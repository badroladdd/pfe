import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

plt.rcParams.update({'font.family': 'DejaVu Sans', 'figure.dpi': 300})

C_ACTOR = '#1565C0'
C_SYS   = '#2E7D32'
C_OBJ   = '#6A1B9A'
C_EXT   = '#E65100'
C_DB    = '#37474F'

ROW_H   = 0.70   # hauteur par message
ACTOR_H = 0.75

def seq(title, actors, messages, figw=14, filename=None):
    """
    messages items:
      (fi, ti, text, style)              style: call | return | self
      ('alt',   label)                   debut alt
      ('else',  label)                   branche else
      ('end_alt',)                       fin alt
      ('loop',  label)                   debut loop
      ('end_loop',)                      fin loop
      ('ref',   label)                   fragment ref
    """

    n = len(actors)

    # -- pre-pass: compter les lignes reelles
    rows = sum(1 for m in messages if not isinstance(m[0], str) or m[0] not in ('alt','else','end_alt','loop','end_loop'))
    figh = max(rows * ROW_H + 4.5, 6)

    fig, ax = plt.subplots(figsize=(figw, figh))
    fig.patch.set_facecolor('white')
    ax.set_xlim(-0.3, n - 0.7)
    ax.set_ylim(-figh + 2.2, 2.8)
    ax.axis('off')

    xs = list(range(n))

    # titre
    ax.text((n-1)/2, 2.55, title,
            ha='center', va='center', fontsize=11, fontweight='bold', color='#0D47A1',
            bbox=dict(boxstyle='round,pad=0.4', facecolor='#E3F2FD',
                      edgecolor='#1565C0', lw=1.5))

    # boites acteurs
    for i, (lbl, color) in enumerate(actors):
        ax.add_patch(mpatches.FancyBboxPatch(
            (xs[i]-0.38, 1.55), 0.76, ACTOR_H,
            boxstyle='round,pad=0.05', lw=2,
            edgecolor=color, facecolor=color, zorder=4))
        ax.text(xs[i], 1.93, lbl.replace(' ', '\n'),
                ha='center', va='center', fontsize=8,
                fontweight='bold', color='white', zorder=5, linespacing=1.3)

    bottom = -(rows + 0.5) * ROW_H - 0.5
    for i in range(n):
        ax.plot([xs[i], xs[i]], [1.55, bottom],
                color='#B0BEC5', lw=1.1, linestyle='--', zorder=1)

    # -- dessin des messages + fragments
    y        = 1.55 - ROW_H * 0.6   # position courante
    row_idx  = 0

    # pile pour alt/loop : (type, y_top, x_left, x_right, label)
    stack = []

    def x_left():
        return -0.28

    def x_right():
        return n - 0.72

    for msg in messages:

        # ── fragments ─────────────────────────────────────────────────────────
        if isinstance(msg[0], str):
            kind = msg[0]

            if kind == 'alt':
                y_top = y + ROW_H * 0.4
                stack.append({'type':'alt', 'y_top': y_top,
                               'y_else': None, 'label': msg[1]})
                # rectangle (tracé a la fin)
                continue

            elif kind == 'else':
                if stack:
                    stack[-1]['y_else'] = y + ROW_H * 0.15
                    # ligne pointillee
                    ax.plot([x_left(), x_right()],
                            [y + ROW_H*0.15, y + ROW_H*0.15],
                            color='#546E7A', lw=1, linestyle='--', zorder=3)
                    ax.text(x_left()+0.07, y + ROW_H*0.15 - 0.12,
                            '['+msg[1]+']',
                            fontsize=7.5, color='#37474F',
                            style='italic', zorder=5)
                continue

            elif kind == 'end_alt':
                if stack:
                    fr = stack.pop()
                    y_bot = y + ROW_H * 0.05
                    xl, xr = x_left(), x_right()
                    # rectangle principal
                    ax.add_patch(mpatches.FancyBboxPatch(
                        (xl, y_bot), xr-xl, fr['y_top']-y_bot,
                        boxstyle='square,pad=0',
                        lw=1.5, edgecolor='#546E7A',
                        facecolor='#ECEFF1', alpha=0.25, zorder=0))
                    # etiquette
                    ax.add_patch(mpatches.FancyBboxPatch(
                        (xl, fr['y_top']-0.28), 0.45, 0.28,
                        boxstyle='square,pad=0',
                        lw=1.5, edgecolor='#546E7A',
                        facecolor='#CFD8DC', zorder=3))
                    ax.text(xl+0.22, fr['y_top']-0.14, 'alt',
                            ha='center', va='center',
                            fontsize=8, fontweight='bold',
                            color='#263238', zorder=4)
                    # condition vraie
                    ax.text(xl+0.55, fr['y_top']-0.14,
                            '['+fr['label']+']',
                            fontsize=7.5, color='#37474F',
                            style='italic', zorder=4)
                continue

            elif kind == 'loop':
                y_top = y + ROW_H * 0.65
                stack.append({'type':'loop', 'y_top': y_top, 'label': msg[1]})
                continue

            elif kind == 'end_loop':
                if stack:
                    fr = stack.pop()
                    y_bot = y - ROW_H * 0.15
                    xl, xr = x_left(), x_right()
                    # rectangle loop
                    ax.add_patch(mpatches.FancyBboxPatch(
                        (xl, y_bot), xr-xl, fr['y_top']-y_bot,
                        boxstyle='square,pad=0',
                        lw=2.0, edgecolor='#1B5E20',
                        facecolor='#E8F5E9', alpha=0.35, zorder=0))
                    # etiquette "loop"
                    lbl_w = 0.65
                    ax.add_patch(mpatches.FancyBboxPatch(
                        (xl, fr['y_top']-0.32), lbl_w, 0.32,
                        boxstyle='square,pad=0',
                        lw=2.0, edgecolor='#1B5E20',
                        facecolor='#C8E6C9', zorder=3))
                    ax.text(xl + lbl_w/2, fr['y_top']-0.16, 'loop',
                            ha='center', va='center',
                            fontsize=8.5, fontweight='bold',
                            color='#1B5E20', zorder=4)
                    # condition
                    ax.text(xl + lbl_w + 0.15, fr['y_top']-0.16,
                            '['+fr['label']+']',
                            fontsize=7.5, color='#2E7D32',
                            style='italic', zorder=4,
                            bbox=dict(boxstyle='round,pad=0.15',
                                      facecolor='white', edgecolor='none', alpha=0.85))
                continue

            elif kind == 'ref':
                xl, xr = x_left(), x_right()
                h = ROW_H * 0.8
                ax.add_patch(mpatches.FancyBboxPatch(
                    (xl, y - h + ROW_H*0.1), xr-xl, h,
                    boxstyle='square,pad=0',
                    lw=1.5, edgecolor='#0277BD',
                    facecolor='#E1F5FE', alpha=0.5, zorder=0))
                ax.add_patch(mpatches.FancyBboxPatch(
                    (xl, y + ROW_H*0.1 - 0.28), 0.42, 0.28,
                    boxstyle='square,pad=0',
                    lw=1.5, edgecolor='#0277BD',
                    facecolor='#B3E5FC', zorder=3))
                ax.text(xl+0.21, y+ROW_H*0.1-0.14, 'ref',
                        ha='center', va='center',
                        fontsize=8, fontweight='bold',
                        color='#01579B', zorder=4)
                ax.text((xl+xr)/2, y - h/2 + ROW_H*0.1,
                        msg[1],
                        ha='center', va='center',
                        fontsize=9, color='#01579B',
                        fontweight='bold', zorder=4)
                y -= ROW_H
                row_idx += 1
                continue

        # ── message normal ────────────────────────────────────────────────────
        fi, ti, text, style = msg
        cur_y = y
        y -= ROW_H
        row_idx += 1

        if style == 'self':
            sx = xs[fi]
            _, sc = actors[fi]
            lp = sx + 0.32
            ax.plot([sx+0.06, lp, lp, sx+0.06],
                    [cur_y, cur_y, cur_y-0.28, cur_y-0.28],
                    color=sc, lw=1.5, zorder=3)
            ax.annotate('', xy=(sx+0.08, cur_y-0.28),
                        xytext=(lp, cur_y-0.28),
                        arrowprops=dict(arrowstyle='->',
                                        color=sc, lw=1.4,
                                        mutation_scale=10), zorder=4)
            ax.text(lp+0.07, cur_y-0.14, text,
                    ha='left', va='center', fontsize=8, color='#212121',
                    bbox=dict(boxstyle='round,pad=0.2',
                              facecolor='white', edgecolor='none', alpha=0.9))
            continue

        x1, x2  = xs[fi], xs[ti]
        is_ret   = (style == 'return')
        _, ac    = actors[ti]
        col_arr  = '#9E9E9E' if is_ret else ac
        ls       = '--' if is_ret else '-'
        pad      = 0.10

        # barre activation
        _, sc = actors[fi]
        ax.add_patch(mpatches.Rectangle(
            (xs[fi]-0.055, cur_y-0.16), 0.11, 0.32,
            lw=0, facecolor=sc, alpha=0.35, zorder=2))

        dx = x2 - x1
        ax.annotate('',
            xy    =(x2-(pad if dx>0 else -pad), cur_y),
            xytext=(x1+(pad if dx>0 else -pad), cur_y),
            arrowprops=dict(arrowstyle='->',
                            color=col_arr, lw=1.6,
                            linestyle=ls,
                            mutation_scale=12), zorder=3)

        mx = (x1+x2)/2
        ax.text(mx, cur_y+0.13, text,
                ha='center', va='bottom', fontsize=8.2,
                color='#424242' if not is_ret else '#757575',
                style='italic' if is_ret else 'normal',
                bbox=dict(boxstyle='round,pad=0.2',
                          facecolor='white', edgecolor='none', alpha=0.9))

    plt.tight_layout(pad=0.6)
    if filename:
        plt.savefig(filename, dpi=200, bbox_inches='tight', facecolor='white')
        print(f"  OK {filename.split('/')[-1]}")
    plt.close()


