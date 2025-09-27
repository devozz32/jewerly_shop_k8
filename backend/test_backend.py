# Unit tests for backend based on your project
import pytest
from main import app
from fastapi.testclient import TestClient

client = TestClient(app)

def test_root():
    resp = client.get("/")
    assert resp.status_code == 200
    assert "message" in resp.json()

def test_get_products():
    resp = client.get("/api/products")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) > 0
