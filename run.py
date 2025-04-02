#!/usr/bin/env python
import os
from dotenv import load_dotenv
from app import create_app, init_additional_databases

# Загрузка переменных окружения
load_dotenv()

# Получение конфигурации из переменной окружения
config_name = os.environ.get('FLASK_CONFIG') or 'default'

# Создание приложения
app = create_app(config_name)

# Инициализация дополнительных баз данных
with app.app_context():
    init_additional_databases(app)

if __name__ == '__main__':
    # Получение порта из переменной окружения или использование порта по умолчанию
    port = int(os.environ.get('PORT', 5000))
    # Запуск приложения
    app.run(host='0.0.0.0', port=port)