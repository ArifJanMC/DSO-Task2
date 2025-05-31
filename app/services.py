# app/services.py

from .models import db, Author, Book, Review, memory_store
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from datetime import datetime


class DatabaseService:
    """Сервисный класс для операций с базами данных."""

    @staticmethod
    def init_sqlite_db(app):
        """Инициализация SQLite базы данных."""
        db.init_app(app)
        with app.app_context():
            db.create_all()
            DatabaseService.seed_data()

    @staticmethod
    def init_postgres_db(app, uri):
        """Инициализация PostgreSQL базы данных."""
        app.config['SQLALCHEMY_DATABASE_URI'] = uri
        # db.init_app(app)
        with app.app_context():
            db.create_all()

    @staticmethod
    def init_mysql_db(app, uri):
        """Инициализация MySQL базы данных."""
        app.config['SQLALCHEMY_DATABASE_URI'] = uri
        # db.init_app(app)
        with app.app_context():
            db.create_all()

    @staticmethod
    def seed_data():
        """Заполнение начальными данными для разработки."""
        if Author.query.first():
            return

        authors = [
            Author(name='Роберт Мартин',
                   bio='Специалист по программной инженерии'),
            Author(name='Эрик Маттес',
                   bio='Школьный учитель математики и информатики'),
            Author(name='Лучано Рамальо',
                   bio='Python разработчик и тренер'),
            Author(name='Эрих Гамма',
                   bio='Специалист по информатике, соавтор книги "Приемы '
                       'объектно-ориентированного проектирования"')
        ]
        db.session.add_all(authors)
        db.session.commit()

        books = [
            Book(title='Чистый код', isbn='9780132350884', author_id=1,
                 description='Руководство по гибкой разработке программного '
                             'обеспечения', price=3500),
            Book(title='Python Crash Course', isbn='9781593276034',
                 author_id=2,
                 description='Практический проектно-ориентированный курс по '
                             'программированию', price=2900),
            Book(title='Fluent Python', isbn='9781491946008', author_id=3,
                 description='Ясное, лаконичное и эффективное '
                             'программирование', price=3900),
            Book(title='Design Patterns', isbn='9780201633610', author_id=4,
                 description='Элементы многократно используемого '
                             'объектно-ориентированного программного '
                             'обеспечения', price=4500)
        ]
        db.session.add_all(books)
        db.session.commit()

        reviews = [
            Review(rating=5,
                   comment='Отличная книга для изучения чистого кода',
                   reviewer_name='Иван Иванов', book_id=1),
            Review(rating=4, comment='Хорошее введение в Python',
                   reviewer_name='Мария Сидорова', book_id=2),
            Review(rating=5,
                   comment='Подробная книга по Python для разработчиков '
                           'среднего уровня',
                   reviewer_name='Сергей Петров', book_id=3)
        ]
        db.session.add_all(reviews)
        db.session.commit()


class AuthorService:
    """Сервисный класс для операций с авторами."""

    @staticmethod
    def get_all_authors():
        """Получить всех авторов."""
        try:
            authors = Author.query.all()
            return [author.to_dict() for author in authors], 200
        except SQLAlchemyError as e:
            return {'error': str(e)}, 500

    @staticmethod
    def get_author(author_id):
        """Получить автора по ID."""
        try:
            author = Author.query.get(author_id)
            if not author:
                return {'error': 'Автор не найден'}, 404
            return author.to_dict(), 200
        except SQLAlchemyError as e:
            return {'error': str(e)}, 500

    @staticmethod
    def create_author(data):
        """Создать нового автора."""
        try:
            birth_date_str = data.get('birth_date')
            birth_date = None
            if birth_date_str:
                birth_date = datetime.strptime(birth_date_str, '%Y-%m-%d')

            author = Author(
                name=data.get('name'),
                birth_date=birth_date,
                bio=data.get('bio')
            )
            db.session.add(author)
            db.session.commit()
            return author.to_dict(), 201
        except IntegrityError:
            db.session.rollback()
            return {
                'error': 'Автор уже существует или нарушено ограничение '
                         'целостности данных'}, 409
        except SQLAlchemyError as e:
            db.session.rollback()
            return {'error': str(e)}, 500

    @staticmethod
    def update_author(author_id, data):
        """Обновить существующего автора."""
        try:
            author = Author.query.get(author_id)
            if not author:
                return {'error': 'Автор не найден'}, 404

            if 'name' in data:
                author.name = data['name']
            if 'birth_date' in data:
                birth_date_str = data['birth_date']
                author.birth_date = None
                if birth_date_str:
                    author.birth_date = datetime.strptime(
                        birth_date_str, '%Y-%m-%d'
                    )
            if 'bio' in data:
                author.bio = data['bio']

            db.session.commit()
            return author.to_dict(), 200
        except IntegrityError:
            db.session.rollback()
            return {
                'error': 'Нарушено ограничение целостности данных'}, 409
        except SQLAlchemyError as e:
            db.session.rollback()
            return {'error': str(e)}, 500

    @staticmethod
    def delete_author(author_id):
        """Удалить автора."""
        try:
            author = Author.query.get(author_id)
            if not author:
                return {'error': 'Автор не найден'}, 404

            db.session.delete(author)
            db.session.commit()
            return {'message': f'Автор {author_id} успешно удален'}, 200
        except SQLAlchemyError as e:
            db.session.rollback()
            return {'error': str(e)}, 500


