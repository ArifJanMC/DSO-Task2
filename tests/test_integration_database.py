# DevSecOps/Task2/tests/test_integration_database.py

import unittest
import os
from flask import current_app
from app import create_app # Assuming your create_app is in app/__init__.py
from app.models import db  # Assuming your db instance is in app/models.py

class DatabaseIntegrationTestCase(unittest.TestCase):
    """
    Test case for database integration.
    This test assumes that the SQLALCHEMY_DATABASE_URI environment variable
    is set by the CI/CD pipeline to point to a test database service.
    """

    def setUp(self):
        """
        Set up the test environment before each test.
        Creates a Flask application instance and pushes an application context.
        """
        # Create the Flask app using the 'testing' configuration.
        # The 'testing' configuration in your app/config.py should
        # ideally be minimal and rely on environment variables for sensitive data
        # like SQLALCHEMY_DATABASE_URI, which will be provided by GitLab CI.
        self.app = create_app('testing')
        self.app_context = self.app.app_context()
        self.app_context.push()

        # You might need to create tables if your connection test relies on them,
        # but for a simple connection check, it might not be necessary.
        # If your app's create_app or init_sqlite_db/init_postgres_db
        # already handles db.create_all(), this might be redundant or handled there.
        # with self.app.app_context():
        #     db.create_all()

    def tearDown(self):
        """
        Clean up the test environment after each test.
        Pops the application context.
        """
        # with self.app.app_context():
        #     db.session.remove()
        #     db.drop_all() # Clean up the database tables after tests
        self.app_context.pop()

    def test_database_connection_via_environment_variable(self):
        """
        Tests if the application can connect to the database
        using the SQLALCHEMY_DATABASE_URI provided as an environment variable.
        """
        db_uri = os.environ.get('SQLALCHEMY_DATABASE_URI')
        self.assertIsNotNone(db_uri, "SQLALCHEMY_DATABASE_URI environment variable is not set.")
        
        # Log the URI for debugging purposes in CI (be careful if it contains sensitive info, though masked in GitLab)
        print(f"Attempting to connect to database using URI: {db_uri}")

        try:
            # A simple way to test the connection is to execute a basic query.
            # current_app.extensions['sqlalchemy'] provides access to the SQLAlchemy object
            # Alternatively, if 'db' is imported directly and initialized with the app:
            with self.app.app_context(): # Ensure we are within app context for db operations
                engine = db.get_engine()
                with engine.connect() as connection:
                    result = connection.execute(db.text("SELECT 1"))
                    self.assertIsNotNone(result, "Database query (SELECT 1) returned None.")
                    row = result.fetchone()
                    self.assertIsNotNone(row, "Fetching a row from (SELECT 1) returned None.")
                    self.assertEqual(row[0], 1, "Database query (SELECT 1) did not return 1.")
            print("Successfully connected to the database and executed a test query.")
        except Exception as e:
            # If the connection fails, the test will fail with an assertion error.
            self.fail(f"Database connection or query failed with error: {e}")

if __name__ == '__main__':
    # This allows running the tests directly from the command line
    unittest.main()
