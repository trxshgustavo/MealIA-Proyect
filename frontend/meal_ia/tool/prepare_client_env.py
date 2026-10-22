"""Merge public platform settings from a local .env into the client asset.

Backend secrets are deliberately excluded, even when present in that file.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ALLOWED = {
    'BACKEND_URL', 'WEB_API_KEY', 'WEB_APP_ID', 'WEB_CLIENT_ID',
    'PROJECT_ID', 'MESSAGING_SENDER_ID', 'STORAGE_BUCKET', 'AUTH_DOMAIN',
    'ANDROID_API_KEY', 'ANDROID_APP_ID', 'ANDROID_CLIENT_ID',
    'IOS_API_KEY', 'IOS_APP_ID', 'IOS_CLIENT_ID', 'IOS_BUNDLE_ID',
    'MACOS_API_KEY', 'MACOS_APP_ID', 'MACOS_BUNDLE_ID',
    'WINDOWS_API_KEY', 'WINDOWS_APP_ID', 'GOOGLE_SERVER_CLIENT_ID',
    'RECAPTCHA_V3_SITE_KEY',
}


def prepare():
    target = ROOT / 'assets/config/firebase.env'
    settings = {}
    for source in (target, ROOT / '.env'):
        if source.is_file():
            for line in source.read_text().splitlines():
                key, sep, value = line.partition('=')
                if sep and key.strip() in ALLOWED:
                    settings[key.strip()] = value.strip()
    target.write_text('# Public client configuration only.\n' + ''.join(
        f'{key}={value}\n' for key, value in settings.items()
    ))


if __name__ == '__main__':
    prepare()
