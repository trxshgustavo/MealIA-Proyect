from datetime import datetime, timedelta
from types import SimpleNamespace
import json

import pytest
from fastapi import HTTPException
import models
from routers import auth, menu


def test_inventory_converts_units_and_preserves_metadata(api, login):
    headers = login()
    first = api.post('/inventory', headers=headers, json={'name': '  Arroz ', 'quantity': 1, 'unit': 'Kg', 'category': 'Cereales', 'calories': 130})
    assert first.status_code == 200
    assert first.json()['quantity'] == 1000
    added = api.post('/inventory', headers=headers, json={'name': 'ARROZ', 'quantity': 500, 'unit': 'g', 'category': 'Cereales'})
    assert added.status_code == 200
    assert added.json()['quantity'] == 1500
    saved = api.get('/inventory', headers=headers).json()[0]
    assert saved['unit'] == 'g' and saved['category'] == 'Cereales' and saved['calories'] == 130
    assert api.post('/inventory', headers=headers, json={'name': 'arroz', 'quantity': 1, 'unit': 'L'}).status_code == 400
    assert api.get('/inventory', headers=headers).json()[0]['quantity'] == 1500


@pytest.mark.parametrize('quantity', [0, -1])
def test_inventory_rejects_non_positive_additions(api, login, quantity):
    assert api.post('/inventory', headers=login(), json={'name': 'arroz', 'quantity': quantity}).status_code == 422


def test_zero_stock_and_name_normalization(api, login):
    headers = login()
    api.post('/inventory', headers=headers, json={'name': 'Huevos', 'quantity': 3})
    response = api.put('/inventory/HUEVOS', headers=headers, json={'quantity': 0, 'unit': 'Unidades'})
    assert response.status_code == 200 and response.json()['quantity'] == 0
    assert api.delete('/inventory/remove/HUEVOS', headers=headers).status_code == 200


def test_accounts_are_isolated(api, login):
    first, second = login('first@example.com'), login('second@example.com')
    api.post('/inventory', headers=first, json={'name': 'arroz', 'quantity': 2})
    assert api.get('/inventory', headers=second).json() == []
    assert api.delete('/inventory/remove/arroz', headers=second).status_code == 404
    assert api.put('/inventory/arroz', headers=second, json={'quantity': 999, 'unit': 'g'}).status_code == 404
    assert api.get('/inventory', headers=first).json()[0]['quantity'] == 2


def test_entitlements_cannot_be_self_granted(api, login):
    headers = login()
    assert api.post('/subscription/upgrade', headers=headers).status_code == 503
    assert api.put('/users/me/data', headers=headers, json={'is_premium': True}).status_code == 422
    assert api.get('/users/me', headers=headers).json()['is_premium'] is False


def test_password_rules_match_registration_and_changes(api, login):
    headers = login('MixedCase@example.com')
    assert api.post('/token', data={'username': 'MIXEDCASE@EXAMPLE.COM', 'password': 'TestPassword123'}).status_code == 200
    assert api.put('/users/me/password', headers=headers, json={'password': 'weak'}).status_code == 422
    assert api.put('/users/me/data', headers=headers, json={'meals_per_day': 100}).status_code == 422


@pytest.mark.parametrize('audience,verified,expected', [('other-app', True, 401), ('mealia-test', False, 401), ('mealia-test', True, 200)])
def test_google_tokens_require_our_audience_and_verified_email(api, monkeypatch, audience, verified, expected):
    monkeypatch.setenv('GOOGLE_WEB_CLIENT_ID', 'mealia-test')
    monkeypatch.setattr(auth.id_token, 'verify_oauth2_token', lambda *args, **kwargs: {'aud': audience, 'email_verified': verified, 'email': 'google@example.com'})
    assert api.post('/auth/google', json={'token': 'mock-signed-token'}).status_code == expected


def test_weekly_ai_error_preserves_existing_plans(session, monkeypatch):
    user = models.User(email='weekly@example.com', hashed_password='not-a-real-hash', is_premium=1)
    session.add(user); session.flush()
    session.add(models.InventoryItem(owner_id=user.id, name='arroz', quantity=1000, unit='g'))
    day = datetime(2026, 10, 22)
    session.add(models.MealPlan(owner_id=user.id, date=day, breakfast={'name': 'Original'}))
    session.commit()
    completion = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=json.dumps({'days': [{}]})))])
    monkeypatch.setattr(menu, 'client', SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=lambda **kwargs: completion))))
    with pytest.raises(HTTPException) as error:
        menu.generate_weekly_menu_with_ia('2026-10-22', session, user)
    assert error.value.status_code == 502
    assert session.query(models.MealPlan).one().breakfast == {'name': 'Original'}


def test_weekly_database_failure_rolls_back_deletions(session, monkeypatch):
    user = models.User(email='rollback@example.com', hashed_password='unused', is_premium=1)
    session.add(user); session.flush()
    session.add(models.InventoryItem(owner_id=user.id, name='arroz', quantity=1000, unit='g'))
    session.add(models.MealPlan(owner_id=user.id, date=datetime(2026, 10, 22), breakfast={'name': 'Original'}))
    session.commit()
    response = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=json.dumps({'days': [{} for _ in range(7)]})))])
    monkeypatch.setattr(menu, 'client', SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=lambda **kwargs: response))))
    original_add = session.add
    def fail_add(value):
        if isinstance(value, models.MealPlan): raise RuntimeError('simulated database failure')
        return original_add(value)
    monkeypatch.setattr(session, 'add', fail_add)
    with pytest.raises(HTTPException): menu.generate_weekly_menu_with_ia('2026-10-22', session, user)
    assert session.query(models.MealPlan).one().breakfast == {'name': 'Original'}


def test_ai_unavailable_is_a_clear_error(api, login):
    headers = login()
    assert api.post('/generate-menu', headers=headers, json={}).status_code == 503