BASE = 'c:/Users/tassili/Desktop/pfe/'

# ══════════════════════════════════════════════════════════════════════════════
#  1 — Authentification
# ══════════════════════════════════════════════════════════════════════════════
seq("Diagramme de Sequence - Authentification",
    [("Client", C_ACTOR), (":Systeme", C_SYS), (":BDD", C_DB)],
    [
        (0, 1, "sAuthentifier(email, motDePasse)", 'call'),
        (1, 2, "trouverParEmail(email)",           'call'),
        ('alt', 'utilisateur trouve'),
            (2, 1, "utilisateur",                  'return'),
            (1, 1, "verifierMotDePasse()",         'self'),
            ('alt', 'mot de passe correct'),
                (1, 0, "tokenAcces + tokenRafraichissement", 'return'),
                (0, 0, "stocker tokens",           'self'),
            ('else', 'mot de passe incorrect'),
                (1, 0, "erreur : identifiants invalides", 'return'),
            ('end_alt',),
        ('else', 'utilisateur non trouve'),
            (2, 1, "non trouve",                   'return'),
            (1, 0, "erreur : compte inexistant",   'return'),
        ('end_alt',),
    ],
    figw=13, filename=BASE+'seq_1_authentification.png')

# ══════════════════════════════════════════════════════════════════════════════
#  2 — Inscription
# ══════════════════════════════════════════════════════════════════════════════
seq("Diagramme de Sequence - Inscription",
    [("Client", C_ACTOR), (":Systeme", C_SYS), (":BDD", C_DB)],
    [
        (0, 1, "sInscrire(nom, email, motDePasse)", 'call'),
        (1, 2, "emailExiste(email)",                'call'),
        ('alt', 'email disponible'),
            (2, 1, "non",                           'return'),
            (1, 1, "hasherMotDePasse()",            'self'),
            (1, 2, "sauvegarder(utilisateur)",      'call'),
            (2, 1, "utilisateur.id",                'return'),
            (1, 0, "confirmation inscription",      'return'),
        ('else', 'email deja utilise'),
            (2, 1, "oui",                           'return'),
            (1, 0, "erreur : email existe deja",    'return'),
        ('end_alt',),
    ],
    figw=13, filename=BASE+'seq_2_inscription.png')

