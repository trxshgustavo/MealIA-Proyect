import importlib.util
from pathlib import Path


def test_client_bundle_excludes_backend_secrets(tmp_path):
    script = Path(__file__).resolve().parents[2] / 'frontend/meal_ia/tool/prepare_client_env.py'
    spec = importlib.util.spec_from_file_location('prepare_client_env', script)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    (tmp_path / 'assets/config').mkdir(parents=True)
    (tmp_path / 'assets/config/firebase.env').write_text('PROJECT_ID=example\n')
    (tmp_path / '.env').write_text('WEB_API_KEY=public-test-key\nGEMINI_API_KEY=must-stay-out\nOPENAI_API_KEY=also-private\nSECRET_KEY=private-signing-secret\n')
    module.ROOT = tmp_path
    module.prepare()
    output = (tmp_path / 'assets/config/firebase.env').read_text()
    assert 'public-test-key' in output
    assert 'PROJECT_ID=example' in output
    assert 'must-stay-out' not in output and 'also-private' not in output
    assert 'SECRET_KEY' not in output
