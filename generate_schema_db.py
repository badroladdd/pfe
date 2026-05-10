import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

plt.rcParams.update({'font.family': 'DejaVu Sans', 'figure.dpi': 100})

# 1024x768 pixels = 10.24x7.68 pouces a 100 dpi
fig, ax = plt.subplots(figsize=(10.24, 7.68))
ax.set_xlim(0, 28)
ax.set_ylim(0, 20)
ax.axis('off')
fig.patch.set_facecolor('#F5F5F5')

# ── couleurs ──────────────────────────────────────────────────────────────────
C_HEADER  = '#1565C0'
C_PK      = '#FFF9C4'
C_FK      = '#E8F5E9'
C_NORMAL  = '#FFFFFF'
C_BORDER  = '#1565C0'
C_TYPE    = '#757575'

# ── helpers ───────────────────────────────────────────────────────────────────
def table(ax, x, y, name, columns):
    """
    columns: [(col_name, col_type, flag)]
    flag: 'PK' | 'FK' | ''
    """
    row_h    = 0.42
    header_h = 0.55
    w        = 5.2
    total_h  = header_h + len(columns) * row_h

    # ombre
    ax.add_patch(mpatches.FancyBboxPatch(
        (x+0.07, y-total_h-0.07), w, total_h,
        boxstyle='round,pad=0.04', lw=0,
        facecolor='#BDBDBD', zorder=1))

    # cadre principal
    ax.add_patch(mpatches.FancyBboxPatch(
        (x, y-total_h), w, total_h,
        boxstyle='round,pad=0.04', lw=2,
        edgecolor=C_BORDER, facecolor=C_NORMAL, zorder=2))

    # en-tete
    ax.add_patch(mpatches.FancyBboxPatch(
        (x, y-header_h), w, header_h,
        boxstyle='round,pad=0.04', lw=0,
        facecolor=C_HEADER, zorder=3))
    ax.text(x + w/2, y - header_h/2, name,
            ha='center', va='center', fontsize=10,
            fontweight='bold', color='white', zorder=4)

    # colonnes
    cy = y - header_h
    for col, typ, flag in columns:
        bg = C_PK if flag == 'PK' else (C_FK if flag == 'FK' else C_NORMAL)
        ax.add_patch(mpatches.Rectangle(
            (x+0.02, cy - row_h + 0.02), w - 0.04, row_h - 0.04,
            facecolor=bg, zorder=2))
        ax.plot([x, x+w], [cy, cy], color='#E0E0E0', lw=0.6, zorder=3)

        # icone PK / FK
        if flag == 'PK':
            ax.text(x+0.18, cy - row_h/2, 'PK',
                    ha='center', va='center', fontsize=6.5,
                    fontweight='bold', color='#F57F17', zorder=4)
        elif flag == 'FK':
            ax.text(x+0.18, cy - row_h/2, 'FK',
                    ha='center', va='center', fontsize=6.5,
                    fontweight='bold', color='#2E7D32', zorder=4)

        # nom colonne
        ax.text(x+0.38, cy - row_h/2, col,
                ha='left', va='center', fontsize=8.2,
                color='#212121', zorder=4,
                fontweight='bold' if flag == 'PK' else 'normal')

        # type
        ax.text(x + w - 0.12, cy - row_h/2, typ,
                ha='right', va='center', fontsize=7.5,
                color=C_TYPE, style='italic', zorder=4)

        cy -= row_h

    return (x, y, w, total_h)

def fk_line(ax, x1, y1, x2, y2, label='', color='#1565C0'):
    """Trace une ligne de relation avec une fleche."""
    ax.annotate('',
        xy=(x2, y2), xytext=(x1, y1),
        arrowprops=dict(
            arrowstyle='-|>',
            color=color, lw=1.6,
            mutation_scale=14,
            connectionstyle='arc3,rad=0.0'),
        zorder=5)
    if label:
        mx, my = (x1+x2)/2, (y1+y2)/2
        ax.text(mx, my+0.12, label,
                ha='center', va='bottom', fontsize=7.5,
                color=color, fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.15',
                          facecolor='white', edgecolor='none', alpha=0.85),
                zorder=6)

