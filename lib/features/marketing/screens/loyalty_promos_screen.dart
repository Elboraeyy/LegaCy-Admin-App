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

class LoyaltyPromosScreen extends StatefulWidget {
  const LoyaltyPromosScreen({super.key});
  @override
  State<LoyaltyPromosScreen> createState() => _LoyaltyPromosScreenState();
}

class _LoyaltyPromosScreenState extends State<LoyaltyPromosScreen> with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFFEAB308);
  late TabController _tabController;
  bool _isLoading = true;
  bool _saving = false;

  // Settings
  bool _enabled = false;
  final _pointsPerEgpCtrl = TextEditingController(text: '1');
  final _pointValueCtrl = TextEditingController(text: '0.1');
  final _minRedeemCtrl = TextEditingController(text: '100');
  final _minOrderCtrl = TextEditingController(text: '0');
  final _couponValidityCtrl = TextEditingController(text: '30');

  // Original states
  bool _originalEnabled = false;
  String _originalPointsPerEgp = '1';
  String _originalPointValue = '0.1';
  String _originalMinRedeem = '100';
  String _originalMinOrder = '0';
  String _originalCouponValidity = '30';

  bool get _hasChanges {
    return _enabled != _originalEnabled ||
           _pointsPerEgpCtrl.text != _originalPointsPerEgp ||
           _pointValueCtrl.text != _originalPointValue ||
           _minRedeemCtrl.text != _originalMinRedeem ||
           _minOrderCtrl.text != _originalMinOrder ||
           _couponValidityCtrl.text != _originalCouponValidity;
  }

  // Stats
  int _totalPoints = 0;
  int _redeemedMonth = 0;
  int _activeMembers = 0;
  String _earningRate = '0';

  // Members
  final _memberSearchCtrl = TextEditingController();
  List<dynamic> _members = [];
  bool _searchingMembers = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pointsPerEgpCtrl.dispose();
    _pointValueCtrl.dispose();
    _minRedeemCtrl.dispose();
    _minOrderCtrl.dispose();
    _couponValidityCtrl.dispose();
    _memberSearchCtrl.dispose();
    super.dispose();
  }

  ApiClient get _client => ApiClient(token: context.read<AuthProvider>().token);

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadSettings(), _loadStats()]);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _client.get('/api/admin/loyalty/settings');
      if (mounted) {
        setState(() {
          _enabled = data['enabled'] ?? false;
          _pointsPerEgpCtrl.text = (data['pointsPerEgp'] ?? 1).toString();
          _pointValueCtrl.text = (data['pointValue'] ?? 0.1).toString();
          _minRedeemCtrl.text = (data['minRedeemPoints'] ?? 100).toString();
          _minOrderCtrl.text = (data['minOrderTotal'] ?? 0).toString();
          _couponValidityCtrl.text = (data['couponValidity'] ?? 30).toString();

          _originalEnabled = _enabled;
          _originalPointsPerEgp = _pointsPerEgpCtrl.text;
          _originalPointValue = _pointValueCtrl.text;
          _originalMinRedeem = _minRedeemCtrl.text;
          _originalMinOrder = _minOrderCtrl.text;
          _originalCouponValidity = _couponValidityCtrl.text;
        });
      }
    } catch (_) {
      // Fallback: try config/settings endpoint
      try {
        final data = await _client.get('/api/admin/config/settings?keys=loyalty_settings');
        if (mounted && data['loyalty_settings'] != null) {
          final config = jsonDecode(data['loyalty_settings']);
          setState(() {
            _enabled = config['enabled'] ?? false;
            _pointsPerEgpCtrl.text = (config['pointsPerEgp'] ?? 1).toString();
            _pointValueCtrl.text = (config['pointValue'] ?? 0.1).toString();
            _minRedeemCtrl.text = (config['minRedeemPoints'] ?? 100).toString();
            _minOrderCtrl.text = (config['minOrderTotal'] ?? 0).toString();
            _couponValidityCtrl.text = (config['couponValidity'] ?? 30).toString();

            _originalEnabled = _enabled;
            _originalPointsPerEgp = _pointsPerEgpCtrl.text;
            _originalPointValue = _pointValueCtrl.text;
            _originalMinRedeem = _minRedeemCtrl.text;
            _originalMinOrder = _minOrderCtrl.text;
            _originalCouponValidity = _couponValidityCtrl.text;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadStats() async {
    try {
      final data = await _client.get('/api/admin/loyalty/stats');
      if (mounted) {
        setState(() {
          _totalPoints = data['totalPointsInCirculation'] ?? 0;
          _redeemedMonth = data['totalPointsRedeemedThisMonth'] ?? 0;
          _activeMembers = data['activeLoyaltyMembers'] ?? 0;
          _earningRate = '${data['config']?['pointsPerEgp'] ?? _pointsPerEgpCtrl.text}';
        });
      }
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      final body = {
        'enabled': _enabled,
        'pointsPerEgp': double.tryParse(_pointsPerEgpCtrl.text) ?? 1,
        'pointValue': double.tryParse(_pointValueCtrl.text) ?? 0.1,
        'minRedeemPoints': int.tryParse(_minRedeemCtrl.text) ?? 100,
        'minOrderTotal': double.tryParse(_minOrderCtrl.text) ?? 0,
        'couponValidity': int.tryParse(_couponValidityCtrl.text) ?? 30,
      };

      try {
        await _client.put('/api/admin/loyalty/settings', body: body);
      } catch (_) {
        // Fallback
        await _client.put('/api/admin/config/settings', body: {
          'settings': [
            {'key': 'loyalty_settings', 'value': jsonEncode(body)},
          ]
        });
      }

      if (mounted) {
        setState(() {
          _originalEnabled = _enabled;
          _originalPointsPerEgp = _pointsPerEgpCtrl.text;
          _originalPointValue = _pointValueCtrl.text;
          _originalMinRedeem = _minRedeemCtrl.text;
          _originalMinOrder = _minOrderCtrl.text;
          _originalCouponValidity = _couponValidityCtrl.text;
        });
        ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Loyalty settings saved'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _searchMembers(String query) async {
    if (query.length < 2) {
      setState(() => _members = []);
      return;
    }
    setState(() => _searchingMembers = true);
    try {
      final data = await _client.get('/api/admin/loyalty/members?search=${Uri.encodeComponent(query)}');
      if (mounted) setState(() => _members = data['members'] ?? data ?? []);
    } catch (_) {
      // Fallback: try users endpoint
      try {
        final data = await _client.get('/api/admin/auth/users?search=${Uri.encodeComponent(query)}&limit=20');
        if (mounted) setState(() => _members = data['users'] ?? []);
      } catch (_) {}
    }
    if (mounted) setState(() => _searchingMembers = false);
  }

  void _showAdjustPointsDialog(Map<String, dynamic> member) {
    final pointsCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Adjust Points', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(LucideIcons.user, size: 20, color: _LoyaltyPromosScreenState._accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member['name'] ?? member['email'] ?? 'User', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('Current: ${member['points'] ?? 0} pts', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Points (+/-)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: pointsCtrl,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: InputDecoration(
                  hintText: 'e.g. 500 or -200',
                  helperText: 'Negative value to deduct points',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Reason', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Manual adjustment, Bonus',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () async {
              if (pointsCtrl.text.isEmpty || reasonCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _client.post('/api/admin/loyalty/adjust-points', body: {
                  'userId': member['id'],
                  'points': int.parse(pointsCtrl.text),
                  'reason': reasonCtrl.text,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Points adjusted'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
                  _searchMembers(_memberSearchCtrl.text);
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showAppToast(AppToast.snackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(LucideIcons.star, color: _accent),
            const SizedBox(width: 8),
            Text('Loyalty Program', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
          ],
        ),
        backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.primaryDark), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            height: 50,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Settings'),
                Tab(text: 'Members'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const AppShimmer(width: double.infinity, height: 56, borderRadius: 16),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: const AppShimmer(width: double.infinity, height: 80, borderRadius: 16)),
                    const SizedBox(width: 12),
                    Expanded(child: const AppShimmer(width: double.infinity, height: 80, borderRadius: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: const AppShimmer(width: double.infinity, height: 80, borderRadius: 16)),
                    const SizedBox(width: 12),
                    Expanded(child: const AppShimmer(width: double.infinity, height: 80, borderRadius: 16)),
                  ],
                ),
              ],
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSettingsTab(),
                _buildMembersTab(),
              ],
            ),
    );
  }

  // ─── OVERVIEW TAB ───
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      color: _accent,
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _enabled ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _enabled ? AppColors.success.withValues(alpha: 0.3) : AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _enabled ? AppColors.success.withValues(alpha: 0.2) : AppColors.error.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(_enabled ? LucideIcons.checkCircle : LucideIcons.xCircle, color: _enabled ? AppColors.success : AppColors.error, size: 20),
                ),
                const SizedBox(width: 12),
                Text(_enabled ? 'System Active' : 'System Disabled', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _enabled ? AppColors.success : AppColors.error)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats Grid
          Row(
            children: [
              Expanded(child: _buildStatCard('⭐', 'Points in\nCirculation', _totalPoints.toString(), const Color(0xFF3B82F6))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('🎁', 'Redeemed\n(Month)', _redeemedMonth.toString(), const Color(0xFF8B5CF6))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('👥', 'Active\nMembers', _activeMembers.toString(), const Color(0xFF10B981))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('⚡', 'Earning\nRate', '$_earningRate pts/EGP', const Color(0xFFF59E0B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, height: 1.3)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SETTINGS TAB ───
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Enable Toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enable Loyalty System', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                    const SizedBox(height: 4),
                    Text('Allow customers to earn and redeem points', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Switch(value: _enabled, onChanged: (v) => setState(() => _enabled = v), activeTrackColor: _accent),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Earning Rules
        _buildSectionLabel('Earning Rules'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
          child: Column(
            children: [
              _buildConfigField(_pointsPerEgpCtrl, 'Points per 1 EGP', 'How many points user earns per 1 EGP spent', LucideIcons.coins),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Redemption Rules
        _buildSectionLabel('Redemption Rules'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
          child: Column(
            children: [
              _buildConfigField(_pointValueCtrl, 'Point Value (EGP)', 'Value of 1 point (e.g. 0.1 = 10pts = 1 EGP)', LucideIcons.banknote),
              const SizedBox(height: 16),
              _buildConfigField(_minRedeemCtrl, 'Minimum Redeem Points', 'Min points required to generate a coupon', LucideIcons.gift),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Restrictions
        _buildSectionLabel('Restrictions & Validity'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
          child: Column(
            children: [
              _buildConfigField(_minOrderCtrl, 'Minimum Order Total', 'Min order to earn points (0 = no limit)', LucideIcons.shoppingCart),
              const SizedBox(height: 16),
              _buildConfigField(_couponValidityCtrl, 'Coupon Validity (Days)', 'How long generated coupons remain valid', LucideIcons.calendar),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Save Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_hasChanges && !_saving) ? _saveSettings : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 0,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade500,
            ),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Save Configuration', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
    );
  }

  Widget _buildConfigField(TextEditingController ctrl, String label, String desc, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: _accent),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(desc, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ─── MEMBERS TAB ───
  Widget _buildMembersTab() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
            child: TextField(
              controller: _memberSearchCtrl,
              onChanged: _searchMembers,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name, email or phone...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
                suffixIcon: _memberSearchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(LucideIcons.x, size: 16), onPressed: () { _memberSearchCtrl.clear(); setState(() => _members = []); })
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

        // Results
        Expanded(
          child: _searchingMembers
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 4,
                  itemBuilder: (_, i) => Padding(
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
                          const AppShimmer(width: 44, height: 44, shape: BoxShape.circle),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                AppShimmer(width: 100, height: 14),
                                SizedBox(height: 6),
                                AppShimmer(width: 120, height: 12),
                              ],
                            ),
                          ),
                          const AppShimmer(width: 60, height: 24, borderRadius: 12),
                        ],
                      ),
                    ),
                  ),
                )
              : _members.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.users, size: 48, color: AppColors.textMuted.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text(
                            _memberSearchCtrl.text.length < 2 ? 'Start typing to search members' : 'No members found',
                            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _members.length,
                      itemBuilder: (_, i) => _buildMemberCard(_members[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final points = member['points'] ?? 0;
    final pointVal = double.tryParse(_pointValueCtrl.text) ?? 0.1;
    final egpValue = (points * pointVal).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(child: Text(((member['name'] ?? member['email'] ?? '?') as String).substring(0, 1).toUpperCase(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _accent))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member['name'] ?? 'Unknown', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(member['email'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                if (member['phone'] != null) Text(member['phone'], style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('$points pts', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF3B82F6))),
              ),
              const SizedBox(height: 4),
              Text('≈ $egpValue EGP', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showAdjustPointsDialog(member),
                child: Text('Adjust', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _accent, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

