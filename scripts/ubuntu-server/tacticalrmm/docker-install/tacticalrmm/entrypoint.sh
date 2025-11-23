#!/bin/bash
set -e

WORKDIR="/opt/tacticalrmm/api/tacticalrmm"
cd $WORKDIR

# Create local_settings.py if it doesn't exist
if [ ! -f "$WORKDIR/tacticalrmm/local_settings.py" ]; then
    echo "Creating local_settings.py..."
    cat > "$WORKDIR/tacticalrmm/local_settings.py" <<EOF
import os

DEBUG = ${DEBUG:-False}
ALLOWED_HOSTS = [x.strip() for x in '${ALLOWED_HOSTS}'.split(',')]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': '${POSTGRES_DB}',
        'USER': '${POSTGRES_USER}',
        'PASSWORD': '${POSTGRES_PASSWORD}',
        'HOST': '${POSTGRES_HOST:-postgres}',
        'PORT': '5432',
    }
}

REDIS_HOST = '${REDIS_HOST:-redis}'
REDIS_PORT = 6379
REDIS_PASSWORD = '${REDIS_PASSWORD}'

MESH_USERNAME = '${MESH_USER}'
MESH_SITE = '${MESH_SITE}'
MESH_TOKEN = '${MESH_TOKEN}'

SECRET_KEY = '${SECRET_KEY}'

CORS_ORIGIN_WHITELIST = [x.strip() for x in '${CORS_ORIGIN_WHITELIST}'.split(',')]

ADMIN_URL = '${ADMIN_URL:-admin/}'

# Celery settings
CELERY_BROKER_URL = f'redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/0'
CELERY_RESULT_BACKEND = f'redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/0'
EOF
fi

# Wait for database to be ready
echo "Waiting for PostgreSQL..."
while ! nc -z ${POSTGRES_HOST:-postgres} 5432; do
    sleep 1
done
echo "PostgreSQL is ready"

# Wait for Redis to be ready
echo "Waiting for Redis..."
while ! nc -z ${REDIS_HOST:-redis} 6379; do
    sleep 1
done
echo "Redis is ready"

# Run migrations on first start
if [ "$1" = "gunicorn" ]; then
    echo "Running database migrations..."
    python manage.py migrate --noinput

    echo "Collecting static files..."
    python manage.py collectstatic --noinput

    # Create superuser if it doesn't exist
    echo "Creating superuser if needed..."
    python manage.py shell <<PYEOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='${ADMIN_USERNAME:-admin}').exists():
    User.objects.create_superuser(
        '${ADMIN_USERNAME:-admin}',
        '${ADMIN_EMAIL:-admin@localhost}',
        '${ADMIN_PASSWORD:-changeme}'
    )
    print('Superuser created')
else:
    print('Superuser already exists')
PYEOF
fi

# Execute the command
exec "$@"