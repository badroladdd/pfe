# -*- coding: utf-8 -*-
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.lines as mlines

plt.rcParams.update({'font.family': 'DejaVu Sans', 'figure.dpi': 300})

BASE = 'c:/Users/tassili/Desktop/pfe/'

C_CLIENT = '#1565C0'
C_AGENT  = '#2E7D32'
C_ADMIN  = '#6A1B9A'
C_SYS    = '#1565C0'

# ── helpers ───────────────────────────────────────────────────────────────────

def draw_actor(ax, x, y, label, color):
    """Bonhomme UML standard."""
    r = 0.30
    ax.add_patch(plt.Circle((x, y + 1.0), r, color='white',
                             ec=color, lw=2, zorder=4))
    ax.plot([x, x],         [y+0.70, y+0.10], color=color, lw=2, zorder=4)
    ax.plot([x-0.45, x+0.45], [y+0.50, y+0.50], color=color, lw=2, zorder=4)
    ax.plot([x, x-0.35],    [y+0.10, y-0.35], color=color, lw=2, zorder=4)
    ax.plot([x, x+0.35],    [y+0.10, y-0.35], color=color, lw=2, zorder=4)
    ax.text(x, y-0.55, label, ha='center', va='top',
            fontsize=9, fontweight='bold', color=color, zorder=5)

def draw_uc(ax, x, y, label, color, rx=1.6, ry=0.4):
    """Ellipse de cas d'utilisation."""
    ax.add_patch(mpatches.Ellipse((x, y), rx*2, ry*2,
                 lw=1.8, edgecolor=color, facecolor='white', zorder=3))
    ax.text(x, y, label, ha='center', va='center',
            fontsize=8.5, color='#212121', zorder=4,
            multialignment='center', linespacing=1.3)
    return (x, y, rx, ry)

def draw_sys_box(ax, x, y, w, h, color, title):
    ax.add_patch(mpatches.FancyBboxPatch(
        (x, y), w, h, boxstyle='round,pad=0.2',
        lw=2, edgecolor=color, facecolor='#F0F4FF', alpha=0.4, zorder=0))
    ax.text(x + w/2, y + h + 0.15, title,
            ha='center', fontsize=10, fontweight='bold', color=color, zorder=5)

def assoc_line(ax, ax1, ay1, uc, color='#424242'):
    x2, y2, rx, ry = uc
    dx, dy = x2-ax1, y2-ay1
    d = max((dx**2+dy**2)**0.5, 0.01)
    ex = x2 - rx*dx/d
    ey = y2 - ry*dy/d
    ax.plot([ax1, ex], [ay1, ey], color=color, lw=1.3, zorder=2)

def include_arr(ax, x1, y1, x2, y2, label='<<include>>'):
    ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
        arrowprops=dict(arrowstyle='->', color='#37474F',
                        lw=1.2, linestyle='dashed', mutation_scale=10), zorder=3)
    mx, my = (x1+x2)/2, (y1+y2)/2
    ax.text(mx, my + 0.18, label, ha='center', va='bottom',
            fontsize=7.5, color='#37474F', style='italic',
            bbox=dict(boxstyle='round,pad=0.15', facecolor='white',
                      edgecolor='none', alpha=0.9), zorder=5)

def extend_arr(ax, x1, y1, x2, y2, label='<<extend>>'):
    ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
        arrowprops=dict(arrowstyle='->', color='#E65100',
                        lw=1.2, linestyle='dashed', mutation_scale=10), zorder=3)
    mx, my = (x1+x2)/2, (y1+y2)/2
    ax.text(mx, my + 0.18, label, ha='center', va='bottom',
            fontsize=7.5, color='#E65100', style='italic',
            bbox=dict(boxstyle='round,pad=0.15', facecolor='white',
                      edgecolor='none', alpha=0.9), zorder=5)

def title_box(ax, cx, y, text):
    ax.text(cx, y, text, ha='center', va='center', fontsize=12,
            fontweight='bold', color='#0D47A1',
            bbox=dict(boxstyle='round,pad=0.4', facecolor='#E3F2FD',
                      edgecolor='#1565C0', lw=1.5), zorder=6)

# ══════════════════════════════════════════════════════════════════════════════
#  1 — GLOBAL
# ══════════════════════════════════════════════════════════════════════════════
fig, ax = plt.subplots(figsize=(26, 20))
ax.set_xlim(0, 26); ax.set_ylim(0, 20); ax.axis('off')
fig.patch.set_facecolor('white')

