# Simple unit test for backend

def test_math():
    assert 1 + 1 == 2

# Example: test product data exists
from main import products_db

def test_products_exist():
    assert isinstance(products_db, list)
    assert len(products_db) > 0
