import 'package:flutter/material.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String? _selectedCat;
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  void _submitTicket() {
    if (_selectedCat != null &&
        _refController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        _emailController.text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket créé avec succès ! Catégorie: $_selectedCat'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _selectedCat = null;
        _refController.clear();
        _phoneController.clear();
        _emailController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Icon(Icons.airplanemode_active, color: Colors.blue),
            Row(children: [
              const Text("fr"),
              const Icon(Icons.arrow_drop_down),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.blue.shade200),
                ),
                child: const Text("Connexion"),
              )
            ])
          ]),
          const SizedBox(height: 30),
          const Text("Créer un ticket",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          _fieldLabel("Catégorie"),
          DropdownButtonFormField<String>(
            decoration: _inputDeco("Sélectionnez une option"),
            initialValue: _selectedCat,
            items: ["Remboursement", "Modification", "Problème technique", "Autre"]
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCat = v),
          ),
          const SizedBox(height: 15),
          _fieldLabel("Numéro de référence"),
          TextField(
            controller: _refController,
            decoration: _inputDeco("Ex : MU7RT3"),
          ),
          const SizedBox(height: 15),
          _fieldLabel("Téléphone"),
          TextField(
            controller: _phoneController,
            decoration: _inputDeco("Votre téléphone"),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 15),
          _fieldLabel("Email"),
          TextField(
            controller: _emailController,
            decoration: _inputDeco("Votre email"),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _submitTicket,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Envoyer",
                style: TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        filled: true,
        fillColor: Colors.white,
      );

  Widget _fieldLabel(String l) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
}
