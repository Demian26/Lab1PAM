import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math; // pentru min/max simple

void main() => runApp(const VitezaMedieApp());

class VitezaMedieApp extends StatefulWidget {
  const VitezaMedieApp({super.key});
  @override
  State<VitezaMedieApp> createState() => _VitezaMedieAppState();
}

class _VitezaMedieAppState extends State<VitezaMedieApp> {
  bool dark = false;

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return MaterialApp(
      title: 'Calculator Viteză Medie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: baseScheme,
        useMaterial3: true,
      ),
      home: PaginaCalculator(
        onToggleTheme: () => setState(() => dark = !dark),
        isDark: dark,
      ),
    );
  }
}

enum Unit { kmh, ms }

class PaginaCalculator extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  const PaginaCalculator({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<PaginaCalculator> createState() => _PaginaCalculatorState();
}

class _PaginaCalculatorState extends State<PaginaCalculator> {
  final _formKey = GlobalKey<FormState>();
  final distCtrl = TextEditingController();
  final timpCtrl = TextEditingController();
  final _distFocus = FocusNode();
  final _timpFocus = FocusNode();

  // limite opționale (doar pentru UX; nu sunt obligatorii)
  static const double _maxDistKm = 1e6; // 1.000.000 km
  static const double _maxTimpH = 1e5; // 100.000 ore

  String mesaj = 'Introdu distanța (km) și timpul (ore).';
  double? vitezaKmH;
  Unit unitPrimary = Unit.kmh;

  final List<_Entry> _history = [];

  @override
  void dispose() {
    distCtrl.dispose();
    timpCtrl.dispose();
    _distFocus.dispose();
    _timpFocus.dispose();
    super.dispose();
  }

  // Acceptă și virgulă; normalizează la punct pentru parse
  double? _toDouble(String s) {
    final v = s.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  String _fmt2(double n) => n.toStringAsFixed(2);
  String _fmt3(double n) => n.toStringAsFixed(3);

  String _formatTimestamp(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(l.day)}.${two(l.month)}.${l.year}  ${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  void _calc() {
    if (!_formKey.currentState!.validate()) {
      _showSnack('Verifică valorile introduse.');
      return;
    }
    final d = _toDouble(distCtrl.text)!;
    final t = _toDouble(timpCtrl.text)!;

    final v = d / t; // km/h
    setState(() {
      vitezaKmH = v;
      mesaj = 'Viteza medie: ${_fmt2(v)} km/h';
      _history.insert(
        0,
        _Entry(
          distanceKm: d,
          timeH: t,
          speedKmh: v,
          timestamp: DateTime.now(),
        ),
      );
      if (_history.length > 8) _history.removeLast();
    });
    FocusScope.of(context).unfocus();
  }

  void _reset() {
    distCtrl.clear();
    timpCtrl.clear();
    setState(() {
      vitezaKmH = null;
      mesaj = 'Introdu distanța (km) și timpul (ore).';
    });
  }

  void _pickFromHistory(_Entry e) {
    distCtrl.text = _fmt3(e.distanceKm).replaceAll('.', ','); // afișare user-friendly
    timpCtrl.text = _fmt3(e.timeH).replaceAll('.', ',');
    setState(() {
      vitezaKmH = e.speedKmh;
      mesaj = 'Viteza medie: ${_fmt2(e.speedKmh)} km/h (din istoric)';
    });
  }

  void _clearHistory() {
    setState(() => _history.clear());
    _showSnack('Istoric șters');
  }

  Future<void> _copyResult() async {
    if (vitezaKmH == null) {
      _showSnack('Nu există rezultat de copiat.');
      return;
    }
    final kmh = _fmt2(vitezaKmH!);
    final ms = _fmt2(vitezaKmH! * 1000 / 3600);
    await Clipboard.setData(
      ClipboardData(text: 'Viteză medie: $kmh km/h (~ $ms m/s)'),
    );
    _showSnack('Rezultat copiat');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Formatter care permite doar cifre + un singur separator (.,)
    final inputFormatters = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
      _SingleDecimalSeparatorFormatter(),
    ];

    double? primaryValue;
    String primaryUnitLabel = unitPrimary == Unit.kmh ? 'km/h' : 'm/s';
    if (vitezaKmH != null) {
      primaryValue =
      unitPrimary == Unit.kmh ? vitezaKmH : (vitezaKmH! * 1000 / 3600);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calculator Viteză Medie'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: widget.isDark ? 'Luminos' : 'Întunecat',
              onPressed: widget.onToggleTheme,
              icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            ),
            IconButton(
              tooltip: 'Copiază rezultat',
              onPressed: _copyResult,
              icon: const Icon(Icons.copy_all_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'Mai multe',
              onSelected: (v) {
                if (v == 'clear_history') _clearHistory();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                    value: 'clear_history', child: Text('Șterge istoricul')),
              ],
            ),
            IconButton(
              tooltip: 'Reset',
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final content = _buildContent(
              cs,
              inputFormatters,
              primaryValue,
              primaryUnitLabel,
              isWide,
            );
            return Padding(padding: const EdgeInsets.all(16), child: content);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
      ColorScheme cs,
      List<TextInputFormatter> inputFormatters,
      double? primaryValue,
      String primaryUnitLabel,
      bool isWide,
      ) {
    final distField = TextFormField(
      controller: distCtrl,
      focusNode: _distFocus,
      validator: (s) => _validateNumber(s, 'Distanța', _maxDistKm),
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _timpFocus.requestFocus(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: inputFormatters,
      decoration: const InputDecoration(
        labelText: 'Distanța (km)',
        hintText: 'ex: 42.2',
        prefixIcon: Icon(Icons.place_outlined),
        border: OutlineInputBorder(),
      ),
    );

    final timeField = TextFormField(
      controller: timpCtrl,
      focusNode: _timpFocus,
      validator: (s) => _validateNumber(s, 'Timpul', _maxTimpH),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _calc(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: inputFormatters,
      decoration: const InputDecoration(
        labelText: 'Timpul (ore)',
        hintText: 'ex: 3.5',
        prefixIcon: Icon(Icons.access_time),
        border: OutlineInputBorder(),
      ),
    );

    final fieldsRow = isWide
        ? Row(
      children: [
        Expanded(child: distField),
        const SizedBox(width: 12),
        Expanded(child: timeField),
      ],
    )
        : Column(
      children: [
        distField, // fără Flexible/Expanded aici
        const SizedBox(height: 12),
        timeField, // fără Flexible/Expanded aici
      ],
    );

    return Form(
      key: _formKey,
      child: Column(
        children: [
          fieldsRow,
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.straighten),
              const SizedBox(width: 8),
              const Text('Unitate rezultat:'),
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                runSpacing: 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Radio<Unit>(
                        value: Unit.kmh,
                        groupValue: unitPrimary,
                        onChanged: (v) =>
                            setState(() => unitPrimary = v!)),
                    const Text('km/h'),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Radio<Unit>(
                        value: Unit.ms,
                        groupValue: unitPrimary,
                        onChanged: (v) =>
                            setState(() => unitPrimary = v!)),
                    const Text('m/s'),
                  ]),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _calc,
              icon: const Icon(Icons.speed),
              label: const Text('Calculează'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: cs.surfaceVariant.withOpacity(0.6),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mesaj,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: vitezaKmH == null
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                  if (vitezaKmH != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Rezultat ($primaryUnitLabel): ${_fmt2(primaryValue!)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unitPrimary == Unit.kmh
                          ? '≈ ${_fmt2(vitezaKmH! * 1000 / 3600)} m/s'
                          : '≈ ${_fmt2(vitezaKmH!)} km/h',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _history.isEmpty
                ? const Center(
              child: Text('Istoricul este gol.',
                  style: TextStyle(fontStyle: FontStyle.italic)),
            )
                : ListView.separated(
              itemCount: _history.length,
              separatorBuilder: (_, __) => const Divider(height: 8),
              itemBuilder: (context, i) {
                final e = _history[i];
                final kmh = _fmt2(e.speedKmh);
                final ms = _fmt2(e.speedKmh * 1000 / 3600);
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('V: $kmh km/h (~ $ms m/s)'),
                  subtitle: Text(
                    'D: ${_fmt3(e.distanceKm)} km   T: ${_fmt3(e.timeH)} h\n${_formatTimestamp(e.timestamp)}',
                  ),
                  isThreeLine: true,
                  onTap: () => _pickFromHistory(e),
                  trailing: IconButton(
                    tooltip: 'Copiază',
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                          'D=${_fmt3(e.distanceKm)} km, T=${_fmt3(e.timeH)} h, V=$kmh km/h (~ $ms m/s) la ${_formatTimestamp(e.timestamp)}',
                        ),
                      );
                      _showSnack('Intrare copiată');
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String? _validateNumber(String? raw, String label, double maxAllowed) {
    if (raw == null || raw.trim().isEmpty) {
      return '$label este obligatoriu.';
    }
    final v = _toDouble(raw);
    if (v == null) return '$label trebuie să fie număr (ex: 12.5 sau 12,5).';
    if (v <= 0) return '$label trebuie să fie > 0.';
    if (!v.isFinite) return '$label este invalid.';
    if (v > maxAllowed) {
      return '$label este prea mare (max: ${_fmt2(maxAllowed)}).';
    }
    return null;
  }
}

/// Formatter custom: permite doar un singur separator zecimal ('.' sau ',')
class _SingleDecimalSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldV, TextEditingValue newV) {
    final text = newV.text;

    // Nu permite mai mult de un separator total (.,)
    final dots = '.'.allMatches(text).length;
    final commas = ','.allMatches(text).length;
    if (dots + commas > 1) return oldV;

    // Nu permite separator ca prim caracter
    if (text.startsWith('.') || text.startsWith(',')) return oldV;

    // Nu permite ".,", ",." unul după altul
    if (text.contains('.,') || text.contains(',.')) return oldV;

    // Nu permite caractere multiple non-digit la final de tip ".." sau ",,"
    if (text.contains('..') || text.contains(',,')) return oldV;

    return newV;
  }
}

class _Entry {
  final double distanceKm;
  final double timeH;
  final double speedKmh;
  final DateTime timestamp;
  _Entry({
    required this.distanceKm,
    required this.timeH,
    required this.speedKmh,
    required this.timestamp,
  });
}
