# app/utils.py

import re
import hashlib
import secrets
from datetime import datetime, timedelta
from flask import request, jsonify
# flask.current_app was F401 in the log, so it's removed.


def sanitize_input(input_string):
    """Санитизация пользовательского ввода для предотвращения атак."""
    # E501 line too long (89 > 79 characters) - wrapped docstring
    if not input_string:
        return input_string

    # Удаление потенциально опасных символов
    sanitized = re.sub(r'[<>\'";]', '', input_string)
    return sanitized


def generate_secure_token(length=32):
    """Генерация безопасного случайного токена."""
    return secrets.token_hex(length)


def hash_password(password, salt=None):
    """Хеширование пароля с солью."""
    if not salt:
        salt = secrets.token_hex(8)

    # Создание хеша с солью
    hashed = hashlib.pbkdf2_hmac(
        'sha256',
        password.encode('utf-8'),
        salt.encode('utf-8'),
        100000
    ).hex()

    return f"{salt}${hashed}"


def verify_password(stored_password, provided_password):
    """Проверка пароля на соответствие хранимому хешу."""
    salt, hashed = stored_password.split('$')
    return stored_password == hash_password(provided_password, salt)


def rate_limit(requests_limit=100, time_window=60):
    """Декоратор для реализации базового ограничения частоты запросов."""
    # Хранение временных меток запросов по IP
    ip_requests = {}

    def decorator(f):
        def wrapper(*args, **kwargs):
            ip = request.remote_addr
            current_time = datetime.utcnow()

            if ip not in ip_requests:
                ip_requests[ip] = []

            cutoff_time = current_time - timedelta(seconds=time_window)
            ip_requests[ip] = [t for t in ip_requests[ip]
                               if t >= cutoff_time]

            if len(ip_requests[ip]) >= requests_limit:
                return jsonify({
                    'error': 'Превышен лимит запросов',
                    'retry_after': time_window
                }), 429

            ip_requests[ip].append(current_time)
            return f(*args, **kwargs)

        wrapper.__name__ = f.__name__
        wrapper.__doc__ = f.__doc__
        return wrapper
    return decorator


def log_request(logger):
    """Декоратор для логирования запросов."""
    def decorator(f):
        def wrapper(*args, **kwargs):
            logger.info(
                f"Запрос: {request.method} {request.path} - "
                f"IP: {request.remote_addr}"
            )  # E501 line too long (95 > 79 characters) - wrapped
            return f(*args, **kwargs)

        wrapper.__name__ = f.__name__
        wrapper.__doc__ = f.__doc__
        return wrapper
    return decorator
# W292 no newline at end of file (ensured newline exists)