def card(ax, x, y, text, color='#1565C0'):
    ax.text(x, y, text, ha='center', va='center',
            fontsize=8, fontweight='bold', color=color,
            bbox=dict(boxstyle='round,pad=0.2',
                      facecolor='white', edgecolor=color, lw=1),
            zorder=7)

# ══════════════════════════════════════════════════════════════════════════════
#  TABLES
# ══════════════════════════════════════════════════════════════════════════════

# users  (centre-haut)
table(ax, 11.0, 19.0, 'users', [
    ('id',         'UUID',     'PK'),
    ('email',      'VARCHAR',  ''),
    ('first_name', 'VARCHAR',  ''),
    ('last_name',  'VARCHAR',  ''),
    ('phone',      'VARCHAR',  ''),
    ('role',       'ENUM',     ''),
    ('password',   'VARCHAR',  ''),
    ('is_active',  'BOOLEAN',  ''),
    ('created_at', 'DATETIME', ''),
    ('updated_at', 'DATETIME', ''),
])

# reservations  (centre)
table(ax, 11.0, 13.5, 'reservations', [
    ('id',                   'UUID',    'PK'),
    ('user_id',              'UUID',    'FK'),
    ('offer_id',             'VARCHAR', ''),
    ('external_order_id',    'VARCHAR', ''),
    ('status',               'ENUM',    ''),
    ('total_amount',         'DECIMAL', ''),
    ('currency',             'CHAR(3)', ''),
    ('booking_reference',    'VARCHAR', ''),
    ('payment_method',       'VARCHAR', ''),
    ('raw_duffel_order',     'JSON',    ''),
    ('pending_booking_data', 'JSON',    ''),
    ('created_at',           'DATETIME',''),
    ('updated_at',           'DATETIME',''),
])

# passengers  (droite)
table(ax, 18.5, 13.5, 'passengers', [
    ('id',                  'UUID',    'PK'),
    ('reservation_id',      'UUID',    'FK'),
    ('type',                'ENUM',    ''),
    ('title',               'ENUM',    ''),
    ('first_name',          'VARCHAR', ''),
    ('last_name',           'VARCHAR', ''),
    ('born_on',             'DATE',    ''),
    ('email',               'VARCHAR', ''),
    ('phone',               'VARCHAR', ''),
    ('id_document_number',  'VARCHAR', ''),
    ('id_document_expiry',  'DATE',    ''),
    ('nationality',         'CHAR(2)', ''),
    ('base_amount',         'DECIMAL', ''),
    ('tax_amount',          'DECIMAL', ''),
])

# payments  (gauche)
table(ax, 1.0, 13.5, 'payments', [
    ('id',                'UUID',    'PK'),
    ('reservation_id',    'UUID',    'FK'),
    ('amount',            'DECIMAL', ''),
    ('currency',          'CHAR(3)', ''),
    ('method',            'VARCHAR', ''),
    ('status',            'ENUM',    ''),
    ('duffel_payment_id', 'VARCHAR', ''),
    ('created_at',        'DATETIME',''),
    ('updated_at',        'DATETIME',''),
])

# promo_codes  (bas-gauche)
table(ax, 1.0, 6.5, 'promo_codes', [
    ('id',             'INT',      'PK'),
    ('code',           'VARCHAR',  ''),
    ('discount_type',  'ENUM',     ''),
    ('discount_value', 'DECIMAL',  ''),
    ('max_uses',       'INT',      ''),
    ('used_count',     'INT',      ''),
    ('expires_at',     'DATETIME', ''),
    ('is_active',      'BOOLEAN',  ''),
    ('created_at',     'DATETIME', ''),
])

# flight_cache  (bas-droite)
table(ax, 11.0, 6.5, 'flight_cache', [
    ('offer_id',      'VARCHAR', 'PK'),
    ('origin',        'CHAR(3)', ''),
    ('destination',   'CHAR(3)', ''),
    ('departure_date','DATE',    ''),
    ('raw_offer',     'JSON',    ''),
    ('expires_at',    'DATETIME',''),
    ('created_at',    'DATETIME',''),
])

