import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch
import matplotlib.patheffects as pe

plt.rcParams.update({
    'font.family': 'DejaVu Sans',
    'font.size': 10,
    'figure.dpi': 300,
})

fig, ax = plt.subplots(1, 1, figsize=(32, 42))
ax.set_xlim(0, 24)
ax.set_ylim(0, 32)
ax.axis('off')
fig.patch.set_facecolor('#FFFFFF')

# ── helpers ───────────────────────────────────────────────────────────────────

def draw_class(ax, x, y, w, title, attributes, methods=None,
               abstract=False, color='#DDEEFF', title_color='#1565C0'):
    methods = methods or []
    row_h = 0.42
    title_h = 0.65
    sep = 0.10
    attr_h = len(attributes) * row_h + sep * 2
    meth_h = len(methods) * row_h + sep * 2 if methods else 0
    total_h = title_h + attr_h + meth_h

    # shadow
    shadow = mpatches.FancyBboxPatch((x + 0.06, y - total_h - 0.06), w, total_h,
        boxstyle="round,pad=0.04", linewidth=0, facecolor='#CCCCCC', zorder=1)
    ax.add_patch(shadow)

    # main box
    box = mpatches.FancyBboxPatch((x, y - total_h), w, total_h,
        boxstyle="round,pad=0.04", linewidth=2.0,
        edgecolor='#1565C0', facecolor='white', zorder=2)
    ax.add_patch(box)

    # title bar
    title_bar = mpatches.FancyBboxPatch((x, y - title_h), w, title_h,
        boxstyle="round,pad=0.04", linewidth=0, facecolor=color, zorder=3)
    ax.add_patch(title_bar)

    # title text
    prefix = '<<Abstract>>\n' if abstract else ''
    ax.text(x + w/2, y - title_h/2, prefix + title,
            ha='center', va='center', fontsize=9.5, fontweight='bold',
            color='white', zorder=4, linespacing=1.4)

    # divider after title
    ax.plot([x, x+w], [y - title_h, y - title_h], color='#1565C0', lw=1.2, zorder=4)

    # attributes
    ay = y - title_h - sep
    for attr in attributes:
        ay -= row_h
        ax.text(x + 0.18, ay + row_h/2, attr, ha='left', va='center',
                fontsize=8.0, color='#212121', zorder=4, family='monospace')

    # divider before methods
    if methods:
        div_y = y - title_h - attr_h
        ax.plot([x, x+w], [div_y, div_y], color='#90CAF9', lw=1.0, linestyle='--', zorder=4)
        my = div_y - sep
        for m in methods:
            my -= row_h
            ax.text(x + 0.18, my + row_h/2, m, ha='left', va='center',
                    fontsize=8.0, color='#1A237E', zorder=4, family='monospace',
                    style='italic')

    # return center-bottom point
    return (x + w/2, y - total_h)

def arrow(ax, x1, y1, x2, y2, style='inherit', label='', label_side='mid'):
    if style == 'inherit':
        ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
            arrowprops=dict(arrowstyle='-|>', color='#1565C0', lw=1.5,
                           mutation_scale=14), zorder=5)
    elif style == 'assoc':
        ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
            arrowprops=dict(arrowstyle='->', color='#424242', lw=1.2,
                           mutation_scale=12), zorder=5)
    elif style == 'compose':
        ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
            arrowprops=dict(arrowstyle='->', color='#6A1B9A', lw=1.2,
                           mutation_scale=12,
                           connectionstyle='arc3,rad=0.0'), zorder=5)
    if label:
        mx, my = (x1+x2)/2, (y1+y2)/2
        ax.text(mx+0.1, my+0.1, label, fontsize=6.5, color='#555', zorder=6)

def line(ax, x1, y1, x2, y2, color='#424242', lw=1.0, ls='-'):
    ax.plot([x1, x2], [y1, y2], color=color, lw=lw, linestyle=ls, zorder=4)

def cardinality(ax, x, y, text):
    ax.text(x, y, text, fontsize=6.5, color='#C62828', ha='center', va='center',
            zorder=6, fontweight='bold')

