import logging
import pandas as pd
from mlxtend.frequent_patterns import apriori, association_rules
from mlxtend.preprocessing import TransactionEncoder

logger = logging.getLogger("flights")


def get_recommendations(origin: str, min_support: float = 0.05, min_confidence: float = 0.3) -> list:
    """
    Applique l'algorithme A priori sur les reservations confirmees.
    Retourne les destinations les plus souvent associees a l'origine donnee.

    Args:
        origin:         Code IATA de l'aeroport d'origine (ex: 'ALG')
        min_support:    Seuil minimum de support (defaut 5%)
        min_confidence: Seuil minimum de confiance (defaut 30%)

    Returns:
        Liste des destinations recommandees triees par confiance decroissante.
    """
    from apps.reservations.models import Reservation

    # ── 1. Recuperer les reservations confirmees ──────────────────────────────
    reservations = list(
        Reservation.objects.filter(status="confirmed")
        .values("user_id", "raw_duffel_order")
    )

    logger.info("Apriori: %d reservations confirmees trouvees", len(reservations))

    if len(reservations) < 5:
        logger.info("Apriori: pas assez de donnees (minimum 5 reservations)")
        return []

    # ── 2. Construire les transactions par utilisateur ─────────────────────────
    user_trips: dict = {}
    for r in reservations:
        uid  = str(r["user_id"])
        data = r["raw_duffel_order"] or {}
        slices = data.get("slices", [])
        if not slices:
            continue

        first_seg = (slices[0].get("segments") or [{}])[0]
        last_seg  = (slices[0].get("segments") or [{}])[-1]
        orig = (first_seg.get("origin")      or {}).get("iata_code", "")
        dest = (last_seg.get("destination")  or {}).get("iata_code", "")

        if orig and dest and orig != dest:
            trajet = f"{orig}-{dest}"
            user_trips.setdefault(uid, set()).add(trajet)

    transactions = [list(v) for v in user_trips.values() if len(v) >= 1]
    logger.info("Apriori: %d utilisateurs distincts", len(transactions))

    if len(transactions) < 3:
        return []

    # ── 3. Encoder les transactions ───────────────────────────────────────────
    te       = TransactionEncoder()
    te_array = te.fit_transform(transactions)
    df       = pd.DataFrame(te_array, columns=te.columns_)

    # ── 4. Appliquer A priori ─────────────────────────────────────────────────
    try:
        frequent_itemsets = apriori(df, min_support=min_support, use_colnames=True)
        if frequent_itemsets.empty:
            logger.info("Apriori: aucun itemset frequent trouve")
            return []

        rules = association_rules(
            frequent_itemsets,
            metric="confidence",
            min_threshold=min_confidence,
        )
    except Exception as e:
        logger.warning("Apriori erreur: %s", e)
        return []

    if rules.empty:
        return []

    # ── 5. Filtrer les regles pour l'origine demandee ─────────────────────────
    results = []
    seen    = set()
    for _, rule in rules.iterrows():
        antecedents = list(rule["antecedents"])
        consequents = list(rule["consequents"])

        for ant in antecedents:
            if not ant.startswith(origin.upper()):
                continue
            for cons in consequents:
                parts = cons.split("-")
                if len(parts) != 2:
                    continue
                dest_iata = parts[1]
                if dest_iata in seen or dest_iata == origin.upper():
                    continue
                seen.add(dest_iata)
                results.append({
                    "destination": dest_iata,
                    "trajet":      cons,
                    "support":     round(float(rule["support"]),    3),
                    "confidence":  round(float(rule["confidence"]), 3),
                    "lift":        round(float(rule["lift"]),        3),
                })

    results.sort(key=lambda x: x["confidence"], reverse=True)
    logger.info("Apriori: %d recommandations pour %s", len(results), origin)
    return results[:5]
