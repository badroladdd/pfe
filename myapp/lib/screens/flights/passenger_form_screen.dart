import 'package:flutter/material.dart';
import 'package:myapp/api.dart';
import 'package:myapp/models/flight.dart';
import 'package:myapp/screens/auth/login_screen.dart';

class PassengerFormScreen extends StatefulWidget {
  final Map<String, dynamic> rawOffer;
  final Flight flight;
  final VoidCallback onBookingCreated;
  final String? forUserId;

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

// Données d'un passager
class _PaxData {
  final String type; // adult / child / infant
  final int? expectedAge; // age attendu par Duffel (pour enfants)
  final TextEditingController firstName  = TextEditingController();
  final TextEditingController lastName   = TextEditingController();
  final TextEditingController dob        = TextEditingController();
  final TextEditingController email      = TextEditingController();
  final TextEditingController phone      = TextEditingController();
  final TextEditingController passNum    = TextEditingController();
  final TextEditingController passExpiry = TextEditingController();
  final TextEditingController passCountry= TextEditingController();
  String gender = 'M';

  _PaxData(this.type, {this.expectedAge});

  void dispose() {
    for (final c in [firstName,lastName,dob,email,phone,passNum,passExpiry,passCountry]) {
      c.dispose();
    }
  }

  Map<String, dynamic> toMap() => PassengerInput(
    firstName:        firstName.text.trim(),
    lastName:         lastName.text.trim(),
    dateOfBirth:      dob.text.trim(),
    gender:           gender,
    nationality:      passCountry.text.trim().isNotEmpty
                        ? passCountry.text.trim().toUpperCase() : 'DZ',
    passengerType:    type,
    email:            email.text.trim(),
    phone:            phone.text.trim(),
    phoneCountryCode: '213',
    passportNumber:   passNum.text.trim(),
    passportExpiry:   passExpiry.text.trim(),
    passportCountry:  passCountry.text.trim().toUpperCase(),
  ).toMap();
}

class _PassengerFormScreenState extends State<PassengerFormScreen> {
  final _api = ApiClient();
  bool _loading = false;

  final _promoCtrl    = TextEditingController();
  bool  _promoLoading = false;
  Map<String, dynamic>? _promoResult;

  late final List<_PaxData> _passengers;

