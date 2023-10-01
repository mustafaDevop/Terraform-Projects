from django.test import TestCase
from django.db import connection


class DbConnectionTestCase(TestCase):
    def test_db_connection(self):
        self.assertTrue(connection.is_usable())