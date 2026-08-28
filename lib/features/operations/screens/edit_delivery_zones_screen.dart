import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/constants/egypt_locations.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';

class EditDeliveryZonesScreen extends StatefulWidget {
  const EditDeliveryZonesScreen({super.key});

  @override
  State<EditDeliveryZonesScreen> createState() => _EditDeliveryZonesScreenState();
}

class _EditDeliveryZonesScreenState extends State<EditDeliveryZonesScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  bool _enableShipping = true;
  double _defaultRate = 50;
  List<Map<String, dynamic>> _zones = [];
  final Map<int, _CityAddingState> _cityAddingState = {};

  List<String> get _governorates => egyptLocations.map((g) => g.en).toList();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = _client();
      final settingsData = await client.get('/api/admin/auth/settings');
      final configs = settingsData['configs'] as List?;
      final shippingConfig = configs?.cast<dynamic>().firstWhere(
            (c) => c['key'] == 'shipping_settings',
            orElse: () => null,
          );

      final value = shippingConfig?['value'];
      _applySettings(value is Map ? Map<String, dynamic>.from(value) : _defaultSettings());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  ApiClient _client() {
    final token = context.read<AuthProvider>().token;
    return ApiClient(token: token);
  }

  Map<String, dynamic> _defaultSettings() {
    return {
      'enableShipping': true,
      'defaultShippingRate': 50,
      'shippingZones': [
        {
          'name': 'Cairo & Giza',
          'governorates': ['Cairo', 'Giza'],
          'cities': [],
          'rate': 40,
        },
        {
          'name': 'Alexandria',
          'governorates': ['Alexandria'],
          'cities': [],
          'rate': 50,
        },
        {
          'name': 'Other Governorates',
          'governorates': [],
          'cities': [],
          'rate': 70,
        },
      ],
    };
  }

  void _applySettings(Map<String, dynamic> value) {
    _enableShipping = value['enableShipping'] ?? true;
    _defaultRate = _number(value['defaultShippingRate'], fallback: 50);
    _zones = _normalizeZones(value['shippingZones']);
    _cityAddingState.clear();
  }

  List<Map<String, dynamic>> _normalizeZones(dynamic rawZones) {
    final source = rawZones is List ? rawZones : _defaultSettings()['shippingZones'] as List;

    return source.map<Map<String, dynamic>>((raw) {
      final zone = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      return {
        'name': (zone['name'] ?? 'New Zone').toString(),
        'governorates': _stringList(zone['governorates']),
        'cities': _normalizeCities(zone['cities'], zoneRate: _number(zone['rate'], fallback: 50)),
        'rate': _number(zone['rate'], fallback: 50),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _normalizeCities(dynamic rawCities, {required double zoneRate}) {
    if (rawCities is! List) return [];

    return rawCities.map<Map<String, dynamic>>((raw) {
      if (raw is Map) {
        final city = Map<String, dynamic>.from(raw);
        return {
          'governorate': (city['governorate'] ?? '').toString(),
          'city': (city['city'] ?? '').toString(),
          'rate': _number(city['rate'], fallback: zoneRate),
        };
      }

      return {
        'governorate': '',
        'city': raw.toString(),
        'rate': zoneRate,
      };
    }).where((city) => (city['city'] as String).isNotEmpty).toList();
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }

  double _number(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _client().put('/api/admin/auth/settings', body: {
        'key': 'shipping_settings',
        'value': _settingsPayload(),
        'description': 'Shipping rates and delivery zones',
      });

      if (!mounted) return;
      messenger.showAppToast(
        AppToast.snackBar(
          content: Text('Shipping settings saved'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showAppToast(
        AppToast.snackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic> _settingsPayload() {
    return {
      'enableShipping': _enableShipping,
      'defaultShippingRate': _defaultRate,
      'shippingZones': _zones.map((zone) {
        return {
          'name': zone['name'],
          'governorates': List<String>.from(zone['governorates'] as List),
          'cities': (zone['cities'] as List).map((city) {
            final cityMap = Map<String, dynamic>.from(city as Map);
            return {
              'governorate': cityMap['governorate'],
              'city': cityMap['city'],
              'rate': _number(cityMap['rate'], fallback: _number(zone['rate'], fallback: 50)),
            };
          }).toList(),
          'rate': _number(zone['rate'], fallback: 50),
        };
      }).toList(),
    };
  }

  void _resetDefaults() {
    setState(() => _applySettings(_defaultSettings()));
    ScaffoldMessenger.of(context).showAppToast(
      AppToast.snackBar(
        content: Text('Defaults loaded. Tap Save Changes to apply.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addZone() {
    setState(() {
      _zones.add({
        'name': 'New Zone',
        'governorates': <String>[],
        'cities': <Map<String, dynamic>>[],
        'rate': 50,
      });
    });
  }

  void _removeZone(int index) {
    if (_zones.length <= 1) return;
    setState(() {
      _zones.removeAt(index);
      _cityAddingState.remove(index);
    });
  }

  List<City> _citiesForGovernorate(String governorate) {
    return egyptLocations
        .firstWhere(
          (location) => location.en == governorate,
          orElse: () => Governorate(en: governorate, ar: '', cities: []),
        )
        .cities;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Edit Delivery Zones',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                // Shipping Status Card Shimmer
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const AppShimmer(width: 40, height: 40, borderRadius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            AppShimmer(width: 120, height: 16),
                            SizedBox(height: 6),
                            AppShimmer(width: 200, height: 12),
                          ],
                        ),
                      ),
                      const AppShimmer(width: 40, height: 24, borderRadius: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Rates Card Shimmer
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          AppShimmer(width: 40, height: 40, borderRadius: 12),
                          SizedBox(width: 12),
                          AppShimmer(width: 100, height: 16),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const AppShimmer(width: double.infinity, height: 48, borderRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Zones Header Shimmer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmer(width: 160, height: 20),
                        SizedBox(height: 6),
                        AppShimmer(width: 120, height: 12),
                      ],
                    ),
                    AppShimmer(width: 90, height: 32, borderRadius: 8),
                  ],
                ),
                const SizedBox(height: 12),
                // Zone Card Shimmer
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          AppShimmer(width: 40, height: 40, borderRadius: 12),
                          SizedBox(width: 12),
                          AppShimmer(width: 80, height: 16),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: const [
                          Expanded(flex: 3, child: AppShimmer(width: double.infinity, height: 48, borderRadius: 10)),
                          SizedBox(width: 12),
                          Expanded(flex: 2, child: AppShimmer(width: double.infinity, height: 48, borderRadius: 10)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const AppShimmer(width: 100, height: 14),
                      const SizedBox(height: 8),
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(6, (i) => AppShimmer(width: 60.0 + (i % 3) * 15.0, height: 24, borderRadius: 12)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const AppShimmer(width: 150, height: 14),
                      const SizedBox(height: 8),
                      // City Exception dropdown placeholders
                      const AppShimmer(width: double.infinity, height: 48, borderRadius: 12),
                      const SizedBox(height: 10),
                      const AppShimmer(width: double.infinity, height: 48, borderRadius: 12),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Expanded(child: AppShimmer(width: double.infinity, height: 48, borderRadius: 12)),
                          SizedBox(width: 10),
                          AppShimmer(width: 80, height: 48, borderRadius: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadSettings,
                  color: AppColors.primaryDark,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    children: [
                      _buildShippingStatusCard(),
                      const SizedBox(height: 16),
                      _buildRatesCard(),
                      const SizedBox(height: 24),
                      _buildZonesHeader(),
                      const SizedBox(height: 12),
                      ..._zones.asMap().entries.map((entry) => _buildZoneCard(entry.key)),
                      const SizedBox(height: 20),
                      _buildActions(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Could not load shipping settings', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadSettings, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildShippingStatusCard() {
    return _sectionCard(
      child: Row(
        children: [
          _iconBox(LucideIcons.truck),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shipping Status', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                const SizedBox(height: 2),
                Text('Calculate shipping costs at checkout', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Switch.adaptive(
            value: _enableShipping,
            activeThumbColor: AppColors.success,
            onChanged: (value) => setState(() => _enableShipping = value),
          ),
        ],
      ),
    );
  }

  Widget _buildRatesCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(LucideIcons.coins),
              const SizedBox(width: 12),
              Text('Default Rates', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _numberField('Default Rate', _defaultRate, (value) => _defaultRate = value)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZonesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shipping Zones', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            Text('${_zones.length} zones from website settings', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        TextButton.icon(
          onPressed: _addZone,
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Add Zone'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF0EA5E9)),
        ),
      ],
    );
  }

  Widget _buildZoneCard(int index) {
    final zone = _zones[index];
    final governorates = List<String>.from(zone['governorates'] as List);
    final cities = List<Map<String, dynamic>>.from(zone['cities'] as List);
    final addingState = _cityAddingState.putIfAbsent(
      index,
      () => _CityAddingState(rate: _number(zone['rate'], fallback: 50)),
    );
    final availableCities = addingState.governorate == null ? <City>[] : _citiesForGovernorate(addingState.governorate!);

    return _sectionCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(LucideIcons.mapPin),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Zone ${index + 1}',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                ),
              ),
              if (_zones.length > 1)
                IconButton(
                  tooltip: 'Remove zone',
                  onPressed: () => _removeZone(index),
                  icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.error),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _textField(
                  label: 'Zone Name',
                  value: zone['name'].toString(),
                  onChanged: (value) => zone['name'] = value,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _numberField(
                  'Rate',
                  _number(zone['rate'], fallback: 50),
                  (value) => zone['rate'] = value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Governorates (${governorates.length} selected)',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _governorates.map((gov) {
                  final selected = governorates.contains(gov);
                  return ChoiceChip(
                    label: Text(gov, style: GoogleFonts.inter(fontSize: 12, color: selected ? Colors.white : AppColors.textPrimary)),
                    selected: selected,
                    selectedColor: AppColors.primaryDark,
                    backgroundColor: AppColors.surface,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: selected ? AppColors.primaryDark : AppColors.cardBorder),
                    ),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          governorates.add(gov);
                        } else {
                          governorates.remove(gov);
                        }
                        zone['governorates'] = governorates;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Specific City Exceptions (${cities.length})',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          _buildCityExceptionInputs(index, zone, addingState, availableCities),
          const SizedBox(height: 12),
          if (cities.isEmpty)
            Text('No specific city exceptions in this zone.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cities.asMap().entries.map((entry) {
                final city = entry.value;
                return Chip(
                  label: Text(
                    '${city['city']} (${city['governorate']}) - ${_formatMoney(_number(city['rate'], fallback: 0))}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  deleteIcon: const Icon(LucideIcons.x, size: 14),
                  onDeleted: () {
                    setState(() => (zone['cities'] as List).removeAt(entry.key));
                  },
                  backgroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.cardBorder)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCityExceptionInputs(int index, Map<String, dynamic> zone, _CityAddingState addingState, List<City> availableCities) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: addingState.governorate,
          isExpanded: true,
          items: _governorates.map((gov) => DropdownMenuItem(value: gov, child: Text(gov))).toList(),
          onChanged: (value) {
            setState(() {
              addingState.governorate = value;
              addingState.city = null;
              addingState.rate = _number(zone['rate'], fallback: 50);
            });
          },
          decoration: _inputDecoration('Select Governorate', LucideIcons.map),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: addingState.city,
          isExpanded: true,
          items: availableCities.map((city) => DropdownMenuItem(value: city.en, child: Text(city.en))).toList(),
          onChanged: addingState.governorate == null ? null : (value) => setState(() => addingState.city = value),
          decoration: _inputDecoration('Select City', LucideIcons.building2),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _numberField(
                'City Rate',
                addingState.rate,
                (value) => addingState.rate = value,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: addingState.city == null ? null : () => _addCityException(index, zone, addingState),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addCityException(int index, Map<String, dynamic> zone, _CityAddingState addingState) {
    final governorate = addingState.governorate;
    final city = addingState.city;
    if (governorate == null || city == null) return;

    final cities = List<Map<String, dynamic>>.from(zone['cities'] as List);
    final exists = cities.any((entry) => entry['governorate'] == governorate && entry['city'] == city);
    if (exists) {
      ScaffoldMessenger.of(context).showAppToast(
        AppToast.snackBar(content: Text('This city is already in this zone'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() {
      cities.add({'governorate': governorate, 'city': city, 'rate': addingState.rate});
      zone['cities'] = cities;
      _cityAddingState[index] = _CityAddingState(governorate: governorate, rate: addingState.rate);
    });
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _resetDefaults,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Reset Default'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Changes'),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required Widget child, EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: const Color(0xFF0EA5E9), size: 20),
    );
  }

  Widget _numberField(String label, double value, ValueChanged<double> onChanged) {
    final text = value % 1 == 0 ? value.toInt().toString() : value.toString();
    return _textField(
      label: label,
      value: text,
      keyboardType: TextInputType.number,
      prefixText: 'EGP ',
      onChanged: (raw) => onChanged(double.tryParse(raw) ?? value),
    );
  }

  Widget _textField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('$label-$value'),
          initialValue: value,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            prefixText: prefixText,
            prefixStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  String _formatMoney(double value) {
    final amount = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
    return 'EGP $amount';
  }
}

class _CityAddingState {
  String? governorate;
  String? city;
  double rate;

  _CityAddingState({this.governorate, required this.rate});
}
