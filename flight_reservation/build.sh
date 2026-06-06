#!/usr/bin/env bash
set -o errexit

pip install -r requirements.txt
python manage.py collectstatic --no-input
python manage.py migrate

python manage.py shell -c "
from apps.users.models import User
import os
email = os.environ.get('ADMIN_EMAIL', 'admin@admin.com')
password = os.environ.get('ADMIN_PASSWORD', 'admin123')
u, created = User.objects.get_or_create(email=email, defaults={
    'first_name': 'Admin', 'last_name': 'User'
})
u.set_password(password)
u.role = 'admin'
u.is_staff = True
u.is_superuser = True
u.save()
print(f'Admin user {email} {\"created\" if created else \"updated\"}')
"
