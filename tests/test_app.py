import unittest
import json
from app import create_app
from app.models import db

class AppTestCase(unittest.TestCase):
    """Тестовый случай для приложения."""
    
    def setUp(self):
        """Настройка тестового окружения."""
        self.app = create_app('testing')
        self.client = self.app.test_client()
        self.app_context = self.app.app_context()
        self.app_context.push()
    
    def tearDown(self):
        """Очистка тестового окружения."""
        self.app_context.pop()
    
    def test_index(self):
        """Тест маршрута индекса."""
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['name'], 'API управления книжным каталогом')
    
    def test_health_check(self):
        """Тест endpoint'а проверки работоспособности."""
        response = self.client.get('/api/health')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'healthy')
    
    def test_get_authors(self):
        """Тест получения всех авторов."""
        response = self.client.get('/api/authors')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIsInstance(data, list)
    
    def test_create_author(self):
        """Тест создания нового автора."""
        author_data = {
            'name': 'Тестовый Автор',
            'bio': 'Тестовая биография'
        }
        response = self.client.post(
            '/api/authors',
            data=json.dumps(author_data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 201)
        data = json.loads(response.data)
        self.assertEqual(data['name'], 'Тестовый Автор')
    
    def test_get_author(self):
        """Тест получения автора по ID."""
        # Сначала создадим автора
        author_data = {
            'name': 'Автор для получения',
            'bio': 'Тестовая биография'
        }
        create_response = self.client.post(
            '/api/authors',
            data=json.dumps(author_data),
            content_type='application/json'
        )
        author_id = json.loads(create_response.data)['id']
        
        # Теперь получим автора
        response = self.client.get(f'/api/authors/{author_id}')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['name'], 'Автор для получения')
    
    def test_update_author(self):
        """Тест обновления автора."""
        # Сначала создадим автора
        author_data = {
            'name': 'Автор для обновления',
            'bio': 'Тестовая биография'
        }
        create_response = self.client.post(
            '/api/authors',
            data=json.dumps(author_data),
            content_type='application/json'
        )
        author_id = json.loads(create_response.data)['id']
        
        # Теперь обновим автора
        update_data = {
            'name': 'Обновленный Автор',
            'bio': 'Обновленная биография'
        }
        response = self.client.put(
            f'/api/authors/{author_id}',
            data=json.dumps(update_data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['name'], 'Обновленный Автор')
    
    def test_delete_author(self):
        """Тест удаления автора."""
        # Сначала создадим автора
        author_data = {
            'name': 'Автор для удаления',
            'bio': 'Тестовая биография'
        }
        create_response = self.client.post(
            '/api/authors',
            data=json.dumps(author_data),
            content_type='application/json'
        )
        author_id = json.loads(create_response.data)['id']
        
        # Теперь удалим автора
        response = self.client.delete(f'/api/authors/{author_id}')
        self.assertEqual(response.status_code, 200)
        
        # Проверим, что автор удален
        get_response = self.client.get(f'/api/authors/{author_id}')
        self.assertEqual(get_response.status_code, 404)
    
    def test_memory_store(self):
        """Тест endpoints хранилища в памяти."""
        response = self.client.get('/api/memory')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn('recent_searches', data)
        self.assertIn('popular_books', data)
        self.assertIn('site_metrics', data)
    
    def test_add_search_query(self):
        """Тест добавления поискового запроса в память."""
        search_data = {
            'query': 'тестовый поиск'
        }
        response = self.client.post(
            '/api/memory/search',
            data=json.dumps(search_data),
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 200)
        
        # Проверим, был ли добавлен поиск
        memory_response = self.client.get('/api/memory/recent_searches')
        self.assertEqual(memory_response.status_code, 200)
        memory_data = json.loads(memory_response.data)
        searches = memory_data['recent_searches']
        self.assertTrue(any(s['query'] == 'тестовый поиск' for s in searches))

if __name__ == '__main__':
    unittest.main()