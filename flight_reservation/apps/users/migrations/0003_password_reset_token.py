from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0002_add_livreur_role'),
    ]

    operations = [
        migrations.CreateModel(
            name='PasswordResetToken',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('email', models.EmailField(db_index=True, max_length=254)),
                ('code', models.CharField(max_length=6)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('expires_at', models.DateTimeField()),
                ('used', models.BooleanField(default=False)),
            ],
            options={
                'db_table': 'password_reset_tokens',
            },
        ),
    ]
