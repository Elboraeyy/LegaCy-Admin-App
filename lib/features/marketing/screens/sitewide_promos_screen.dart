import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';

class SitewidePromosScreen extends StatefulWidget {
  const SitewidePromosScreen({super.key});
  @override
  State<SitewidePromosScreen> createState() => _SitewidePromosScreenState();
}

class _SitewidePromosScreenState extends State<SitewidePromosScreen> {
  bool _isLoading = true;
  bool _enabled = false;

  bool _tier3Enabled = true;
  final TextEditingController _tier3Label = TextEditingController(text: 'Buy 2 Get 1 Free');

  bool _tier2Enabled = true;
  final TextEditingController _tier2Discount = TextEditingController(text: '50');
  final TextEditingController _tier2Label = TextEditingController(text: 'Buy 1 Get 2nd at 50% OFF');

  bool _tier1Enabled = true;
  final TextEditingController _tier1Discount = TextEditingController(text: '20');
  final TextEditingController _tier1Label = TextEditingController(text: '20% OFF any item');

  // Original state tracking
  bool _originalEnabled = false;
  bool _originalTier3Enabled = true;
  String _originalTier3Label = 'Buy 2 Get 1 Free';
  bool _originalTier2Enabled = true;
  String _originalTier2Discount = '50';
  String _originalTier2Label = 'Buy 1 Get 2nd at 50% OFF';
  bool _originalTier1Enabled = true;
  String _originalTier1Discount = '20';
  String _originalTier1Label = '20% OFF any item';

  bool get _hasChanges {
    return _enabled != _originalEnabled ||
           _tier3Enabled != _originalTier3Enabled ||
           _tier3Label.text != _originalTier3Label ||
           _tier2Enabled != _originalTier2Enabled ||
           _tier2Discount.text != _originalTier2Discount ||
           _tier2Label.text != _originalTier2Label ||
           _tier1Enabled != _originalTier1Enabled ||
           _tier1Discount.text != _originalTier1Discount ||
           _tier1Label.text != _originalTier1Label;
  }

