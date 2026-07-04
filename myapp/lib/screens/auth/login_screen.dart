import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/navigation/admin_navigation.dart';
import 'package:myapp/navigation/agent_navigation.dart';
import 'package:myapp/navigation/main_navigation.dart';
import 'package:myapp/screens/auth/forgot_password_screen.dart';
import 'package:myapp/screens/auth/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _api          = ApiClient();
  bool _loading       = false;
  bool _obscure       = true;

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _snack('Veuillez remplir tous les champs.', Colors.red);
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.login(email: email, password: password);
      final profile = await _api.getProfile();
      if (!mounted) return;
      final role = profile['role'] as String? ?? 'client';
      if (!mounted) return;
      Widget destination;
      if (role == 'admin') {
        destination = const AdminNavigation();
      } else if (role == 'agent') {
        destination = const AgentNavigation();
      } else {
        destination = const MainNavigation();
      }
      Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      if (e is NetworkException) {
        _snack('Impossible de joindre le serveur. Vérifiez votre connexion.', Colors.orange);
      } else if (e is UnauthorizedException || e.toString().contains('401')) {
        _snack('Identifiants incorrects.', Colors.red);
      } else {
        _snack('Erreur : $e', Colors.red);
      }
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.airplanemode_active, color: Colors.blue, size: 48),
              const SizedBox(height: 24),
              const Text('Connexion',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Bienvenue ! Connectez-vous pour continuer.',
                style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 36),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDeco('Email', Icons.email_outlined),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: _inputDeco('Mot de passe', Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  ),
                  child: const Text('Mot de passe oublié ?',
                      style: TextStyle(color: Colors.blue)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Se connecter',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text("Pas de compte ? S'inscrire"),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainNavigation()),
                    (_) => false,
                  ),
                  child: Text("Continuer en tant qu'invité",
                    style: TextStyle(color: Colors.grey.shade600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: Colors.blue),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    filled: true,
    fillColor: Colors.white,
  );
}
