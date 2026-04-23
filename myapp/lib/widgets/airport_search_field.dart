import 'dart:async';
import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/data/airports.dart';

Future<String?> showAirportSearch(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
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

  List<Map<String, String>> _results = [];
  bool _loading = false;

  List<Map<String, String>> get _staticList => kAirports
      .map((a) => {'iata': a.iata, 'name': a.name, 'city': a.city, 'country': a.country})
      .toList();

  @override
  void initState() {
    super.initState();
    _results = _staticList;
    if (widget.current != null && widget.current!.length == 3) {
      _ctrl.text = widget.current!;
      _search(widget.current!);
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
    if (q.trim().length < 2) {
      setState(() { _results = _staticList; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    try {
      final data = await _api.searchAirports(q);
      if (!mounted) return;
      setState(() {
        _results = data
            .map((a) => {
                  'iata':    (a['iata']    ?? '').toString(),
                  'name':    (a['name']    ?? '').toString(),
                  'city':    (a['city']    ?? '').toString(),
                  'country': (a['country'] ?? '').toString(),
                })
            .where((a) => a['iata']!.isNotEmpty)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = kAirports
            .where((a) => a.matches(q))
            .map((a) => {'iata': a.iata, 'name': a.name, 'city': a.city, 'country': a.country})
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                prefixIcon: _loading
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${_results.length} aéroport(s) trouvé(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Aucun aéroport trouvé',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 70),
                    itemBuilder: (_, i) {
                      final a = _results[i];
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              a['iata']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blue,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        title: Text('${a['city']}, ${a['country']}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(a['name']!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.pop(context, a['iata']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