  @override
  void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/config/settings?keys=sitewide_offer_settings');
      if (mounted) {
        if (data['sitewide_offer_settings'] != null) {
          final Map<String, dynamic> config = jsonDecode(data['sitewide_offer_settings']);
          setState(() {
            _enabled = config['enabled'] ?? false;
            _tier3Enabled = config['tier3Enabled'] ?? true;
            _tier3Label.text = config['tier3Label'] ?? 'Buy 2 Get 1 Free';
            
            _tier2Enabled = config['tier2Enabled'] ?? true;
            _tier2Discount.text = (config['tier2DiscountPercent'] ?? 50).toString();
            _tier2Label.text = config['tier2Label'] ?? 'Buy 1 Get 2nd at 50% OFF';
            
            _tier1Enabled = config['tier1Enabled'] ?? true;
            _tier1Discount.text = (config['tier1DiscountPercent'] ?? 20).toString();
            _tier1Label.text = config['tier1Label'] ?? '20% OFF any item';
            
            _originalEnabled = _enabled;
            _originalTier3Enabled = _tier3Enabled;
            _originalTier3Label = _tier3Label.text;
            _originalTier2Enabled = _tier2Enabled;
            _originalTier2Discount = _tier2Discount.text;
            _originalTier2Label = _tier2Label.text;
            _originalTier1Enabled = _tier1Enabled;
            _originalTier1Discount = _tier1Discount.text;
            _originalTier1Label = _tier1Label.text;
          });
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      
      final config = {
        'enabled': _enabled,
        'tier3Enabled': _tier3Enabled,
        'tier3Label': _tier3Label.text,
        'tier2Enabled': _tier2Enabled,
        'tier2DiscountPercent': int.tryParse(_tier2Discount.text) ?? 50,
        'tier2Label': _tier2Label.text,
        'tier1Enabled': _tier1Enabled,
        'tier1DiscountPercent': int.tryParse(_tier1Discount.text) ?? 20,
        'tier1Label': _tier1Label.text,
      };

      await client.put('/api/admin/config/settings', body: {
        'settings': [
          {'key': 'sitewide_offer_settings', 'value': jsonEncode(config)},
        ]
      });
      if (mounted) {
        setState(() {
          _originalEnabled = _enabled;
          _originalTier3Enabled = _tier3Enabled;
          _originalTier3Label = _tier3Label.text;
          _originalTier2Enabled = _tier2Enabled;
          _originalTier2Discount = _tier2Discount.text;
          _originalTier2Label = _tier2Label.text;
          _originalTier1Enabled = _tier1Enabled;
          _originalTier1Discount = _tier1Discount.text;
          _originalTier1Label = _tier1Label.text;
        });
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Offer settings saved'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTierCard({
    required String title,
    required String icon,
    required String subtitle,
    required bool enabled,
    required Function(bool) onToggle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled && _enabled ? AppColors.surface : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: enabled && _enabled ? const Color(0xFF14B8A6).withValues(alpha: 0.3) : AppColors.cardBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark))),
              Switch(value: enabled, onChanged: onToggle, activeTrackColor: const Color(0xFF14B8A6)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF14B8A6);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(LucideIcons.target, color: color),
            const SizedBox(width: 8),
            Text('Site-Wide Offer', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
          ],
        ),
        backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark), onPressed: () => Navigator.pop(context)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSettings,
        color: const Color(0xFF14B8A6),
        child: _isLoading
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: double.infinity, height: 24),
                        SizedBox(height: 16),
                        AppShimmer(width: 240, height: 14),
                        SizedBox(height: 24),
                        AppShimmer(width: double.infinity, height: 1),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tier card skeleton 1
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: 180, height: 20),
                        SizedBox(height: 8),
                        AppShimmer(width: 260, height: 12),
                        SizedBox(height: 16),
                        AppShimmer(width: double.infinity, height: 48, borderRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tier card skeleton 2
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: 200, height: 20),
                        SizedBox(height: 8),
                        AppShimmer(width: 240, height: 12),
                        SizedBox(height: 16),
                        AppShimmer(width: double.infinity, height: 48, borderRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tier card skeleton 3
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: 160, height: 20),
                        SizedBox(height: 8),
                        AppShimmer(width: 220, height: 12),
                        SizedBox(height: 16),
                        AppShimmer(width: double.infinity, height: 48, borderRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const AppShimmer(width: double.infinity, height: 48, borderRadius: 12),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Enable Site-Wide Offer', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                                  const SizedBox(height: 4),
                                  Text('Automatic discount applied to all orders at checkout', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _enabled,
                              onChanged: (v) => setState(() => _enabled = v),
                              activeTrackColor: color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Divider(color: AppColors.divider, height: 1),
                        const SizedBox(height: 24),
                        
                        _buildTierCard(
                          title: '3+ Items → Cheapest FREE',
                          icon: '🎁',
                          subtitle: 'Customer pays for the 2 most expensive items, cheapest is free',
                          enabled: _tier3Enabled,
                          onToggle: (v) => setState(() => _tier3Enabled = v),
                          children: [
                            TextField(
                              controller: _tier3Label,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Offer Label',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            )
                          ],
                        ),

                        _buildTierCard(
                          title: '2 Items → 2nd at Discount',
                          icon: '🏷️',
                          subtitle: 'Pay full for most expensive, discount on the cheapest',
                          enabled: _tier2Enabled,
                          onToggle: (v) => setState(() => _tier2Enabled = v),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: _tier2Discount,
                                    onChanged: (_) => setState(() {}),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Discount %',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _tier2Label,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      labelText: 'Offer Label',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),

                        _buildTierCard(
                          title: '1 Item → Discount',
                          icon: '💰',
                          subtitle: 'Percentage discount on any single item',
                          enabled: _tier1Enabled,
                          onToggle: (v) => setState(() => _tier1Enabled = v),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: _tier1Discount,
                                    onChanged: (_) => setState(() {}),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Discount %',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _tier1Label,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      labelText: 'Offer Label',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),

                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_hasChanges && !_isLoading) ? _saveSettings : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              elevation: 0,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade500,
                            ),
                            child: Text('Save Settings', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

