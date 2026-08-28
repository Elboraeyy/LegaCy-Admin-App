import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/constants/egypt_locations.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'edit_delivery_zones_screen.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';

class DeliveryZonesScreen extends StatefulWidget {
  const DeliveryZonesScreen({super.key});

  @override
  State<DeliveryZonesScreen> createState() => _DeliveryZonesScreenState();
}

class _DeliveryZonesScreenState extends State<DeliveryZonesScreen> {
  bool _isLoading = true;
  String? _error;

  bool _enableShipping = true;
  bool _freeShippingEnabled = false;
  double _freeThreshold = 0;
  double _defaultRate = 50;
  List<Map<String, dynamic>> _zones = [];

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

      // Fetch free shipping settings from the correct endpoint (StoreSetting table)
      final freeShippingData = await client.get('/api/admin/config/settings?keys=FREE_SHIPPING_ENABLED,FREE_SHIPPING_THRESHOLD');

      if (mounted) {
        setState(() {
          _freeShippingEnabled = freeShippingData['FREE_SHIPPING_ENABLED']?.toString() == 'true';
          _freeThreshold = double.tryParse(freeShippingData['FREE_SHIPPING_THRESHOLD']?.toString() ?? '0') ?? 0;
        });
      }

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
      'shippingZones': [],
    };
  }

  void _applySettings(Map<String, dynamic> value) {
    _enableShipping = value['enableShipping'] ?? true;
    _defaultRate = _number(value['defaultShippingRate'], fallback: 50);
    _zones = _normalizeZones(value['shippingZones']);
  }

  List<Map<String, dynamic>> _normalizeZones(dynamic rawZones) {
    if (rawZones is! List) return [];

    return rawZones.map<Map<String, dynamic>>((raw) {
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
      return {'governorate': '', 'city': raw.toString(), 'rate': zoneRate};
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

  double getGovernorateRate(String governorate) {
    for (var zone in _zones) {
      if ((zone['governorates'] as List).contains(governorate)) {
        return _number(zone['rate'], fallback: _defaultRate);
      }
    }
    return _defaultRate;
  }

  double getCityRate(String governorate, String city) {
    for (var zone in _zones) {
      for (var exception in (zone['cities'] as List)) {
        if (exception['governorate'] == governorate && exception['city'] == city) {
          return _number(exception['rate'], fallback: _number(zone['rate'], fallback: _defaultRate));
        }
      }
    }
    return getGovernorateRate(governorate);
  }

  String _formatMoney(double value) {
    final amount = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
    return 'EGP $amount';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Shipping Prices',
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
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditDeliveryZonesScreen()),
              );
              // Reload settings when returning from edit screen
              _loadSettings();
            },
            icon: const Icon(LucideIcons.edit, size: 18),
            label: const Text('Edit'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF0EA5E9)),
          ),
        ],
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: 4,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const AppShimmer(width: 40, height: 40, borderRadius: 10),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            AppShimmer(width: 120, height: 14),
                            SizedBox(height: 6),
                            AppShimmer(width: 160, height: 12),
                          ],
                        ),
                      ),
                      const AppShimmer(width: 60, height: 16),
                    ],
                  ),
                ),
              ),
            )
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadSettings,
                  color: AppColors.primaryDark,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildOverviewCard(),
                            const SizedBox(height: 16),
                            _buildSearchField(),
                            const SizedBox(height: 16),
                            _buildSearchResults(),
                          ],
                        ),
                      ),
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

  Widget _buildOverviewCard() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.truck, color: Color(0xFF0EA5E9), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Global Shipping Settings', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                    const SizedBox(height: 2),
                    Text(_enableShipping ? 'Active' : 'Disabled', style: GoogleFonts.inter(fontSize: 12, color: _enableShipping ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _infoTile('Default Rate', _formatMoney(_defaultRate)),
              ),
              if (_freeShippingEnabled && _freeThreshold > 0) ...[
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.cardBorder,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: _infoTile('Free Shipping', '> ${_formatMoney(_freeThreshold)}'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: GoogleFonts.inter(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Search governorates or cities...',
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
        prefixIcon: const Icon(LucideIcons.search, color: AppColors.textMuted),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(LucideIcons.xCircle, color: AppColors.textMuted, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryDark),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final query = _searchQuery.trim().toLowerCase();
    
    if (query.isEmpty) {
      return Column(
        children: egyptLocations.map((gov) {
          final govRate = getGovernorateRate(gov.en);
          return Card(
            color: AppColors.surface,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text('${gov.en} (${gov.ar})', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                subtitle: Text('Base Rate: ${_formatMoney(govRate)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                children: [
                  const Divider(color: AppColors.cardBorder),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: gov.cities.map((city) {
                      final cityRate = getCityRate(gov.en, city.en);
                      final isException = cityRate != govRate;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isException ? const Color(0xFF0EA5E9).withValues(alpha: 0.1) : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isException ? const Color(0xFF0EA5E9).withValues(alpha: 0.3) : AppColors.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(city.en, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                            const SizedBox(width: 6),
                            Text(_formatMoney(cityRate), style: GoogleFonts.inter(fontSize: 12, fontWeight: isException ? FontWeight.bold : FontWeight.w600, color: isException ? const Color(0xFF0EA5E9) : AppColors.textSecondary)),
                          ],
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    // Search Mode
    final List<Widget> results = [];
    
    for (var gov in egyptLocations) {
      bool govMatches = gov.en.toLowerCase().contains(query) || gov.ar.toLowerCase().contains(query);
      
      if (govMatches) {
        final govRate = getGovernorateRate(gov.en);
        results.add(
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.cardBorder)),
            leading: const Icon(LucideIcons.map, color: AppColors.primaryDark),
            title: Text('${gov.en} (${gov.ar})', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            subtitle: Text('Governorate', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            trailing: Text(_formatMoney(govRate), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark)),
          ),
        );
        results.add(const SizedBox(height: 8));
      }

      for (var city in gov.cities) {
        if (city.en.toLowerCase().contains(query) || city.ar.toLowerCase().contains(query)) {
          final cityRate = getCityRate(gov.en, city.en);
          results.add(
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.cardBorder)),
              leading: const Icon(LucideIcons.building2, color: Color(0xFF0EA5E9)),
              title: Text('${city.en} (${city.ar})', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: Text('City in ${gov.en}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              trailing: Text(_formatMoney(cityRate), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark)),
            ),
          );
          results.add(const SizedBox(height: 8));
        }
      }
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            children: [
              const Icon(LucideIcons.searchX, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text('No locations found', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Column(children: results);
  }
}
