import 'package:admin_app/core/services/app_image_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/widgets/app_shimmer.dart';

class MerchandisingScreen extends StatefulWidget {
  const MerchandisingScreen({super.key});

  @override
  State<MerchandisingScreen> createState() => _MerchandisingScreenState();
}

class _MerchandisingScreenState extends State<MerchandisingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  bool _saving = false;
  bool _hasUnsavedChanges = false;
  String _search = '';
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];

  late Map<String, dynamic> _featured;
  late Map<String, dynamic> _newArrivals;
  late Map<String, dynamic> _shop;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _featured = _defaultSection(randomize: true, limit: 10);
    _newArrivals = _defaultSection(limit: 10, requireNewArrivalFlag: true);
    _shop = {
      ..._defaultSection(limit: 0, includeSoldOut: true),
      'showOnlySelectedFirst': true,
    };
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _defaultSection({
    bool randomize = false,
    bool includeSoldOut = false,
    bool requireNewArrivalFlag = false,
    int limit = 10,
  }) {
    return {
      'randomize': randomize,
      'selectedProductIds': <String>[],
      'categoryIds': <String>[],
      'includeSoldOut': includeSoldOut,
      'limit': limit,
      'sortMode': randomize ? 'manual' : 'newest',
      'requireNewArrivalFlag': requireNewArrivalFlag,
      'selectedOnly': false,
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);
      final data = await client.get('/api/admin/auth/merchandising');
      final settings = Map<String, dynamic>.from(data['settings'] ?? {});
      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(data['products'] ?? []);
        _categories = List<Map<String, dynamic>>.from(data['categories'] ?? []);
        _featured = _mergeSection(_featured, settings['featured']);
        _newArrivals = _mergeSection(_newArrivals, settings['newArrivals']);
        _shop = _mergeSection(_shop, settings['shop']);
        
        _normalizeSortMode(_featured, false);
        _normalizeSortMode(_newArrivals, false);
        _normalizeSortMode(_shop, true);

        _hasUnsavedChanges = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Could not load merchandising settings', AppColors.error);
    }
  }

  void _markChanged(VoidCallback change) {
    setState(() {
      change();
      _hasUnsavedChanges = true;
    });
  }

  void _normalizeSortMode(Map<String, dynamic> section, bool isShop) {
    final mode = _sectionMode(section, isShop);
    final showSort = mode == 'rules' || mode == 'all' || mode == 'pinned';
    if (showSort && section['sortMode'] == 'manual') {
      section['sortMode'] = 'newest';
    }
  }

  Map<String, dynamic> _mergeSection(
    Map<String, dynamic> base,
    dynamic incoming,
  ) {
    final next = <String, dynamic>{
      ...base,
      if (incoming is Map) ...Map<String, dynamic>.from(incoming),
    };
    next['selectedProductIds'] = List<String>.from(
      next['selectedProductIds'] ?? [],
    );
    next['categoryIds'] = List<String>.from(next['categoryIds'] ?? []);
    return next;
  }

  String _sectionMode(Map<String, dynamic> section, bool isShop) {
    final selectedIds = List<String>.from(section['selectedProductIds'] ?? []);
    if (section['randomize'] == true) return 'random';
    if (isShop) {
      if (selectedIds.isEmpty) return 'all';
      return section['showOnlySelectedFirst'] == true ? 'pinned' : 'manual';
    }
    if (section['selectedOnly'] == true || selectedIds.isNotEmpty) {
      return 'manual';
    }
    return 'rules';
  }

  void _applyMode(Map<String, dynamic> section, bool isShop, String mode) {
    HapticFeedback.selectionClick();
    _markChanged(() {
      if (mode == 'random') {
        section['randomize'] = true;
        section['selectedOnly'] = false;
        section['selectedProductIds'] = <String>[];
        section['sortMode'] = 'manual';
        if (isShop) section['showOnlySelectedFirst'] = true;
        return;
      }

      section['randomize'] = false;
      if (isShop) {
        if (mode == 'all') {
          section['selectedOnly'] = false;
          section['selectedProductIds'] = <String>[];
          section['showOnlySelectedFirst'] = true;
          if (section['sortMode'] == 'manual') section['sortMode'] = 'newest';
        } else if (mode == 'pinned') {
          section['selectedOnly'] = false;
          section['showOnlySelectedFirst'] = true;
          if (section['sortMode'] == 'manual') section['sortMode'] = 'newest';
        } else {
          section['selectedOnly'] = true;
          section['categoryIds'] = <String>[];
          section['showOnlySelectedFirst'] = false;
          section['sortMode'] = 'manual';
        }
        return;
      }

      if (mode == 'manual') {
        section['selectedOnly'] = true;
        section['categoryIds'] = <String>[];
        section['sortMode'] = 'manual';
      } else {
        section['selectedOnly'] = false;
        section['selectedProductIds'] = <String>[];
        if (section['sortMode'] == 'manual') section['sortMode'] = 'newest';
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final client = ApiClient(token: context.read<AuthProvider>().token);
      await client.put(
        '/api/admin/auth/merchandising',
        body: {
          'featured': _featured,
          'newArrivals': _newArrivals,
          'shop': _shop,
        },
      );
      if (!mounted) return;
      setState(() => _hasUnsavedChanges = false);
      _toast('Saved and synced to website', AppColors.success);
    } catch (e) {
      if (!mounted) return;
      _toast('Failed to save changes', AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(context).showAppToast(
      AppToast.snackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 64,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              color: AppColors.primaryDark,
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Merchandising',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
            actions: [
              if (_hasUnsavedChanges)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: FilledButton.icon(
                    onPressed: _saving || _loading ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.save, size: 16),
                    label: Text(_saving ? 'Saving' : 'Save'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(58),
              child: Container(
                height: 46,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'Featured'),
                    Tab(text: 'New Arrival'),
                    Tab(text: 'Shop'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primaryDark,
          child: _loading
              ? _loadingSkeleton()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _sectionView(
                      section: _featured,
                      title: 'Featured Collection',
                      subtitle: 'Homepage hero carousel product curation.',
                      icon: LucideIcons.star,
                      accent: AppColors.accent,
                    ),
                    _sectionView(
                      section: _newArrivals,
                      title: 'New Arrivals',
                      subtitle:
                          'Control products shown in homepage new arrivals.',
                      icon: LucideIcons.clock,
                      accent: const Color(0xFF0EA5E9),
                      showNewArrivalFlag: true,
                    ),
                    _sectionView(
                      section: _shop,
                      title: 'Shop Listing',
                      subtitle:
                          'Default order and visibility for all-products shop.',
                      icon: LucideIcons.shoppingBag,
                      accent: const Color(0xFF8B5CF6),
                      isShop: true,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _sectionView({
    required Map<String, dynamic> section,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    bool showNewArrivalFlag = false,
    bool isShop = false,
  }) {
    final selectedIds = List<String>.from(section['selectedProductIds'] ?? []);
    final selectedProducts = selectedIds
        .map(_productById)
        .whereType<Map<String, dynamic>>()
        .toList();
    final mode = _sectionMode(section, isShop);
    final showSort = mode == 'rules' || mode == 'all' || mode == 'pinned';
    final showLimit = !isShop;
    final showCategories =
        mode == 'random' ||
        mode == 'rules' ||
        mode == 'all' ||
        mode == 'pinned';
    final showPinned = mode == 'manual' || mode == 'pinned';
    final warning = _sectionWarning(
      section: section,
      selectedCount: selectedIds.length,
      mode: mode,
      isShop: isShop,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _heroCard(title, subtitle, icon, accent, selectedProducts.length),
        if (warning != null) ...[
          const SizedBox(height: 12),
          _warningTile(warning),
        ],
        const SizedBox(height: 14),
        _modePicker(section, isShop, mode, accent),
        const SizedBox(height: 14),
        _switchTile(
          title: 'Show sold out products',
          subtitle: 'Allow products with zero available stock to appear.',
          value: section['includeSoldOut'] == true,
          onChanged: (value) =>
              _markChanged(() => section['includeSoldOut'] = value),
        ),
        if (showNewArrivalFlag)
          _switchTile(
            title: 'Respect New Arrival product flag',
            subtitle: 'Only include products marked as New Arrivals.',
            value: section['requireNewArrivalFlag'] == true,
            onChanged: (value) =>
                _markChanged(() => section['requireNewArrivalFlag'] = value),
          ),
        if (showSort || showLimit) ...[
          const SizedBox(height: 12),
          _optionRow(section, showSort: showSort, showLimit: showLimit),
        ],
        if (showCategories) ...[
          const SizedBox(height: 18),
          _categoryPicker(section),
        ],
        if (showPinned) ...[
          const SizedBox(height: 18),
          _selectedProducts(section, selectedProducts, accent, mode),
          const SizedBox(height: 18),
          _productPicker(section, accent),
        ],
      ],
    );
  }

  Widget _modePicker(
    Map<String, dynamic> section,
    bool isShop,
    String activeMode,
    Color accent,
  ) {
    final options = isShop
        ? const [
            _MerchMode('all', 'All products', 'Sort and filter the full shop.'),
            _MerchMode(
              'pinned',
              'Pinned first',
              'Chosen products first, then rules.',
            ),
            _MerchMode('manual', 'Manual only', 'Show only the chosen order.'),
            _MerchMode('random', 'Random', 'Shuffle eligible shop products.'),
          ]
        : const [
            _MerchMode('random', 'Random mix', 'Shuffle eligible products.'),
            _MerchMode('manual', 'Manual list', 'Only products you choose.'),
            _MerchMode('rules', 'Smart rules', 'Use categories and sorting.'),
          ];

    return _panel(
      title: 'Display mode',
      subtitle: 'Pick one workflow. Conflicting controls are hidden.',
      child: Column(
        children: options.map((option) {
          final active = option.id == activeMode;
          return _modeTile(
            option: option,
            active: active,
            accent: accent,
            onTap: () => _applyMode(section, isShop, option.id),
          );
        }).toList(),
      ),
    );
  }

  String? _sectionWarning({
    required Map<String, dynamic> section,
    required int selectedCount,
    required String mode,
    required bool isShop,
  }) {
    final limit = section['limit'] as int? ?? 0;
    if (mode == 'manual' && selectedCount == 0) {
      return isShop
          ? 'Manual only with no pinned products will make the shop empty.'
          : 'Manual list with no products will hide this section on the website.';
    }
    if (!isShop && limit <= 0) {
      return 'Limit is zero, so this section will not show products.';
    }
    return null;
  }

  Widget _warningTile(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.alertTriangle,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingSkeleton() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _skeletonBlock(height: 92),
        const SizedBox(height: 14),
        _skeletonBlock(height: 210),
        const SizedBox(height: 14),
        _skeletonBlock(height: 86), // Fixed overflow (was 72)
        const SizedBox(height: 14),
        _skeletonBlock(height: 120),
        const SizedBox(height: 14),
        _skeletonBlock(height: 180),
      ],
    );
  }

  Widget _skeletonBlock({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppShimmer(width: 140, height: 14, borderRadius: 8),
          const SizedBox(height: 10),
          const Expanded(
            child: AppShimmer(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 8,
            ),
          ),
          const SizedBox(height: 10),
          const AppShimmer(width: 92, height: 10, borderRadius: 8),
        ],
      ),
    );
  }

  Widget _modeTile({
    required _MerchMode option,
    required bool active,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryDark.withValues(alpha: 0.08)
                : AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.primaryDark : AppColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppColors.primaryDark : Colors.transparent,
                  border: Border.all(
                    color: active ? AppColors.primaryDark : AppColors.textMuted,
                  ),
                ),
                child: active
                    ? const Icon(
                        LucideIcons.check,
                        color: Colors.white,
                        size: 13,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                active ? LucideIcons.lock : LucideIcons.chevronRight,
                color: active ? accent : AppColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard(
    String title,
    String subtitle,
    IconData icon,
    Color accent,
    int selectedCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primaryDark, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$selectedCount',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primaryDark,
            onChanged: (next) {
              HapticFeedback.selectionClick();
              onChanged(next);
            },
          ),
        ],
      ),
    );
  }

  Widget _optionRow(
    Map<String, dynamic> section, {
    required bool showSort,
    required bool showLimit,
  }) {
    return Row(
      children: [
        if (showSort)
          Expanded(
            child: _selectBox(
              label: 'Sort',
              value: section['sortMode']?.toString() ?? 'newest',
              items: const {
                'newest': 'Newest',
                'oldest': 'Oldest',
                'priceAsc': 'Price low',
                'priceDesc': 'Price high',
                'nameAsc': 'Name A-Z',
              },
              onChanged: (value) =>
                  _markChanged(() => section['sortMode'] = value),
            ),
          ),
        if (showSort && showLimit) const SizedBox(width: 12),
        if (showLimit)
          SizedBox(
            width: 112,
            child: _numberBox(
              label: 'Limit',
              value: section['limit'] as int? ?? 10,
              onChanged: (value) =>
                  _markChanged(() => section['limit'] = value),
            ),
          ),
      ],
    );
  }

  Widget _selectBox({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    final selectedValue = items.containsKey(value)
        ? value
        : (items.keys.contains('newest') ? 'newest' : items.keys.first);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              isExpanded: true,
              items: items.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _numberBox({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepButton(
                icon: LucideIcons.minus,
                onTap: value > 1 ? () => onChanged(value - 1) : null,
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
              _stepButton(
                icon: LucideIcons.plus,
                onTap: () => onChanged(value + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepButton({required IconData icon, required VoidCallback? onTap}) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 32,
        height: 36,
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.primaryDark : AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _categoryPicker(Map<String, dynamic> section) {
    final selected = List<String>.from(section['categoryIds'] ?? []);
    return _panel(
      title: 'Allowed categories',
      subtitle: 'Leave empty to allow all categories.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _categories.map((category) {
          final id = category['id'].toString();
          final active = selected.contains(id);
          return FilterChip(
            selected: active,
            label: Text(category['name']?.toString() ?? 'Category'),
            selectedColor: AppColors.primaryDark.withValues(alpha: 0.12),
            checkmarkColor: AppColors.primaryDark,
            onSelected: (value) {
              _markChanged(() {
                if (value) {
                  selected.add(id);
                } else {
                  selected.remove(id);
                }
                section['categoryIds'] = selected;
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _selectedProducts(
    Map<String, dynamic> section,
    List<Map<String, dynamic>> products,
    Color accent,
    String mode,
  ) {
    final ids = List<String>.from(section['selectedProductIds'] ?? []);
    final subtitle = mode == 'pinned'
        ? 'These appear first. The rest follows your rules below.'
        : 'Only these products will appear, in this exact order.';
    return _panel(
      title: 'Pinned products',
      subtitle: subtitle,
      child: products.isEmpty
          ? _empty('No pinned products yet.')
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              onReorder: (oldIndex, newIndex) {
                _markChanged(() {
                  if (newIndex > oldIndex) newIndex--;
                  final id = ids.removeAt(oldIndex);
                  ids.insert(newIndex, id);
                  section['selectedProductIds'] = ids;
                });
              },
              itemBuilder: (context, index) {
                final product = products[index];
                return _productRow(
                  key: ValueKey('selected-${product['id']}'),
                  product: product,
                  accent: accent,
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => _markChanged(() {
                      ids.remove(product['id']);
                      section['selectedProductIds'] = ids;
                    }),
                  ),
                  leading: const Icon(
                    LucideIcons.gripVertical,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                );
              },
            ),
    );
  }

  Widget _productPicker(Map<String, dynamic> section, Color accent) {
    final selectedIds = List<String>.from(section['selectedProductIds'] ?? []);
    final filtered = _products
        .where((product) {
          final name = product['name']?.toString().toLowerCase() ?? '';
          return _search.isEmpty || name.contains(_search.toLowerCase());
        })
        .take(80)
        .toList();

    return _panel(
      title: 'Add products',
      subtitle: 'Search and pin products into this section.',
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(LucideIcons.search, size: 18),
              hintText: 'Search products...',
            ),
          ),
          const SizedBox(height: 12),
          ...filtered.map((product) {
            final id = product['id'].toString();
            final selected = selectedIds.contains(id);
            return _productRow(
              key: ValueKey('picker-$id'),
              product: product,
              accent: accent,
              trailing: IconButton(
                icon: Icon(
                  selected ? LucideIcons.checkCircle : LucideIcons.plusCircle,
                  color: selected ? AppColors.success : AppColors.primaryDark,
                  size: 20,
                ),
                onPressed: selected
                    ? null
                    : () => _markChanged(() {
                        selectedIds.add(id);
                        section['selectedProductIds'] = selectedIds;
                      }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _productRow({
    required Key key,
    required Map<String, dynamic> product,
    required Color accent,
    Widget? leading,
    required Widget trailing,
  }) {
    final inStock = product['inStock'] == true;
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 8)],
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: product['imageUrl'] != null
                ? CachedNetworkImage(
                    imageUrl: product['imageUrl'],
                    cacheManager: AppImageCacheManager.instance,
                    fit: BoxFit.cover,
                  )
                : Icon(LucideIcons.package, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name']?.toString() ?? 'Product',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${product['categoryName'] ?? 'Uncategorized'} - ${product['totalStock'] ?? 0} in stock',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: inStock ? AppColors.textMuted : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Map<String, dynamic>? _productById(String id) {
    for (final product in _products) {
      if (product['id'] == id) return product;
    }
    return null;
  }
}

class _MerchMode {
  final String id;
  final String title;
  final String subtitle;

  const _MerchMode(this.id, this.title, this.subtitle);
}
