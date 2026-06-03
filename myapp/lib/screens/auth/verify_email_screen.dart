import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/api.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  // Single controller — all 6 digits live here
  final _ctrl      = TextEditingController();
  final _focusNode = FocusNode();
  final _api       = ApiClient();

  bool  _loading   = false;
  bool  _resending = false;
  int   _cooldown  = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    // Auto-focus on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Verify ────────────────────────────────────────────────────────────────

  Future<void> _verify() async {
    final code = _ctrl.text.trim();
    if (code.length < 6) {
      _snack('Veuillez saisir le code complet à 6 chiffres.', Colors.red);
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.verifyEmail(code);
      if (!mounted) return;
      _snack('Email vérifié ! Vous pouvez maintenant vous connecter.', Colors.green);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      _snack('Code invalide ou expiré.', Colors.red);
      _ctrl.clear();
      _focusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Resend ────────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    if (_resending || _cooldown > 0) return;
    setState(() => _resending = true);
    try {
      await _api.resendVerificationCode(widget.email);
      if (!mounted) return;
      _snack('Un nouveau code a été envoyé.', Colors.green);
      _ctrl.clear();
      _focusNode.requestFocus();
      _startCooldown(60);
    } catch (_) {
      if (!mounted) return;
      _snack('Erreur lors de l\'envoi. Réessayez.', Colors.red);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Vérification email'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),

                // Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mark_email_unread_outlined,
                      size: 56, color: Colors.blue.shade600),
                ),
                const SizedBox(height: 28),

                const Text('Entrez votre code',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                Text(
                  'Un code à 6 chiffres a été envoyé à\n${widget.email}',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // 6 boxes + hidden field
                _buildCodeInput(),

                const SizedBox(height: 36),

                // Verify button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('Vérifier',
                            style: TextStyle(
                                color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),

                // Resend row
                _buildResendRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeInput() {
    final code = _ctrl.text;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Visual boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            final filled = i < code.length;
            final isCurrent = i == code.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent && _focusNode.hasFocus
                      ? Colors.blue
                      : filled
                          ? Colors.blue.shade200
                          : Colors.grey.shade300,
                  width: isCurrent && _focusNode.hasFocus ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                filled ? code[i] : '',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
            );
          }),
        ),

        // Hidden text field (transparent — captures keyboard & paste)
        Opacity(
          opacity: 0,
          child: SizedBox(
            width: 320,
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: ''),
              onChanged: (v) {
                if (v.length == 6) _verify();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Code non reçu ? ',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        if (_resending)
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2))
        else if (_cooldown > 0)
          Text(
            'Renvoyer dans ${_cooldown}s',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          )
        else
          GestureDetector(
            onTap: _resend,
            child: const Text(
              'Renvoyer le code',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }
}
