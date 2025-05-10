# app/models.py

from datetime import datetime
from flask_sqlalchemy import SQLAlchemy

# Инициализация SQLAlchemy
db = SQLAlchemy()


class Author(db.Model):
    """Модель автора."""
    __tablename__ = 'authors'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    birth_date = db.Column(db.Date, nullable=True)
    bio = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    # Связь с моделью Book
    books = db.relationship(
        'Book', backref='author', lazy=True, cascade='all, delete-orphan'
    )

    def __repr__(self):
        return f'<Author {self.name}>'

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'birth_date': self.birth_date.isoformat()
            if self.birth_date else None,
            'bio': self.bio,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }


class Book(db.Model):
    """Модель книги."""
    __tablename__ = 'books'

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    isbn = db.Column(db.String(13), unique=True, nullable=True)
    publication_date = db.Column(db.Date, nullable=True)
    description = db.Column(db.Text, nullable=True)
    price = db.Column(db.Float, nullable=True)
    author_id = db.Column(
        db.Integer, db.ForeignKey('authors.id'), nullable=False
    )
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    # Связь с моделью Review
    reviews = db.relationship(
        'Review', backref='book', lazy=True, cascade='all, delete-orphan'
    )

    def __repr__(self):
        return f'<Book {self.title}>'

    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'isbn': self.isbn,
            'publication_date': self.publication_date.isoformat()
            if self.publication_date else None,
            'description': self.description,
            'price': self.price,
            'author_id': self.author_id,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }


class Review(db.Model):
    """Модель отзыва."""
    __tablename__ = 'reviews'

    id = db.Column(db.Integer, primary_key=True)
    rating = db.Column(db.Integer, nullable=False)  # Оценка от 1-5
    comment = db.Column(db.Text, nullable=True)
    reviewer_name = db.Column(db.String(100), nullable=False)
    book_id = db.Column(
        db.Integer, db.ForeignKey('books.id'), nullable=False
    )
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    def __repr__(self):
        return f'<Review {self.id} for Book {self.book_id}>'

    def to_dict(self):
        return {
            'id': self.id,
            'rating': self.rating,
            'comment': self.comment,
            'reviewer_name': self.reviewer_name,
            'book_id': self.book_id,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }


# Хранилище данных в памяти для данных, не хранящихся в БД
memory_store = {
    'recent_searches': [],
    'popular_books': [
        {'id': 1, 'title': 'Python для начинающих', 'popularity': 95},
        {'id': 2, 'title': 'Чистый код', 'popularity': 92},
        {'id': 3, 'title': 'Шаблоны проектирования', 'popularity': 88},
        {'id': 4, 'title': 'Fluent Python', 'popularity': 85},
        {'id': 5, 'title': 'Эффективный Python', 'popularity': 82},
    ],
    'site_metrics': {
        'visitors': 12345,
        'page_views': 54321,
        'unique_users': 7890
    }
}
