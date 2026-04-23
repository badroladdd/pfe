from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("reservations", "0003_add_pending_booking_data"),
    ]

    operations = [
        migrations.CreateModel(
            name="PromoCode",
            fields=[
                ("id", models.AutoField(auto_created=True, primary_key=True, serialize=False)),
                ("code", models.CharField(db_index=True, max_length=20, unique=True)),
                ("discount_type", models.CharField(
                    choices=[("percent", "Pourcentage"), ("fixed", "Montant fixe")],
                    max_length=10,
                )),
                ("discount_value", models.DecimalField(decimal_places=2, max_digits=8)),
                ("max_uses", models.IntegerField(default=1)),
                ("used_count", models.IntegerField(default=0)),
                ("expires_at", models.DateTimeField()),
                ("is_active", models.BooleanField(default=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
            ],
            options={"db_table": "promo_codes"},
        ),
    ]