class BookService:
    """Сервисный класс для операций с книгами."""

    @staticmethod
    def get_all_books():
        """Получить все книги."""
        try:
            books = Book.query.all()
            return [book.to_dict() for book in books], 200
        except SQLAlchemyError as e:
            return {'error': str(e)}, 500

    @staticmethod
    def get_book(book_id):
        """Получить книгу по ID."""
        try:
            book = Book.query.get(book_id)
            if not book:
                return {'error': 'Книга не найдена'}, 404
            return book.to_dict(), 200
        except SQLAlchemyError as e:
            return {'error': str(e)}, 500

    @staticmethod
    def create_book(data):
        """Создать новую книгу."""
        try:
            author = Author.query.get(data.get('author_id'))
            if not author:
                return {'error': 'Автор не найден'}, 404

            pub_date_str = data.get('publication_date')
            publication_date = None
            if pub_date_str:
                publication_date = datetime.strptime(pub_date_str, '%Y-%m-%d')

            book = Book(
                title=data.get('title'),
                isbn=data.get('isbn'),
                publication_date=publication_date,
                description=data.get('description'),
                price=data.get('price'),
                author_id=data.get('author_id')
            )
            db.session.add(book)
            db.session.commit()
            return book.to_dict(), 201
        except IntegrityError:
            db.session.rollback()
            return {
                'error': 'Книга уже существует или нарушено ограничение '
                         'целостности данных'}, 409
        except SQLAlchemyError as e:
            db.session.rollback()
            return {'error': str(e)}, 500

    @staticmethod
    def update_book(book_id, data):
        """Обновить существующую книгу."""
        try:
            book = Book.query.get(book_id)
            if not book:
                return {'error': 'Книга не найдена'}, 404

            if 'title' in data:
                book.title = data['title']
            if 'isbn' in data:
                book.isbn = data['isbn']
            if 'publication_date' in data:
                pub_date_str = data['publication_date']
                book.publication_date = None
                if pub_date_str:
                    book.publication_date = datetime.strptime(
                        pub_date_str, '%Y-%m-%d'
                    )
            if 'description' in data:
                book.description = data['description']
            if 'price' in data:
                book.price = data['price']
            if 'author_id' in data:
                author = Author.query.get(data['author_id'])
                if not author:
                    return {'error': 'Автор не найден'}, 404
                book.author_id = data['author_id']

            db.session.commit()
            return book.to_dict(), 200
        except IntegrityError:
            db.session.rollback()
            return {
                'error': 'Нарушено ограничение целостности данных'}, 409
        except SQLAlchemyError as e:
            db.session.rollback()
            return {'error': str(e)}, 500

    @staticmethod
    def delete_book(book_id):
        """Удалить книгу."""
        try:
            book = Book.query.get(book_id)
            if not book:
                return {'error': 'Книга не найдена'}, 404

            db.session.delete(book)
            db.session.commit()
            return {'message': f'Книга {book_id} успешно удалена'}, 200
        except SQLAlchemyError as e:
            db.session.rollback()
            return {'error': str(e)}, 500