# ══════════════════════════════════════════════════════════════════════════════
#  RELATIONS
# ══════════════════════════════════════════════════════════════════════════════

# users  1 ──► N  reservations
fk_line(ax, 13.6, 15.08, 13.6, 13.5, color='#1565C0')
card(ax, 13.0, 15.35, '1', '#1565C0')
card(ax, 13.0, 13.65, 'N', '#1565C0')

# reservations  1 ──► N  passengers
fk_line(ax, 18.5, 11.5, 16.2, 11.5, color='#2E7D32')
card(ax, 18.3, 11.75, 'N', '#2E7D32')
card(ax, 16.4, 11.75, '1', '#2E7D32')

# reservations  1 ──► 1  payments
fk_line(ax, 11.0, 11.5, 6.2, 11.5, color='#E65100')
card(ax, 11.2, 11.75, '1', '#E65100')
card(ax, 6.0, 11.75, '1', '#E65100')

# ══════════════════════════════════════════════════════════════════════════════
#  LEGENDE
# ══════════════════════════════════════════════════════════════════════════════
lx, ly = 18.5, 6.2
ax.add_patch(mpatches.FancyBboxPatch(
    (lx, ly-3.2), 7.5, 3.4,
    boxstyle='round,pad=0.1', lw=1.5,
    edgecolor='#90CAF9', facecolor='#E3F2FD'))
ax.text(lx+3.75, ly-0.2, 'Legende',
        ha='center', fontsize=9.5, fontweight='bold', color='#1565C0')

legend_items = [
    (C_PK[:-2]+'FF', 'PK', 'Cle primaire'),
    (C_FK[:-2]+'FF', 'FK', 'Cle etrangere'),
]
for i, (bg, tag, desc) in enumerate(legend_items):
    iy = ly - 0.75 - i*0.65
    ax.add_patch(mpatches.Rectangle(
        (lx+0.3, iy-0.18), 0.6, 0.36,
        facecolor=bg, edgecolor='#9E9E9E', lw=0.8))
    ax.text(lx+0.60, iy, tag,
            ha='center', va='center', fontsize=7.5,
            fontweight='bold',
            color='#F57F17' if tag=='PK' else '#2E7D32')
    ax.text(lx+1.05, iy, desc,
            ha='left', va='center', fontsize=8.5, color='#212121')

# relation lines legend
rel_items = [
    ('#1565C0', 'users → reservations  (1:N)'),
    ('#2E7D32', 'reservations → passengers  (1:N)'),
    ('#E65100', 'reservations → payments  (1:1)'),
]
for i, (col, desc) in enumerate(rel_items):
    iy = ly - 1.95 - i*0.55
    ax.annotate('', xy=(lx+0.9, iy), xytext=(lx+0.3, iy),
                arrowprops=dict(arrowstyle='-|>', color=col,
                                lw=1.5, mutation_scale=10))
    ax.text(lx+1.05, iy, desc,
            ha='left', va='center', fontsize=8, color='#212121')

# ══════════════════════════════════════════════════════════════════════════════
#  TITRE
# ══════════════════════════════════════════════════════════════════════════════
ax.text(14, 19.7,
        "Schema Relationnel — Systeme de Reservation de Vols",
        ha='center', va='center', fontsize=13,
        fontweight='bold', color='#0D47A1',
        bbox=dict(boxstyle='round,pad=0.4',
                  facecolor='#E3F2FD', edgecolor='#1565C0', lw=2))

plt.tight_layout(pad=0.5)
plt.savefig('c:/Users/tassili/Desktop/pfe/schema_relationnel.png',
            dpi=100, bbox_inches=None, facecolor='#F5F5F5')
print("Sauvegarde: schema_relationnel.png")

# Verifier la resolution
from PIL import Image
img = Image.open('c:/Users/tassili/Desktop/pfe/schema_relationnel.png')
print(f"Resolution: {img.size[0]} x {img.size[1]} pixels")