title_box(ax, 13, 19.4, "Diagramme de Cas d'Utilisation Global — Systeme de Reservation de Vols")
draw_sys_box(ax, 3.0, 0.5, 20.5, 18.0, '#1565C0', "Systeme de Reservation de Vols")

# acteurs
draw_actor(ax, 1.2, 12.5, "Client",          C_CLIENT)
draw_actor(ax, 1.2,  5.5, "Agent",           C_AGENT)
draw_actor(ax, 24.8, 9.5, "Administrateur",  C_ADMIN)

# ── UC Client
uc_login  = draw_uc(ax, 8.5, 17.5, "Se connecter",         C_CLIENT)
uc_profil = draw_uc(ax, 8.5, 15.8, "Consulter profil",     C_CLIENT)
uc_search = draw_uc(ax, 8.5, 14.1, "Rechercher des vols",  C_CLIENT)
uc_res    = draw_uc(ax, 8.5, 12.4, "Reserver un vol",      C_CLIENT)
uc_promo  = draw_uc(ax, 8.5, 10.7, "Appliquer code promo", C_CLIENT)
uc_trips  = draw_uc(ax, 8.5,  9.0, "Consulter mes voyages",C_CLIENT)
uc_canc   = draw_uc(ax, 8.5,  7.3, "Annuler reservation",  C_CLIENT)

# ── UC Agent
uc_allres  = draw_uc(ax, 14.0, 12.4, "Voir toutes\nles reservations", C_AGENT)
uc_confirm = draw_uc(ax, 14.0, 10.7, "Confirmer\nreservation",        C_AGENT)
uc_canc_a  = draw_uc(ax, 14.0,  9.0, "Annuler reservation\n(Agent)",  C_AGENT)
uc_book4c  = draw_uc(ax, 14.0,  7.3, "Reserver pour\nun client",      C_AGENT)
uc_stats_a = draw_uc(ax, 14.0,  5.6, "Voir statistiques",             C_AGENT)

# ── UC Admin
uc_users   = draw_uc(ax, 20.5, 16.5, "Gerer utilisateurs",        C_ADMIN)
uc_creu    = draw_uc(ax, 20.5, 14.8, "Creer utilisateur",         C_ADMIN)
uc_blok    = draw_uc(ax, 20.5, 13.1, "Bloquer / Debloquer",       C_ADMIN)
uc_del     = draw_uc(ax, 20.5, 11.4, "Supprimer utilisateur",     C_ADMIN)
uc_promo_m = draw_uc(ax, 20.5,  9.7, "Gerer codes promo",         C_ADMIN)
uc_stats_d = draw_uc(ax, 20.5,  8.0, "Voir statistiques\n(Admin)",C_ADMIN)

# associations client
for u in [uc_login, uc_profil, uc_search, uc_res, uc_promo, uc_trips, uc_canc]:
    assoc_line(ax, 2.0, 13.2, u, C_CLIENT)

# associations agent
for u in [uc_login, uc_allres, uc_confirm, uc_canc_a, uc_book4c, uc_stats_a]:
    assoc_line(ax, 2.0, 6.2, u, C_AGENT)

# associations admin
for u in [uc_login, uc_users, uc_creu, uc_blok, uc_del, uc_promo_m, uc_stats_d]:
    assoc_line(ax, 24.2, 10.2, u, C_ADMIN)

# include / extend
include_arr(ax, 8.5, 11.96, 8.5, 17.1)    # reserver <<include>> login
extend_arr (ax, 8.5, 11.14, 8.5, 11.30)   # promo <<extend>> reserver
include_arr(ax, 14.0, 11.14, 14.0, 11.96) # confirmer <<include>> voir reservations
include_arr(ax, 20.5, 14.4, 20.5, 17.1)   # gerer users <<include>> login
include_arr(ax, 20.5, 16.1, 20.5, 14.8)   # creer <<include>> gerer users
include_arr(ax, 20.8, 16.1, 20.8, 13.1)   # bloquer <<include>> gerer users
include_arr(ax, 21.0, 16.1, 21.0, 11.4)   # supprimer <<include>> gerer users

# legende
lx, ly = 3.5, 4.5
ax.add_patch(mpatches.FancyBboxPatch((lx, ly-2.8), 9, 3.2,
    boxstyle='round,pad=0.1', lw=1.2, edgecolor='#90CAF9', facecolor='#E3F2FD'))
