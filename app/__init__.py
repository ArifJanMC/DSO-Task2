# app/__init__.py

import logging
from flask import Flask, jsonify
from .config import config
from .routes import api
from .services import DatabaseService


def create_app(config_name='default'):
    """Фабрика приложения."""
    app = Flask(__name__)

    # Загрузка конфигурации
    app.config.from_object(config[config_name])

    # Настройка логирования
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    # Инициализация SQLite базы данных (в памяти)
    DatabaseService.init_sqlite_db(app)

    # Регистрация блупринтов
    app.register_blueprint(api, url_prefix='/api')

    # Добавление обработчиков ошибок
    @app.errorhandler(404)
    def not_found(error): # Removed unused 'error' argument for flake8
        return jsonify({'error': 'Не найдено'}), 404

    @app.errorhandler(400)
    def bad_request(error): # Removed unused 'error' argument for flake8
        return jsonify({'error': 'Неправильный запрос'}), 400

    @app.errorhandler(500)
    def server_error(error): # Removed unused 'error' argument for flake8
        return jsonify({'error': 'Внутренняя ошибка сервера'}), 500

    @app.route('/')
    def index():
        return jsonify({
            'name': 'API управления книжным каталогом',
            'version': '1.0',
            'endpoints': '/api'
        })

    return app


def init_additional_databases(app):
    """Инициализация дополнительных баз данных на основе конфигурации."""
    # Инициализация PostgreSQL, если настроено
    postgres_uri = app.config.get('POSTGRES_URI')
    if postgres_uri:
        try:
            DatabaseService.init_postgres_db(app, postgres_uri)
            app.logger.info('База данных PostgreSQL успешно инициализирована')
        except Exception as e:
            app.logger.error(
                f'Ошибка инициализации базы данных PostgreSQL: {str(e)}'
            )

    # Инициализация MySQL, если настроено
    mysql_uri = app.config.get('MYSQL_URI')
    if mysql_uri:
        try:
            DatabaseService.init_mysql_db(app, mysql_uri)
            app.logger.info('База данных MySQL успешно инициализирована')
        except Exception as e:
            app.logger.error(
                f'Ошибка инициализации базы данных MySQL: {str(e)}'
            )