# ── classes ───────────────────────────────────────────────────────────────────

# Utilisateur (abstract) — top center
draw_class(ax, 9.5, 31.5, 5.0, 'Utilisateur',
    ['id : int', 'nom : string', 'prenom : string',
     'email : string', 'password : string', 'role : string'],
    ['register() : void', 'login() : void'],
    abstract=True, color='#1565C0')

# Administrateur — left
draw_class(ax, 1.0, 27.5, 4.5, 'Administrateur', [],
    ['gérerUtilisateurs() : void', 'gérerOffres() : void', 'consulterStatistiques() : void'],
    color='#1976D2')

# Agent — center
draw_class(ax, 7.0, 27.5, 4.5, 'Agent', [],
    ['créerRéservation() : void', 'confirmerRéservation() : void',
     'annulerRéservation() : void', 'créerPourClient() : void'],
    color='#1976D2')

# Client — right
draw_class(ax, 14.5, 27.5, 4.8, 'Client', [],
    ['rechercherVols() : void', 'créerRéservation() : void',
     'annulerRéservation() : void', 'consulterRéservations() : void'],
    color='#1976D2')

# Réservation — center-left
draw_class(ax, 4.5, 22.5, 4.8, 'Réservation',
    ['id : int', 'dateRéservation : DateTime',
     'status : string', 'prix : float',
     'monnaie : string', 'pnr : string'],
    color='#0288D1')

# Paiement — left
draw_class(ax, 0.3, 18.0, 4.2, 'Paiement',
    ['id : int', 'montant : float', 'monnaie : string',
     'methode : string', 'status : string'],
    color='#0288D1')

# BilletDAvion — center
draw_class(ax, 10.2, 22.5, 4.5, 'BilletDAvion',
    ['id : int', 'numeroSiege : int',
     'laClasse : string', 'prix : float'],
    color='#0288D1')

# Passager — right
draw_class(ax, 16.5, 22.5, 4.8, 'Passager',
    ['id : int', 'nom : string', 'prenom : string',
     'dateNaissance : date'],
    color='#0288D1')

# Passeport — far right
draw_class(ax, 19.5, 17.5, 4.2, 'Passeport',
    ['id : int', 'numero : string',
     'dateCreation : date', 'dateExpiration : date'],
    color='#0277BD')

# CompagnieAvion — left
draw_class(ax, 0.3, 13.5, 4.2, 'CompagnieAvion',
    ['id : int', 'nom : string',
     'codeIATA : string', 'logo : string'],
    color='#00838F')

# Vol — center
draw_class(ax, 9.0, 17.0, 4.5, 'Vol',
    ['id : int', 'numeroVol : string',
     'tempDepart : datetime', 'tempArrive : datetime'],
    color='#0277BD')

# Aéroport — bottom center
draw_class(ax, 9.0, 11.5, 4.5, 'Aéroport',
    ['id : int', 'nom : string',
     'codeIATA : string'],
    color='#00838F')

# Pays — right
draw_class(ax, 16.5, 13.5, 4.2, 'Pays',
    ['id : int', 'nom : string', 'codeISO : string'],
    color='#2E7D32')

# Ville — right
draw_class(ax, 16.5, 9.5, 4.2, 'Ville',
    ['id : int', 'nom : string'],
    color='#2E7D32')

# ── inheritance arrows ─────────────────────────────────────────────────────────
# Admin → Utilisateur
arrow(ax, 3.25, 25.42, 10.5, 28.62, style='inherit')
# Agent → Utilisateur
arrow(ax, 9.25, 25.42, 11.0, 28.62, style='inherit')
# Client → Utilisateur
arrow(ax, 16.9, 25.42, 13.2, 28.62, style='inherit')

# ── associations ───────────────────────────────────────────────────────────────
# Client 1 → N Réservation
line(ax, 16.5, 24.5, 9.3, 24.5)
cardinality(ax, 16.3, 24.7, '1')
cardinality(ax, 9.5, 24.7, 'N')

