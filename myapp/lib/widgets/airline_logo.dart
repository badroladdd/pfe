import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

const String _kApiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://amadeus-project.onrender.com/api/v1',
);

/// Displays an airline logo fetched from Duffel's CDN.
/// Falls back to a coloured initial if the logo is unavailable.
class AirlineLogo extends StatefulWidget {
  final String code;
  final double size;
  final bool circle;

  const AirlineLogo({
    super.key,
    required this.code,
    this.size = 40,
    this.circle = false,
  });

  @override
  State<AirlineLogo> createState() => _AirlineLogoState();
}

class _AirlineLogoState extends State<AirlineLogo> {
  // Shared across all instances: code → bytes (null = known failure)
  static final Map<String, Uint8List?> _cache = {};

  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load(widget.code);
  }

  @override
  void didUpdateWidget(AirlineLogo old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) {
      setState(() => _bytes = null);
      _load(widget.code);
    }
  }

  Future<void> _load(String rawCode) async {
    final code = rawCode.toUpperCase().trim();
    if (code.isEmpty) return;

    if (_cache.containsKey(code)) {
      final cached = _cache[code];
      if (cached != null && mounted) setState(() => _bytes = cached);
      return;
    }

    try {
      final url = '$_kApiBase/airlines/logo/$code/';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        _cache[code] = resp.bodyBytes;
        if (mounted) setState(() => _bytes = resp.bodyBytes);
      } else {
        _cache[code] = null; // mark as unavailable so we don't retry
      }
    } catch (_) {
      _cache[code] = null;
    }
  }

  Color _fallbackColor() {
    const palette = [
      Color(0xFFE53935), Color(0xFFF4A900), Color(0xFF1565C0),
      Color(0xFF6A1B9A), Color(0xFF00695C), Color(0xFF283593),
    ];
    return palette[widget.code.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.size;

    if (_bytes != null) {
      Widget svg = SvgPicture.memory(
        _bytes!,
        width: sz,
        height: sz,
        fit: BoxFit.contain,
      );
      if (widget.circle) {
        return ClipOval(
          child: Container(
            width: sz, height: sz,
            color: Colors.white,
            padding: const EdgeInsets.all(4),
            child: svg,
          ),
        );
      }
      return Container(
        width: sz, height: sz,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(4),
        child: svg,
      );
    }

    // Fallback: coloured shape with carrier initial
    final label = widget.code.isNotEmpty ? widget.code[0].toUpperCase() : '✈';
    return Container(
      width: sz, height: sz,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _fallbackColor(),
        shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: widget.circle ? null : BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: sz * 0.38,
        ),
      ),
    );
  }
}
