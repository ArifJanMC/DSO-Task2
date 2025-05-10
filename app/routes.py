# app/routes.py

from flask import Blueprint, request, jsonify
from .services import AuthorService, BookService, ReviewService, MemoryService
from datetime import datetime
# Removed: import json (F401 imported but unused)

api = Blueprint('api', __name__)


# Вспомогательная функция для получения JSON данных из запроса
def get_request_data():
    """Извлечение JSON данных из запроса."""
    if request.is_json:
        return request.json
    return {}


# Маршруты авторов
@api.route('/authors', methods=['GET'])
def get_authors():
    """Получить всех авторов."""
    data, status_code = AuthorService.get_all_authors()
    return jsonify(data), status_code


@api.route('/authors/<int:author_id>', methods=['GET'])
def get_author(author_id):
    """Получить автора по ID."""
    data, status_code = AuthorService.get_author(author_id)
    return jsonify(data), status_code


@api.route('/authors', methods=['POST'])
def create_author():
    """Создать нового автора."""
    data = get_request_data()
    result, status_code = AuthorService.create_author(data)
    return jsonify(result), status_code


@api.route('/authors/<int:author_id>', methods=['PUT'])
def update_author(author_id):
    """Обновить существующего автора."""
    data = get_request_data()
    result, status_code = AuthorService.update_author(author_id, data)
    return jsonify(result), status_code


@api.route('/authors/<int:author_id>', methods=['DELETE'])
def delete_author(author_id):
    """Удалить автора."""
    result, status_code = AuthorService.delete_author(author_id)
    return jsonify(result), status_code


# Маршруты книг
@api.route('/books', methods=['GET'])
def get_books():
    """Получить все книги."""
    data, status_code = BookService.get_all_books()
    return jsonify(data), status_code


@api.route('/books/<int:book_id>', methods=['GET'])
def get_book(book_id):
    """Получить книгу по ID."""
    data, status_code = BookService.get_book(book_id)
    return jsonify(data), status_code


@api.route('/books', methods=['POST'])
def create_book():
    """Создать новую книгу."""
    data = get_request_data()
    result, status_code = BookService.create_book(data)
    return jsonify(result), status_code


@api.route('/books/<int:book_id>', methods=['PUT'])
def update_book(book_id):
    """Обновить существующую книгу."""
    data = get_request_data()
    result, status_code = BookService.update_book(book_id, data)
    return jsonify(result), status_code


@api.route('/books/<int:book_id>', methods=['DELETE'])
def delete_book(book_id):
    """Удалить книгу."""
    result, status_code = BookService.delete_book(book_id)
    return jsonify(result), status_code


# Маршруты отзывов
@api.route('/reviews', methods=['GET'])
def get_reviews():
    """Получить все отзывы."""
    data, status_code = ReviewService.get_all_reviews()
    return jsonify(data), status_code


@api.route('/books/<int:book_id>/reviews', methods=['GET'])
def get_reviews_for_book(book_id):
    """Получить все отзывы для конкретной книги."""
    data, status_code = ReviewService.get_reviews_for_book(book_id)
    return jsonify(data), status_code


@api.route('/reviews/<int:review_id>', methods=['GET'])
def get_review(review_id):
    """Получить отзыв по ID."""
    data, status_code = ReviewService.get_review(review_id)
    return jsonify(data), status_code


@api.route('/reviews', methods=['POST'])
def create_review():
    """Создать новый отзыв."""
    data = get_request_data()
    result, status_code = ReviewService.create_review(data)
    return jsonify(result), status_code


@api.route('/reviews/<int:review_id>', methods=['PUT'])
def update_review(review_id):
    """Обновить существующий отзыв."""
    data = get_request_data()
    result, status_code = ReviewService.update_review(review_id, data)
    return jsonify(result), status_code


@api.route('/reviews/<int:review_id>', methods=['DELETE'])
def delete_review(review_id):
    """Удалить отзыв."""
    result, status_code = ReviewService.delete_review(review_id)
    return jsonify(result), status_code


# Маршруты хранилища в памяти
@api.route('/memory', methods=['GET'])
def get_memory():
    """Получить все данные из хранилища в памяти."""
    data, status_code = MemoryService.get_all_memory_data()
    return jsonify(data), status_code


@api.route('/memory/<string:key>', methods=['GET'])
def get_memory_key(key):
    """Получить конкретные данные из хранилища в памяти по ключу."""
    data, status_code = MemoryService.get_memory_data(key)
    return jsonify(data), status_code


@api.route('/memory/search', methods=['POST'])
def add_search():
    """Добавить поисковый запрос в память."""
    data = get_request_data()
    result, status_code = MemoryService.add_search_query(data.get('query', ''))
    return jsonify(result), status_code


@api.route('/memory/metrics', methods=['PUT'])
def update_metrics():
    """Обновить метрики сайта."""
    data = get_request_data()
    result, status_code = MemoryService.update_metrics(data)
    return jsonify(result), status_code


# Маршрут проверки работоспособности
@api.route('/health', methods=['GET'])
def health_check():
    """Эндпоинт проверки работоспособности."""
    return jsonify({
        'status': 'healthy',
        'timestamp': str(datetime.utcnow())
    }), 200
# W292 no newline at end of file (added newline)