# Réservation 1 → 1 Paiement
line(ax, 4.5, 20.5, 4.5, 18.0)
cardinality(ax, 4.7, 20.2, '1')
cardinality(ax, 4.7, 18.3, '1')

# Réservation 1 → N BilletDAvion
line(ax, 9.3, 21.0, 10.2, 21.0)
cardinality(ax, 9.5, 21.2, '1')
cardinality(ax, 10.0, 21.2, 'N')

# BilletDAvion N → 1 Vol
line(ax, 12.45, 19.42, 11.25, 17.0)
cardinality(ax, 12.3, 19.2, 'N')
cardinality(ax, 11.4, 17.2, '1')

# BilletDAvion N → 1 Passager
line(ax, 14.7, 21.0, 16.5, 21.0)
cardinality(ax, 14.9, 21.2, 'N')
cardinality(ax, 16.3, 21.2, '1')

# Passager 1 → 1 Passeport
line(ax, 21.1, 20.42, 21.6, 17.5)
ax.text(20.2, 19.2, 'Possède', fontsize=7, color='#555', style='italic')
cardinality(ax, 20.9, 20.2, '1')
cardinality(ax, 21.5, 17.7, '1')

# CompagnieAvion 1 → N Vol
line(ax, 4.5, 11.42, 9.0, 14.5)
cardinality(ax, 4.7, 11.6, '1')
cardinality(ax, 8.9, 14.3, 'N')

# Vol N → 1 Aéroport (départ)
line(ax, 10.5, 13.92, 10.5, 11.5)
ax.text(10.7, 12.8, 'Départ', fontsize=7, color='#555')
cardinality(ax, 10.3, 13.7, 'N')
cardinality(ax, 10.3, 11.7, '1')

# Vol N → 1 Aéroport (arrivée)
line(ax, 12.5, 13.92, 12.5, 11.5)
ax.text(12.6, 12.8, 'Arrivée', fontsize=7, color='#555')
cardinality(ax, 12.3, 13.7, 'N')
cardinality(ax, 12.3, 11.7, '1')

# Pays 1 → N Ville
line(ax, 18.6, 11.42, 18.6, 9.5)
cardinality(ax, 18.8, 11.2, '1')
cardinality(ax, 18.8, 9.7, 'N')

# Ville 1 → N Aéroport
line(ax, 16.5, 7.5, 13.5, 9.5)
cardinality(ax, 16.3, 7.6, '1')
cardinality(ax, 13.6, 9.4, 'N')

# ── title ──────────────────────────────────────────────────────────────────────
ax.text(12, 31.8, "Diagramme de Classes — Système de Réservation de Vols",
        ha='center', va='center', fontsize=15, fontweight='bold', color='#0D47A1')

# legend
legend_x, legend_y = 0.3, 5.5
ax.add_patch(mpatches.FancyBboxPatch((legend_x, legend_y - 2.8), 5.5, 3.2,
    boxstyle="round,pad=0.1", linewidth=1, edgecolor='#90CAF9', facecolor='#E3F2FD'))
ax.text(legend_x + 2.75, legend_y - 0.2, 'Légende', ha='center', fontsize=8, fontweight='bold', color='#1565C0')
for i, (col, lbl) in enumerate([
    ('#1565C0', 'Héritage'),
    ('#424242', 'Association'),
]):
    yy = legend_y - 0.8 - i*0.6
    ax.annotate('', xy=(legend_x + 2.0, yy), xytext=(legend_x + 0.4, yy),
        arrowprops=dict(arrowstyle='-|>' if i==0 else '->', color=col, lw=1.5, mutation_scale=12))
    ax.text(legend_x + 2.2, yy, lbl, va='center', fontsize=7.5, color='#212121')

plt.tight_layout(pad=1.0)
plt.savefig('c:/Users/tassili/Desktop/pfe/diagramme_classes.png',
            dpi=300, bbox_inches='tight', facecolor='#FFFFFF',
            metadata={'Title': 'Diagramme de Classes'})
print("Saved: diagramme_classes.png")
