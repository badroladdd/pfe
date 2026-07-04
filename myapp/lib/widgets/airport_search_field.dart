import 'dart:async';
import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/data/airports.dart';

/// Returns a map with keys: iata, city, country, name
/// or null if the user dismissed.
Future<Map<String, String>?> showAirportSearch(
    BuildContext context, {String? current}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AirportSearchSheet(current: current),
  );
}

class _AirportSearchSheet extends StatefulWidget {
  final String? current;
  const _AirportSearchSheet({this.current});
  @override
  State<_AirportSearchSheet> createState() => _AirportSearchSheetState();
}

class _AirportSearchSheetState extends State<_AirportSearchSheet> {
  final _ctrl = TextEditingController();
  final _api  = ApiClient();
  Timer? _debounce;

  String _query       = '';
  bool   _apiLoading  = false;
  List<Map<String, String>>? _apiResults; // null = pas encore chargés

  // Toujours afficher immédiatement : filtre statique OU résultats API
  List<Map<String, String>> get _displayed {
    final q = _query.trim().toLowerCase();
    if (q.length < 2) {
      return kAirports
          .map((a) => {'iata': a.iata, 'name': a.name,
                        'city': a.city, 'country': a.country})
          .toList();
    }

    // Résultats statiques — la capitale de chaque pays est en premier dans kAirports
    final staticResults = kAirports
        .where((a) => a.matches(q))
        .map((a) => {'iata': a.iata, 'name': a.name,
                      'city': a.city, 'country': a.country})
        .toList();

    // Si l'API a répondu avec des résultats, les utiliser
    // Si l'API a répondu vide (ex. mot français "espagne"), fallback statique
    if (_apiResults != null && _apiResults!.isNotEmpty) return _apiResults!;

    // Sinon : statique (pendant chargement API ou si API vide)
    return staticResults;
  }

  @override
  void initState() {
    super.initState();
    if (widget.current != null) {
      _ctrl.text = widget.current!;
      _query     = widget.current!;
      _fetchDuffel(widget.current!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    setState(() {
      _query      = q;
      _apiResults = null;         // reset API results → filtre statique affiché
      _apiLoading = q.trim().length >= 2;
    });
    if (q.trim().length < 2) return;
    // Déclencher Duffel après 600ms (debounce)
    _debounce = Timer(const Duration(milliseconds: 600), () => _fetchDuffel(q));
  }

  Future<void> _fetchDuffel(String q) async {
    if (!mounted) return;
    setState(() => _apiLoading = true);
    try {
      final data = await _api
          .searchAirports(q)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final results = data
          .map((a) => {
                'iata':    (a['iata']    ?? '').toString(),
                'name':    (a['name']    ?? '').toString(),
                'city':    (a['city']    ?? '').toString(),
                'country': (a['country'] ?? '').toString(),
              })
          .where((a) => a['iata']!.isNotEmpty)
          .toList();
      if (mounted) setState(() { _apiResults = results; _apiLoading = false; });
    } catch (e) {
      debugPrint('[Airport] Duffel error: $e');
      if (mounted) setState(() => _apiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list   = _displayed;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Paris, CDG, Alger...',
                prefixIcon: _apiLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search, color: Colors.blue),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _ctrl.clear();
                          _onChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _apiLoading && _apiResults == null
                    ? 'Recherche Duffel en cours...'
                    : '${list.length} aéroport(s) trouvé(s)'
                        '${_apiResults != null ? ' (Duffel)' : ''}',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ),
          const Divider(height: 12),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Aucun aéroport trouvé',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 70),
                    itemBuilder: (_, i) {
                      final a = list[i];
                      return ListTile(
                        leading: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(a['iata']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blue,
                                  letterSpacing: 1,
                                )),
                          ),
                        ),
                        title: Text('${a['city']}, ${a['country']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(a['name']!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        onTap: () =>
                            Navigator.pop(context, a),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