  @override
  void initState() {
    super.initState();
    // Construire la liste depuis l'offre
    final offerPax = (widget.rawOffer['passengers'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    _passengers = offerPax.map((p) {
      String type = p['type']?.toString() ?? 'adult';
      if (type.contains('infant')) type = 'infant';
      if (type.contains('child'))  type = 'child';
      if (!['adult','child','infant'].contains(type)) type = 'adult';
      // Recuperer l'age attendu par Duffel pour les enfants
      final age = p['age'] != null ? int.tryParse(p['age'].toString()) : null;
      return _PaxData(type, expectedAge: age);
    }).toList();
    if (_passengers.isEmpty) _passengers.add(_PaxData('adult'));
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    for (final p in _passengers) { p.dispose(); }
    super.dispose();
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

  Future<void> _submit({bool acceptPriceChange = false, String paymentMethod = 'cash'}) async {
    // Vérifier que tous les passagers ont les champs obligatoires
    for (int i = 0; i < _passengers.length; i++) {
      final p = _passengers[i];
      if (p.firstName.text.isEmpty || p.lastName.text.isEmpty ||
          p.dob.text.isEmpty || p.email.text.isEmpty) {
        _snack('Passager ${i+1} : remplissez tous les champs obligatoires', Colors.red);
        return;
      }
      // Valider que l'age correspond a l'age attendu par Duffel
      if (p.expectedAge != null && p.dob.text.isNotEmpty) {
        try {
          final dob  = DateTime.parse(p.dob.text);
          final now  = DateTime.now();
          final age  = now.year - dob.year -
              ((now.month < dob.month || (now.month == dob.month && now.day < dob.day)) ? 1 : 0);
          if (age != p.expectedAge) {
            _snack(
              'Passager ${i+1} : la date de naissance doit correspondre à ${p.expectedAge} ans',
              Colors.red,
            );
            return;
          }
        } catch (_) {}
      }
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
      final offer = Map<String, dynamic>.from(widget.rawOffer);
      final promoCode = _promoResult != null ? (_promoResult!['code'] as String?) : null;
      if (_promoResult != null) offer['total_amount'] = _promoResult!['discounted_amount'];

      final passengerMaps = _passengers.map((p) => p.toMap()).toList();

      if (widget.forUserId != null) {
        await _api.createReservationForClient(
          flightOffer: offer,
          passengers: passengerMaps,
          forUserId: widget.forUserId,
          paymentMethod: paymentMethod,
          promoCode: promoCode,
        );
      } else {
        await _api.createReservation(
          flightOffer: offer,
          passengers: passengerMaps,
          acceptPriceChange: acceptPriceChange,
          paymentMethod: paymentMethod,
          promoCode: promoCode,
        );
      }

      widget.onBookingCreated();
      if (!mounted) return;
      if (paymentMethod == 'cib') {
        _snack('Réservation confirmée ! Paiement CIB / Edahabia accepté.', Colors.green);
      } else {
        _snack('Demande envoyée ! En attente de confirmation agent.', Colors.orange);
      }
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
        content: Text('Le prix a changé de ${e.oldPrice} à ${e.newPrice} ${e.currency}.\nVoulez-vous continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () { Navigator.pop(context); _submit(acceptPriceChange: true); },
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
      ctrl.text = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'adult':  return 'Adulte';
      case 'child':  return 'Enfant';
      case 'infant': return 'Bébé';
      default:       return 'Passager';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informations passagers'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête vol
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
                            style: const TextStyle(fontSize: 12,
                                decoration: TextDecoration.lineThrough, color: Colors.grey)),
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
            const SizedBox(height: 20),

            // Formulaire par passager
            for (int i = 0; i < _passengers.length; i++) ...[
              _buildPassengerForm(i),
              const SizedBox(height: 16),
            ],

            // Code promo
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
                      filled: true, fillColor: Colors.white,
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
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Code "${_promoResult!['code']}" appliqué !',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      Text('Économie : ${_promoResult!['saved']} € → ${_promoResult!['discounted_amount']} €',
                          style: const TextStyle(fontSize: 13)),
                    ]),
                  ],
                ),
              ),
            ],

            // Boutons paiement
            const SizedBox(height: 28),
            const Text('Mode de paiement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : () => _submit(paymentMethod: 'cash'),
                icon: const Icon(Icons.payments_outlined, color: Colors.white),
                label: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Payer ultérieurement', style: TextStyle(color: Colors.white, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : () => _submit(paymentMethod: 'cib'),
                icon: const Icon(Icons.credit_card, color: Colors.white),
                label: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Payer avec CIB / Edahabia', style: TextStyle(color: Colors.white, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerForm(int index) {
    final p = _passengers[index];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${index + 1}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_typeLabel(p.type),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (p.expectedAge != null) ...[
                    Text(
                      'Âge attendu : ${p.expectedAge} ans',
                      style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Né(e) vers ${DateTime.now().year - p.expectedAge!}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _field(p.firstName, 'Prénom *', Icons.person_outline),
          _field(p.lastName, 'Nom *', Icons.person_outline),
          GestureDetector(
            onTap: () => _pickDate(p.dob),
            child: AbsorbPointer(child: _field(p.dob, 'Date de naissance * (AAAA-MM-JJ)', Icons.cake_outlined)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DropdownButtonFormField<String>(
              initialValue: p.gender,
              decoration: InputDecoration(
                labelText: 'Genre',
                prefixIcon: const Icon(Icons.wc_outlined, color: Colors.blue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 'M', child: Text('Homme')),
                DropdownMenuItem(value: 'F', child: Text('Femme')),
              ],
              onChanged: (v) => setState(() => p.gender = v ?? 'M'),
            ),
          ),
          _field(p.email, 'Email *', Icons.email_outlined, type: TextInputType.emailAddress),
          _field(p.phone, 'Téléphone', Icons.phone_outlined, type: TextInputType.phone),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Passeport', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          _field(p.passNum, 'Numéro de passeport', Icons.credit_card_outlined),
          GestureDetector(
            onTap: () => _pickDate(p.passExpiry, future: true),
            child: AbsorbPointer(child: _field(p.passExpiry, "Date d'expiration (AAAA-MM-JJ)", Icons.date_range_outlined)),
          ),
          _field(p.passCountry, "Pays d'émission (ex: DZ)", Icons.flag_outlined),
        ],
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
          filled: true, fillColor: Colors.white,
        ),
      ),
    );
  }
}