ax.text(lx+4.5, ly-0.15, 'Legende', ha='center', fontsize=9, fontweight='bold', color='#1565C0')
for i,(col,name,desc) in enumerate([
    (C_CLIENT,'Client','Utilisateur final de l\'application'),
    (C_AGENT, 'Agent', 'Confirme et gere les reservations'),
    (C_ADMIN, 'Admin', 'Gere utilisateurs et configuration'),
]):
    iy = ly - 0.75 - i*0.7
    ax.add_patch(plt.Circle((lx+0.3, iy), 0.18, color='white', ec=col, lw=1.5))
    ax.text(lx+0.65, iy, f'{name} : {desc}', va='center', fontsize=8, color='#212121')
for i,(col,lbl,desc) in enumerate([
    ('#37474F','<<include>>','relation obligatoire'),
    ('#E65100','<<extend>>','relation optionnelle'),
]):
    iy = ly - 2.2 - i*0.55
    ax.annotate('',xy=(lx+0.8,iy),xytext=(lx+0.2,iy),
        arrowprops=dict(arrowstyle='->',color=col,lw=1.2,
                        linestyle='dashed',mutation_scale=10))
    ax.text(lx+0.95, iy, f'{lbl} : {desc}', va='center',
            fontsize=8, color=col, style='italic')

plt.tight_layout(pad=0.3)
plt.savefig(BASE+'uc_0_global.png', dpi=180, bbox_inches='tight', facecolor='white')
plt.close(); print("OK uc_0_global.png")

# ══════════════════════════════════════════════════════════════════════════════
#  2 — CLIENT
# ══════════════════════════════════════════════════════════════════════════════
fig, ax = plt.subplots(figsize=(14, 18))
ax.set_xlim(0, 14); ax.set_ylim(0, 18); ax.axis('off')
fig.patch.set_facecolor('white')

title_box(ax, 7, 17.4, "Cas d'Utilisation — Client")
draw_sys_box(ax, 2.5, 0.5, 10, 16.4, C_CLIENT, "Systeme")
draw_actor(ax, 1.0, 9.0, "Client", C_CLIENT)

ucs_c = [
    draw_uc(ax, 7.5, 15.8, "Se connecter",          C_CLIENT),
    draw_uc(ax, 7.5, 14.2, "Consulter profil",       C_CLIENT),
    draw_uc(ax, 7.5, 12.6, "Rechercher des vols",    C_CLIENT),
    draw_uc(ax, 7.5, 11.0, "Reserver un vol",        C_CLIENT),
    draw_uc(ax, 7.5,  9.4, "Appliquer code promo",   C_CLIENT),
    draw_uc(ax, 7.5,  7.8, "Consulter mes voyages",  C_CLIENT),
    draw_uc(ax, 7.5,  6.2, "Annuler reservation",    C_CLIENT),
    draw_uc(ax, 7.5,  4.6, "Telecharger billet PDF", C_CLIENT),
]
for u in ucs_c:
    assoc_line(ax, 1.8, 9.7, u, C_CLIENT)

include_arr(ax, 7.5, 10.6, 7.5, 15.4)   # reserver <<include>> login
extend_arr (ax, 7.5,  9.8, 7.5, 10.6)   # promo <<extend>> reserver
include_arr(ax, 7.5,  5.8, 7.5,  7.4)   # annuler <<include>> consulter voyages
include_arr(ax, 7.5,  4.2, 7.5, 10.6)   # PDF <<include>> reserver

plt.tight_layout(pad=0.3)
plt.savefig(BASE+'uc_1_client.png', dpi=180, bbox_inches='tight', facecolor='white')
plt.close(); print("OK uc_1_client.png")

# ══════════════════════════════════════════════════════════════════════════════
#  3 — AGENT
# ══════════════════════════════════════════════════════════════════════════════
fig, ax = plt.subplots(figsize=(14, 18))
ax.set_xlim(0, 14); ax.set_ylim(0, 18); ax.axis('off')
fig.patch.set_facecolor('white')

title_box(ax, 7, 17.4, "Cas d'Utilisation — Agent")
draw_sys_box(ax, 2.5, 0.5, 10, 16.4, C_AGENT, "Systeme")
draw_actor(ax, 1.0, 9.0, "Agent", C_AGENT)

