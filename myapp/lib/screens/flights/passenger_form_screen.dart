import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/auth/login_screen.dart';

class PassengerFormScreen extends StatefulWidget {
  final Map<String, dynamic> rawOffer;
  final Flight flight;
  final VoidCallback onBookingCreated;
  final String? forUserId; // agent: book on behalf of this user

  const PassengerFormScreen({
    super.key,
    required this.rawOffer,
    required this.flight,
    required this.onBookingCreated,
    this.forUserId,
  });

  @override
  State<PassengerFormScreen> createState() => _PassengerFormScreenState();
}

class _PassengerFormScreenState extends State<PassengerFormScreen> {
  final _api = ApiClient();
  bool _loading = false;

  final _promoCtrl       = TextEditingController();
  bool  _promoLoading    = false;
  Map<String, dynamic>? _promoResult;

  final _firstNameCtrl       = TextEditingController();
  final _lastNameCtrl        = TextEditingController();
  final _dobCtrl             = TextEditingController();
  String _gender             = 'M';
  final _emailCtrl           = TextEditingController();
  final _phoneCtrl           = TextEditingController();
  final _passportNumCtrl     = TextEditingController();
  final _passportExpiryCtrl  = TextEditingController();
  final _passportCountryCtrl = TextEditingController();

  PassengerInput _buildPassenger() => PassengerInput(
    firstName:        _firstNameCtrl.text.trim(),
    lastName:         _lastNameCtrl.text.trim(),
    dateOfBirth:      _dobCtrl.text.trim(),
    gender:           _gender,
    nationality:      _passportCountryCtrl.text.trim().isNotEmpty
                        ? _passportCountryCtrl.text.trim().toUpperCase()
                        : 'DZ',
    passengerType:    'adult',
    email:            _emailCtrl.text.trim(),
    phone:            _phoneCtrl.text.trim(),
    phoneCountryCode: '213',
    passportNumber:   _passportNumCtrl.text.trim(),
    passportExpiry:   _passportExpiryCtrl.text.trim(),
    passportCountry:  _passportCountryCtrl.text.trim().toUpperCase(),
  );

  Future<void> _submit({bool acceptPriceChange = false}) async {
    if (_firstNameCtrl.text.isEmpty || _lastNameCtrl.text.isEmpty ||
        _dobCtrl.text.isEmpty || _emailCtrl.text.isEmpty) {
      _snack('Veuillez remplir tous les champs obligatoires.', Colors.red);
      return;
    }

    final loggedIn = await _api.isLoggedIn;
    if (!loggedIn) {
      if (!mounted) return;
      _snack('Veuillez vous connecter pour réserver.', Colors.orange);
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.forUserId != null) {
        await _api.createReservationForClient(
          flightOffer: widget.rawOffer,
          passengers: [_buildPassenger().toMap()],
          forUserId: widget.forUserId,
        );
      } else {
        await _api.createReservation(
          flightOffer: widget.rawOffer,
          passengers: [_buildPassenger().toMap()],
          acceptPriceChange: acceptPriceChange,
        );
      }

      widget.onBookingCreated();

      if (!mounted) return;
      _snack(
        'Demande envoyée ! Votre réservation est en attente de confirmation par un agent.',
        Colors.orange,
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } on PriceChangedException catch (e) {
      setState(() => _loading = false);
      _showPriceChangeDialog(e);
    } on DuplicateBookingException catch (e) {
      _snack(e.message, Colors.orange);
    } catch (e) {
      _snack('Erreur: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPriceChangeDialog(PriceChangedException e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Prix modifié'),
        content: Text(
            'Le prix de ce vol a changé de ${e.oldPrice} à ${e.newPrice} ${e.currency}.\nVoulez-vous continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _submit(acceptPriceChange: true);
            },
            child: const Text('Confirmer quand même'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(TextEditingController ctrl, {bool future = false}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: future ? now.add(const Duration(days: 365)) : DateTime(1990),
      firstDate: future ? now : DateTime(1900),
      lastDate: future ? now.add(const Duration(days: 365 * 20)) : now,
    );
    if (date != null && mounted) {
      ctrl.text =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _applyPromo() async {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _promoLoading = true);
    try {
      final result = await _api.validatePromoCode(code, widget.flight.price);
      setState(() => _promoResult = result);
    } catch (e) {
      setState(() => _promoResult = null);
      _snack('Code invalide ou expiré', Colors.red);
    } finally {
      setState(() => _promoLoading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informations passager'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${widget.flight.from} → ${widget.flight.to}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_promoResult != null)
                        Text('${widget.flight.price.toStringAsFixed(0)} €',
                            style: const TextStyle(
                                fontSize: 12, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                      Text(
                        _promoResult != null
                            ? '${_promoResult!['discounted_amount']} €'
                            : '${widget.flight.price.toStringAsFixed(0)} €',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Passager 1',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _field(_firstNameCtrl, 'Prénom *', Icons.person_outline),
            _field(_lastNameCtrl, 'Nom *', Icons.person_outline),
            GestureDetector(
              onTap: () => _pickDate(_dobCtrl),
              child: AbsorbPointer(
                child: _field(_dobCtrl, 'Date de naissance * (AAAA-MM-JJ)', Icons.cake_outlined),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: InputDecoration(
                  labelText: 'Genre',
                  prefixIcon: const Icon(Icons.wc_outlined, color: Colors.blue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Homme')),
                  DropdownMenuItem(value: 'F', child: Text('Femme')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? 'M'),
              ),
            ),
            _field(_emailCtrl, 'Email *', Icons.email_outlined,
                type: TextInputType.emailAddress),
            _field(_phoneCtrl, 'Téléphone', Icons.phone_outlined,
                type: TextInputType.phone),
            const Divider(height: 32),
            const Text('Passeport',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _field(_passportNumCtrl, 'Numéro de passeport', Icons.credit_card_outlined),
            GestureDetector(
              onTap: () => _pickDate(_passportExpiryCtrl, future: true),
              child: AbsorbPointer(
                child: _field(_passportExpiryCtrl, "Date d'expiration (AAAA-MM-JJ)",
                    Icons.date_range_outlined),
              ),
            ),
            _field(_passportCountryCtrl, "Pays d'émission (ex: DZ)", Icons.flag_outlined),
            const Divider(height: 32),
            const Text('Code promo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Code promo (optionnel)',
                      prefixIcon: const Icon(Icons.local_offer_outlined, color: Colors.blue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _promoLoading ? null : _applyPromo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                  child: _promoLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Appliquer', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            if (_promoResult != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Code "${_promoResult!['code']}" appliqué !',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        Text('Économie : ${_promoResult!['saved']} € → ${_promoResult!['discounted_amount']} €',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : () => _submit(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Confirmer la réservation',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
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
}
