import os
from dotenv import load_dotenv

# Загрузка переменных окружения из .env файла
load_dotenv()

class Config:
    """Базовая конфигурация."""
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-key-should-be-changed')
    # SQLite база данных (в памяти)
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    # PostgreSQL база данных
    POSTGRES_URI = os.environ.get('POSTGRES_URI', 'postgresql://user:pass@localhost/books_db')
    # MySQL база данных
    MYSQL_URI = os.environ.get('MYSQL_URI', 'mysql+pymysql://user:pass@localhost/books_db')
    
class DevelopmentConfig(Config):
    """Конфигурация для разработки."""
    DEBUG = True

class TestingConfig(Config):
    """Конфигурация для тестирования."""
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'

class ProductionConfig(Config):
    """Конфигурация для продакшена."""
    DEBUG = False

# Словарь для выбора конфигурации
config = {
    'development': DevelopmentConfig,
    'testing': TestingConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}