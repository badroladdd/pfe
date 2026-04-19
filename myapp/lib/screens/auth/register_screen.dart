import 'package:flutter/material.dart';
import 'package:myapp/api.dart';

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

  Future<void> _register() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty ||
        _firstCtrl.text.isEmpty || _lastCtrl.text.isEmpty) {
      _snack('Veuillez remplir tous les champs obligatoires.', Colors.red);
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.register(
        email:     _emailCtrl.text.trim(),
        password:  _passwordCtrl.text,
        password2: _password2Ctrl.text,
        firstName: _firstCtrl.text.trim(),
        lastName:  _lastCtrl.text.trim(),
        phone:     _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      _snack('Compte créé ! Connectez-vous.', Colors.green);
      Navigator.pop(context);
    } catch (e) {
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
        title: const Text("Créer un compte"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _field(_firstCtrl,    'Prénom',            Icons.person_outline),
              _field(_lastCtrl,     'Nom',               Icons.person_outline),
              _field(_emailCtrl,    'Email',             Icons.email_outlined,
                     type: TextInputType.emailAddress),
              _field(_phoneCtrl,   'Téléphone',          Icons.phone_outlined,
                     type: TextInputType.phone),
              _field(_passwordCtrl, 'Mot de passe',      Icons.lock_outline,  obscure: true),
              _field(_password2Ctrl,'Confirmer le mot de passe', Icons.lock_outline, obscure: true),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("S'inscrire",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: obscure,
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
}