# ══════════════════════════════════════════════════════════════════════════════
#  3 — Recherche de vols
# ══════════════════════════════════════════════════════════════════════════════
seq("Diagramme de Sequence - Recherche de Vols",
    [("Client", C_ACTOR), (":Systeme", C_SYS), (":Vol", C_OBJ),
     ("Service\nVols", C_EXT), (":BDD", C_DB)],
    [
        (0, 1, "rechercherVols(origine, destination,\ndateDepart, passagers)", 'call'),
        (1, 2, "preparerCriteres(passagers, classe)", 'call'),
        (2, 1, "criteres",                            'return'),
        (1, 3, "obtenirVols(criteres)",               'call'),
        (3, 1, "listeVols[]",                         'return'),
        ('alt', 'vols trouves [listeVols non vide]'),
            (1, 1, "traiterResultats()",              'self'),
            ('loop', 'pour chaque vol de listeVols'),
                (1, 2, "attacherResume(vol)",         'call'),
                (2, 1, "vol avec resume",             'return'),
            ('end_loop',),
            (1, 4, "mettreEnCache(vols)",             'call'),
            (4, 1, "OK",                              'return'),
            (1, 0, "resultatsVols[]",                 'return'),
        ('else', 'aucun vol disponible [listeVols vide]'),
            (1, 0, "liste vide",                      'return'),
        ('end_alt',),
    ],
    figw=16, filename=BASE+'seq_3_recherche_vols.png')

