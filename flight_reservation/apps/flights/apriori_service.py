import logging
import pandas as pd
from mlxtend.frequent_patterns import apriori, association_rules
from mlxtend.preprocessing import TransactionEncoder

logger = logging.getLogger("flights")

# Codes IATA des aeroports connus (pour distinguer aeroport vs compagnie)
IATA_AIRPORTS = {
    'ALG','ORN','CZL','AAE','TLM','BJA','TMR','OGX','GHA','BSK','ELU',
    'CDG','ORY','BVA','LYS','MRS','NCE','TLS','BOD','NTE','LIL','SXB',
    'MAD','BCN','AGP','VLC','PMI','FCO','MXP','LIN','VCE','NAP',
    'LHR','LGW','STN','MAN','EDI','FRA','MUC','BER','DUS','HAM',
    'AMS','BRU','ZRH','GVA','IST','SAW','AYT','ESB',
    'DXB','AUH','DOH','RUH','JED','MED','CMN','RAK','TNG','FEZ',
    'TUN','SFA','MIR','CAI','HRG','SSH','TIP','YUL','YYZ',
    'JFK','LAX','ORD','PEK','PVG','HND','SIN','BOM','DEL',
}


def get_recommendations(origin: str, destination: str = '',
                        min_support: float = 0.05,
                        min_confidence: float = 0.3) -> list:
    """
    Regle A priori : {Aeroport_Depart, Aeroport_Arrivee} -> Compagnie_Aerienne

    Exemple : {ALG, CDG} -> Air France (confiance: 70%)

    Args:
        origin:         Code IATA depart (ex: 'ALG')
        destination:    Code IATA arrivee (ex: 'CDG') — optionnel
        min_support:    Seuil minimum de support
        min_confidence: Seuil minimum de confiance
    """
    from apps.reservations.models import Reservation

    # 1. Recuperer les reservations confirmees
    reservations = list(
        Reservation.objects.filter(status="confirmed")
        .values("user_id", "raw_duffel_order")
    )

    logger.info("Apriori: %d reservations confirmees", len(reservations))

    if len(reservations) < 5:
        return []

    # 2. Construire les transactions : {depart, arrivee, compagnie}
    transactions = []
    for r in reservations:
        data   = r["raw_duffel_order"] or {}
        slices = data.get("slices", [])
        if not slices:
            continue

        first_seg = (slices[0].get("segments") or [{}])[0]
        last_seg  = (slices[0].get("segments") or [{}])[-1]

        orig    = (first_seg.get("origin")      or {}).get("iata_code", "")
        dest    = (last_seg.get("destination")  or {}).get("iata_code", "")
        carrier = (first_seg.get("marketing_carrier") or {}).get("name", "")
        if not carrier:
            carrier = (first_seg.get("operating_carrier") or {}).get("name", "")

        if orig and dest and carrier and orig != dest:
            transactions.append([orig, dest, carrier])

    logger.info("Apriori: %d transactions valides", len(transactions))

    if len(transactions) < 3:
        return []

    # 3. Encoder et appliquer A priori
    te       = TransactionEncoder()
    te_array = te.fit_transform(transactions)
    df       = pd.DataFrame(te_array, columns=te.columns_)

    try:
        frequent_itemsets = apriori(df, min_support=min_support, use_colnames=True)
        if frequent_itemsets.empty:
            logger.info("Apriori: aucun itemset frequent")
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

    # 4. Filtrer : antecedent contient origine (+ destination si fournie)
    #              consequent est une compagnie (pas un aeroport)
    results = []
    seen    = set()

    for _, rule in rules.iterrows():
        ants = list(rule["antecedents"])
        cons = list(rule["consequents"])

        # L'antecedent doit contenir l'origine
        if origin.upper() not in [a.upper() for a in ants]:
            continue

        # Si destination fournie, elle doit aussi etre dans l'antecedent
        if destination and destination.upper() not in [a.upper() for a in ants]:
            continue

        for c in cons:
            # Le consequent doit etre une compagnie, pas un aeroport
            if c.upper() in IATA_AIRPORTS or c in seen:
                continue
            seen.add(c)
            results.append({
                "compagnie":  c,
                "support":    round(float(rule["support"]),    3),
                "confidence": round(float(rule["confidence"]), 3),
                "lift":       round(float(rule["lift"]),        3),
            })

    results.sort(key=lambda x: x["confidence"], reverse=True)
    logger.info("Apriori: %d compagnies pour {%s, %s}", len(results), origin, destination)
    return results[:3]
