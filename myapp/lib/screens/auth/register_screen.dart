import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/screens/auth/verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl     = TextEditingController();
  final _firstCtrl     = TextEditingController();
  final _lastCtrl      = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _password2Ctrl = TextEditingController();
  final _api           = ApiClient();
  bool _loading        = false;
  bool _obscure        = true;
  bool _obscure2       = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _password2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email     = _emailCtrl.text.trim();
    final firstName = _firstCtrl.text.trim();
    final lastName  = _lastCtrl.text.trim();
    final password  = _passwordCtrl.text;
    final password2 = _password2Ctrl.text;

    if (email.isEmpty || firstName.isEmpty || lastName.isEmpty || password.isEmpty) {
      _snack('Veuillez remplir tous les champs obligatoires.', Colors.red);
      return;
    }
    if (password != password2) {
      _snack('Les mots de passe ne correspondent pas.', Colors.red);
      return;
    }
    if (password.length < 8) {
      _snack('Le mot de passe doit contenir au moins 8 caractères.', Colors.red);
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.registerWithEmailVerification(
        email:     email,
        password:  password,
        firstName: firstName,
        lastName:  lastName,
        phone:     _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      // Navigate to verification screen — pass the email for display
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: email),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Erreur: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Créer un compte'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _field(_firstCtrl,    'Prénom *',                    Icons.person_outline),
              _field(_lastCtrl,     'Nom *',                       Icons.person_outline),
              _field(_emailCtrl,    'Email *',                     Icons.email_outlined,
                     type: TextInputType.emailAddress),
              _field(_phoneCtrl,    'Téléphone',                   Icons.phone_outlined,
                     type: TextInputType.phone),
              _passwordField(_passwordCtrl,  'Mot de passe *',          _obscure,
                     () => setState(() => _obscure = !_obscure)),
              _passwordField(_password2Ctrl, 'Confirmer le mot de passe *', _obscure2,
                     () => setState(() => _obscure2 = !_obscure2)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _register,
                  icon: _loading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.person_add_outlined, color: Colors.white),
                  label: const Text("S'inscrire",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Déjà un compte ?',
                      style: TextStyle(color: Colors.grey.shade600)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Se connecter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _passwordField(TextEditingController ctrl, String label,
      bool obscure, VoidCallback toggle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.blue),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey),
            onPressed: toggle,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
