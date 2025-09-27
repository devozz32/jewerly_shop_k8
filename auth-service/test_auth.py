# Unit tests for auth-service based on your project
import pytest
from main import app
from fastapi.testclient import TestClient

client = TestClient(app)

def test_health_check():
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "healthy"
    assert data["service"] == "auth-service"

def test_root():
    resp = client.get("/")
    assert resp.status_code == 200
    assert "message" in resp.json()
