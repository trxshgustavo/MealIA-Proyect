import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.environ['SECRET_KEY'] = 'isolated-api-test-key-not-for-production'
os.environ['SQLALCHEMY_DATABASE_URL'] = 'sqlite://'
os.environ.pop('OPENAI_API_KEY', None)
from main import app
from database import Base, get_db
from limiter import limiter


@pytest.fixture
def session():
    engine = create_engine('sqlite://', connect_args={'check_same_thread': False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    with sessionmaker(bind=engine)() as db:
        yield db
    engine.dispose()


@pytest.fixture
def api(session):
    limiter.reset()
    def override():
        yield session
    app.dependency_overrides[get_db] = override
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()


@pytest.fixture
def login(api):
    def create(email='qa@example.com'):
        password = 'TestPassword123'
        response = api.post('/register', json={'email': email, 'first_name': 'QA', 'password': password})
        assert response.status_code == 200, response.text
        token = api.post('/token', data={'username': email, 'password': password}).json()['access_token']
        return {'Authorization': 'Bearer ' + token}
    return create
