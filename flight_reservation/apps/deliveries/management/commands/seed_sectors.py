"""
Management command: seed the Sector table with the 57 communes of Wilaya d'Alger (16).

Usage:
    python manage.py seed_sectors
    python manage.py seed_sectors --clear   # drop existing sectors first
"""

from django.core.management.base import BaseCommand
from apps.deliveries.models import Sector

COMMUNES = [
    # Daïra d'Alger-Centre
    ("Alger-Centre",       "1601", 36.7372,  3.0878),
    ("Sidi M'Hamed",       "1602", 36.7408,  3.0789),
    ("El Madania",         "1603", 36.7503,  3.0672),
    ("Belouizdad",         "1604", 36.7383,  3.0819),
    # Daïra de Bab El Oued
    ("Bab El Oued",        "1605", 36.7833,  3.0547),
    ("Casbah",             "1606", 36.7836,  3.0597),
    ("Oued Koriche",       "1607", 36.7911,  3.0550),
    ("Bologhine",          "1608", 36.8028,  3.0461),
    # Daïra de Bir Mourad Raïs
    ("Bir Mourad Raïs",    "1609", 36.7194,  3.0586),
    ("El Biar",            "1610", 36.7617,  3.0417),
    ("Birkhadem",          "1611", 36.7050,  3.0558),
    ("Birmendreïs",        "1612", 36.7258,  3.0153),
    # Daïra de Bouzaréah
    ("Bouzaréah",          "1613", 36.7708,  3.0200),
    ("Dely Ibrahim",       "1614", 36.7550,  2.9942),
    ("Ben Aknoun",         "1615", 36.7578,  3.0089),
    ("El Achour",          "1616", 36.7353,  2.9903),
    ("Ouled Fayet",        "1617", 36.7067,  2.9453),
    ("Chéraga",            "1618", 36.7600,  2.9592),
    # Daïra de Dar El Beïda
    ("Dar El Beïda",       "1619", 36.7153,  3.2147),
    ("Bordj El Kiffan",    "1620", 36.7572,  3.1869),
    ("Aïn Taya",           "1621", 36.7883,  3.2658),
    ("El Marsa",           "1622", 36.8306,  3.2325),
    ("Bordj El Bahri",     "1623", 36.8019,  3.2156),
    ("Reghaïa",            "1624", 36.7531,  3.3333),
    # Daïra d'El Harrach
    ("El Harrach",         "1625", 36.7197,  3.1392),
    ("Bachdjerrah",        "1626", 36.7272,  3.1286),
    ("Kouba",              "1627", 36.7358,  3.1033),
    ("Hussein Dey",        "1628", 36.7472,  3.1150),
    ("Mohammadia",         "1629", 36.7528,  3.1219),
    ("El Magharia",        "1630", 36.7258,  3.1022),
    ("Oued Smar",          "1631", 36.7108,  3.1608),
    # Daïra de Hammamet
    ("Hammamet",           "1632", 36.7381,  2.9739),
    ("Raïs Hamidou",       "1633", 36.8069,  3.0111),
    ("Aïn Benian",         "1634", 36.7872,  2.9256),
    ("Staouéli",           "1635", 36.7422,  2.8808),
    ("Souidania",          "1636", 36.7219,  2.9428),
    # Daïra de Zeralda
    ("Zeralda",            "1637", 36.7117,  2.8575),
    ("Mahelma",            "1638", 36.6911,  2.8561),
    ("Rahmania",           "1639", 36.6700,  2.8781),
    ("Sidi Abdallah",      "1640", 36.6667,  2.9333),
    # Daïra de Saoula
    ("Saoula",             "1641", 36.6942,  3.0117),
    ("Tessala El Merdja",  "1642", 36.6492,  3.0161),
    ("Birtouta",           "1643", 36.6611,  2.9933),
    ("Khraicia",           "1644", 36.6744,  3.0322),
    ("Baba Hassen",        "1645", 36.7011,  2.9800),
    # Daïra de Draria
    ("Draria",             "1646", 36.7111,  2.9939),
    ("Douéra",             "1647", 36.6867,  3.0169),
    ("Gué de Constantine", "1648", 36.7108,  3.1261),
    # Daïra de Baraki
    ("Baraki",             "1649", 36.6767,  3.1011),
    ("Sidi Moussa",        "1650", 36.6444,  3.0736),
    ("Les Eucalyptus",     "1651", 36.6950,  3.1692),
    ("Larbaa",             "1652", 36.5633,  3.1622),
    # Daïra de Bab Ezzouar
    ("Bab Ezzouar",        "1653", 36.7261,  3.1839),
    ("El Hamiz",           "1654", 36.7189,  3.2233),
    # Daïra de Rouïba
    ("Rouïba",             "1655", 36.7350,  3.2869),
    ("Heuraoua",           "1656", 36.7219,  3.2533),
    ("Khemis El Khechna",  "1657", 36.6500,  3.3333),
]


class Command(BaseCommand):
    help = "Seed the Sector table with the 57 communes of Wilaya d'Alger (16)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--clear",
            action="store_true",
            help="Delete all existing sectors before seeding.",
        )

    def handle(self, *args, **options):
        if options["clear"]:
            deleted, _ = Sector.objects.all().delete()
            self.stdout.write(self.style.WARNING(f"Deleted {deleted} existing sectors."))

        created = 0
        skipped = 0
        for name, code, lat, lng in COMMUNES:
            _, was_created = Sector.objects.get_or_create(
                code=code,
                defaults={
                    "name": name,
                    "description": f"Commune de {name}, Wilaya d'Alger",
                    "latitude": lat,
                    "longitude": lng,
                    "radius_km": 5.0,
                    "is_active": True,
                },
            )
            if was_created:
                created += 1
            else:
                skipped += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Done. {created} sectors created, {skipped} already existed."
            )
        )