ucs_a = [
    draw_uc(ax, 7.5, 15.8, "Se connecter",                  C_AGENT),
    draw_uc(ax, 7.5, 14.2, "Voir toutes les reservations",   C_AGENT),
    draw_uc(ax, 7.5, 12.6, "Confirmer reservation",         C_AGENT),
    draw_uc(ax, 7.5, 11.0, "Annuler reservation",           C_AGENT),
    draw_uc(ax, 7.5,  9.4, "Reserver pour un client",       C_AGENT),
    draw_uc(ax, 7.5,  7.8, "Voir statistiques",             C_AGENT),
    draw_uc(ax, 7.5,  6.2, "Rechercher un client",          C_AGENT),
    draw_uc(ax, 7.5,  4.6, "Voir detail reservation",       C_AGENT),
]
for u in ucs_a:
    assoc_line(ax, 1.8, 9.7, u, C_AGENT)

include_arr(ax, 7.5, 12.2, 7.5, 13.8)   # confirmer <<include>> voir reservations
include_arr(ax, 7.5, 10.6, 7.5, 13.8)   # annuler <<include>> voir reservations
include_arr(ax, 7.5,  4.2, 7.5, 13.8)   # voir detail <<include>> voir reservations
include_arr(ax, 7.5, 15.4, 7.5, 15.4)   # (pas de fleche supplémentaire)

plt.tight_layout(pad=0.3)
plt.savefig(BASE+'uc_2_agent.png', dpi=180, bbox_inches='tight', facecolor='white')
plt.close(); print("OK uc_2_agent.png")

# ══════════════════════════════════════════════════════════════════════════════
#  4 — ADMIN
# ══════════════════════════════════════════════════════════════════════════════
fig, ax = plt.subplots(figsize=(14, 20))
ax.set_xlim(0, 14); ax.set_ylim(0, 20); ax.axis('off')
fig.patch.set_facecolor('white')

title_box(ax, 7, 19.4, "Cas d'Utilisation — Administrateur")
draw_sys_box(ax, 2.5, 0.5, 10, 18.4, C_ADMIN, "Systeme")
draw_actor(ax, 1.0, 10.5, "Administrateur", C_ADMIN)

ucs_d = [
    draw_uc(ax, 7.5, 17.8, "Se connecter",           C_ADMIN),
    draw_uc(ax, 7.5, 16.2, "Gerer utilisateurs",     C_ADMIN),
    draw_uc(ax, 7.5, 14.6, "Creer utilisateur",      C_ADMIN),
    draw_uc(ax, 7.5, 13.0, "Modifier utilisateur",   C_ADMIN),
    draw_uc(ax, 7.5, 11.4, "Bloquer / Debloquer",    C_ADMIN),
    draw_uc(ax, 7.5,  9.8, "Supprimer utilisateur",  C_ADMIN),
    draw_uc(ax, 7.5,  8.2, "Gerer codes promo",      C_ADMIN),
    draw_uc(ax, 7.5,  6.6, "Creer code promo",       C_ADMIN),
    draw_uc(ax, 7.5,  5.0, "Voir statistiques",      C_ADMIN),
]
for u in ucs_d:
    assoc_line(ax, 1.8, 11.2, u, C_ADMIN)

include_arr(ax, 7.5, 17.4, 7.5, 17.4)
include_arr(ax, 7.5, 15.8, 7.5, 15.8)
include_arr(ax, 7.5, 14.2, 7.5, 15.8)   # creer <<include>> gerer users
include_arr(ax, 7.8, 14.2, 7.8, 15.8)   # modifier <<include>> gerer users
include_arr(ax, 8.0, 14.2, 8.0, 15.8)   # bloquer <<include>> gerer users
include_arr(ax, 8.2, 14.2, 8.2, 15.8)   # supprimer <<include>> gerer users
include_arr(ax, 7.5,  6.2, 7.5,  7.8)   # creer promo <<include>> gerer promos
include_arr(ax, 7.5, 17.4, 7.5, 17.4)

# liens corrects
include_arr(ax, 7.5, 14.20, 7.5, 15.82)
include_arr(ax, 7.7, 12.62, 7.7, 15.82)
include_arr(ax, 7.9, 11.02, 7.9, 15.82)
include_arr(ax, 8.1,  9.42, 8.1, 15.82)
include_arr(ax, 7.5,  6.22, 7.5,  7.82)

plt.tight_layout(pad=0.3)
plt.savefig(BASE+'uc_3_admin.png', dpi=180, bbox_inches='tight', facecolor='white')
plt.close(); print("OK uc_3_admin.png")

print("\nTous les use cases regeneres !")