class ReviewService:
    """Сервисный класс для операций с отзывами."""

    @staticmethod
    def get_all_reviews():
        """Получить все отзывы."""
        try:
            reviews = Review.query.all()
            return [review.to_dict() for review in reviews], 200
        except SQLAlchemyError as e:
            return {'error': str(e)}, 500

    @staticmethod
    def get_reviews_for_book(book_id):
        """Получить все отзывы для конкретной книги."""
        try:
            book = Book.query.get(book_id)
            if not book:
                return {'error': 'Книга не найдена'}, 404

            reviews = Review.query.filter_by(book_id=book_id).all()
            return [review.to_dict() for review in reviews], 200
        except SQLAlchemyError as e:
            return {'error': str(e)}, 500

    @staticmethod
    def get_review(review_id):
        """Получить отзыв по ID."""
        try:
            review = Review.query.get(review_id)
            if not review:
                return {'error': 'Отзыв не найден'}, 404
            return review.to_dict(), 200
        except SQLAlchemyError as e:
            return {'error': str(e)}, 500

    @staticmethod
    def create_review(data):
        """Создать новый отзыв."""
        try:
            book = Book.query.get(data.get('book_id'))
            if not book:
                return {'error': 'Книга не найдена'}, 404

            rating = data.get('rating')
            if rating is None or not (1 <= rating <= 5):
                return {'error': 'Оценка должна быть от 1 до 5'}, 400

            review = Review(
                rating=rating,
                comment=data.get('comment'),
                reviewer_name=data.get('reviewer_name'),
                book_id=data.get('book_id')
            )
            db.session.add(review)
            db.session.commit()
            return review.to_dict(), 201
        except IntegrityError:
            db.session.rollback()
            return {
                'error': 'Нарушено ограничение целостности данных'}, 409
        except SQLAlchemyError as e:
            db.session.rollback()
            return {'error': str(e)}, 500

    @staticmethod
    def update_review(review_id, data):
        """Обновить существующий отзыв."""
        try:
            review = Review.query.get(review_id)
            if not review:
                return {'error': 'Отзыв не найден'}, 404

            if 'rating' in data:
                rating = data['rating']
                if not (1 <= rating <= 5):
                    return {'error': 'Оценка должна быть от 1 до 5'}, 400
                review.rating = rating
            if 'comment' in data:
                review.comment = data['comment']
            if 'reviewer_name' in data:
                review.reviewer_name = data['reviewer_name']

            db.session.commit()
            return review.to_dict(), 200
        except IntegrityError:
            db.session.rollback()
            return {
                'error': 'Нарушено ограничение целостности данных'}, 409
        except SQLAlchemyError as e:
            db.session.rollback()
            return {'error': str(e)}, 500

    @staticmethod
    def delete_review(review_id):
        """Удалить отзыв."""
        try:
            review = Review.query.get(review_id)
            if not review:
                return {'error': 'Отзыв не найден'}, 404

            db.session.delete(review)
            db.session.commit()
            return {'message': f'Отзыв {review_id} успешно удален'}, 200
        except SQLAlchemyError as e:
            db.session.rollback()
            return {'error': str(e)}, 500


class MemoryService:
    """Сервисный класс для операций с данными в памяти."""

    @staticmethod
    def get_all_memory_data():
        """Получить все данные из памяти."""
        return memory_store, 200

    @staticmethod
    def get_memory_data(key):
        """Получить конкретные данные из памяти по ключу."""
        if key not in memory_store:
            return {
                'error': f'Ключ "{key}" не найден в хранилище памяти'}, 404
        return {key: memory_store[key]}, 200

    @staticmethod
    def add_search_query(query):
        """Добавить поисковый запрос в недавние поиски."""
        memory_store['recent_searches'].append({
            'query': query,
            'timestamp': datetime.utcnow().isoformat()
        })
        memory_store['recent_searches'] = \
            memory_store['recent_searches'][-10:]
        return {'message': 'Поисковый запрос добавлен'}, 200

    @staticmethod
    def update_metrics(data):
        """Обновить метрики сайта."""
        if 'visitors' in data:
            memory_store['site_metrics']['visitors'] = data['visitors']
        if 'page_views' in data:
            memory_store['site_metrics']['page_views'] = data['page_views']
        if 'unique_users' in data:
            memory_store['site_metrics']['unique_users'] = data['unique_users']
        return {
            'message': 'Метрики обновлены',
            'metrics': memory_store['site_metrics']
        }, 200