# ══════════════════════════════════════════════════════════════════════════════
#  4 — Réservation client
# ══════════════════════════════════════════════════════════════════════════════
seq("Diagramme de Sequence - Reservation (Client)",
    [("Client", C_ACTOR), (":Systeme", C_SYS),
     (":Reservation", C_OBJ), (":Passager", C_OBJ), (":BDD", C_DB)],
    [
        ('ref', 'Authentification'),
        (0, 1, "reserver(offre, infoPassagers)",     'call'),
        ('alt', 'offre disponible'),
            (1, 2, "creerReservation(offre, montant)", 'call'),
            (2, 4, "sauvegarder(reservation)",          'call'),
            (4, 2, "reservation.id",                    'return'),
            (2, 1, "reservation [EN_ATTENTE]",          'return'),
            ('loop', 'pour chaque passager'),
                (1, 3, "enregistrerPassager(info)",     'call'),
                (3, 4, "sauvegarder(passager)",         'call'),
                (4, 3, "passager.id",                   'return'),
                (3, 1, "passager enregistre",           'return'),
            ('end_loop',),
            (1, 0, "confirmationEnAttente(reservation)",'return'),
        ('else', 'offre expiree ou indisponible'),
            (1, 0, "erreur : offre non disponible",     'return'),
        ('end_alt',),
    ],
    figw=17, filename=BASE+'seq_4_reservation_client.png')

# ══════════════════════════════════════════════════════════════════════════════
#  5 — Confirmation agent
# ══════════════════════════════════════════════════════════════════════════════
seq("Diagramme de Sequence - Confirmation Reservation (Agent)",
    [("Agent", C_ACTOR), (":Systeme", C_SYS),
     (":Reservation", C_OBJ), ("Service\nVols", C_EXT), (":BDD", C_DB)],
    [
        ('ref', 'Authentification'),
        (0, 1, "confirmerReservation(id)",               'call'),
        (1, 2, "chargerReservation(id)",                 'call'),
        (2, 4, "trouverParId(id)",                       'call'),
        (4, 2, "reservation",                            'return'),
        (2, 1, "reservation",                            'return'),
        ('alt', 'statut = EN_ATTENTE'),
            (1, 3, "creerBillet(passagers, paiement)",   'call'),
            (3, 1, "billet(idBillet, referencePNR)",     'return'),
            (1, 2, "mettreAJourStatut(CONFIRME, PNR)",   'call'),
            (2, 4, "mettreAJour(reservation)",           'call'),
            (4, 2, "OK",                                 'return'),
            (2, 1, "reservation [CONFIRME]",             'return'),
            (1, 0, "reservation confirmee + PNR",        'return'),
        ('else', 'statut != EN_ATTENTE'),
            (1, 0, "erreur : impossible de confirmer",   'return'),
        ('end_alt',),
    ],
    figw=17, filename=BASE+'seq_5_confirmation_agent.png')

# ══════════════════════════════════════════════════════════════════════════════
#  6 — Annulation
# ══════════════════════════════════════════════════════════════════════════════
seq("Diagramme de Sequence - Annulation de Reservation",
    [("Client /\nAgent", C_ACTOR), (":Systeme", C_SYS),
     (":Reservation", C_OBJ), ("Service\nVols", C_EXT), (":BDD", C_DB)],
    [
        ('ref', 'Authentification'),
        (0, 1, "annulerReservation(id)",               'call'),
        (1, 2, "chargerReservation(id)",               'call'),
        (2, 4, "trouverParId(id)",                     'call'),
        (4, 2, "reservation",                          'return'),
        (2, 1, "reservation",                          'return'),
        ('alt', 'reservation confirmee avec billet'),
            (1, 3, "demanderRemboursement(idBillet)",  'call'),
            (3, 1, "montantRemboursement",             'return'),
            (1, 3, "validerAnnulation()",              'call'),
            (3, 1, "annulation validee",               'return'),
        ('else', 'reservation en attente sans billet'),
            (1, 1, "annulerDirectement()",             'self'),
        ('end_alt',),
        (1, 2, "mettreAJourStatut(ANNULE)",            'call'),
        (2, 4, "mettreAJour(reservation)",             'call'),
        (4, 2, "OK",                                   'return'),
        (2, 1, "reservation [ANNULE]",                 'return'),
        (1, 0, "confirmation annulation",              'return'),
    ],
    figw=17, filename=BASE+'seq_6_annulation.png')

# ══════════════════════════════════════════════════════════════════════════════
#  7 — Code promo
# ══════════════════════════════════════════════════════════════════════════════
seq("Diagramme de Sequence - Application Code Promo",
    [("Client", C_ACTOR), (":Systeme", C_SYS),
     (":CodePromo", C_OBJ), (":BDD", C_DB)],
    [
        (0, 1, "appliquerCodePromo(code, montant)", 'call'),
        (1, 2, "trouverParCode(code)",              'call'),
        (2, 3, "charger(code)",                     'call'),
        ('alt', 'code trouve'),
            (3, 2, "codePromo",                     'return'),
            (2, 1, "codePromo",                     'return'),
            (1, 2, "estValide()",                   'call'),
            (2, 2, "verifier actif + expiration + nbUtilisations", 'self'),
            ('alt', 'code valide'),
                (2, 1, "valide",                    'return'),
                (1, 2, "calculerReduction(montant)",'call'),
                (2, 1, "montantReduit",             'return'),
                (1, 0, "montantAvecReduction",      'return'),
            ('else', 'code expire ou epuise'),
                (2, 1, "invalide",                  'return'),
                (1, 0, "erreur : code invalide",    'return'),
            ('end_alt',),
        ('else', 'code non trouve'),
            (3, 2, "non trouve",                    'return'),
            (2, 1, "non trouve",                    'return'),
            (1, 0, "erreur : code inexistant",      'return'),
        ('end_alt',),
    ],
    figw=14, filename=BASE+'seq_7_code_promo.png')

# ══════════════════════════════════════════════════════════════════════════════
#  8 — Gestion utilisateurs (admin)
# ══════════════════════════════════════════════════════════════════════════════
seq("Diagramme de Sequence - Gestion Utilisateurs (Admin)",
    [("Administrateur", C_ACTOR), (":Systeme", C_SYS), (":BDD", C_DB)],
    [
        ('ref', 'Authentification'),

        # --- Creer utilisateur ---
        (0, 1, "creerUtilisateur(email, role, motDePasse)", 'call'),
        (1, 2, "emailExiste(email)",           'call'),
        ('alt', 'email disponible'),
            (2, 1, "non",                      'return'),
            (1, 1, "hasherMotDePasse()",       'self'),
            (1, 2, "sauvegarder(utilisateur)", 'call'),
            (2, 1, "utilisateur.id",           'return'),
            (1, 0, "utilisateur cree",         'return'),
        ('else', 'email deja utilise'),
            (2, 1, "oui",                      'return'),
            (1, 0, "erreur : email existant",  'return'),
        ('end_alt',),

        # --- Modifier role ---
        (0, 1, "modifierRole(id, nouveauRole)", 'call'),
        (1, 2, "trouverParId(id)",              'call'),
        (2, 1, "utilisateur",                   'return'),
        (1, 2, "mettreAJour(utilisateur)",      'call'),
        (2, 1, "OK",                            'return'),
        (1, 0, "role mis a jour",               'return'),

        # --- Supprimer utilisateurs ---
        ('loop', 'pour chaque utilisateur a supprimer'),
            (0, 1, "supprimerUtilisateur(id)", 'call'),
            (1, 2, "supprimer(id)",            'call'),
            (2, 1, "OK",                       'return'),
            (1, 0, "confirmation suppression", 'return'),
        ('end_loop',),
    ],
    figw=14, filename=BASE+'seq_8_gestion_utilisateurs.png')

print("Tous les diagrammes generes avec alt, loop et ref !")
