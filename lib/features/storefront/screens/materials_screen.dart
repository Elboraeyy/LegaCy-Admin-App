import 'package:admin_app/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/features/storefront/screens/organize_products_screen.dart';
import '../../../core/widgets/app_shimmer.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  bool _isLoading = true;
  bool _hasUnsavedOrder = false;
  bool _isSavingOrder = false;
  String? _error;
  List<dynamic> _materials = [];
  List<dynamic> _filteredMaterials = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    _searchController.addListener(_filterMaterials);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMaterials() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredMaterials = _materials.where((m) {
        final name = m['name']?.toString().toLowerCase() ?? '';
        final slug = m['slug']?.toString().toLowerCase() ?? '';
        return name.contains(q) || slug.contains(q);
      }).toList();
    });
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final data = await client.get('/api/admin/auth/materials');
      if (mounted) {
        setState(() {
          _materials = data['materials'] ?? [];
          _filteredMaterials = List.from(_materials);
          _hasUnsavedOrder = false;
          _isSavingOrder = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveMaterialOrder() async {
    setState(() => _isSavingOrder = true);
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      final items = _materials
          .asMap()
          .entries
          .map((e) => {'id': e.value['id'], 'sortOrder': e.key})
          .toList();
      await client.put(
        '/api/admin/auth/materials/reorder',
        body: {'items': items},
      );
      if (!mounted) return;
      setState(() {
        _hasUnsavedOrder = false;
        _isSavingOrder = false;
      });
      ScaffoldMessenger.of(context).showAppToast(
        AppToast.snackBar(
          content: Text(
            'Material order saved & synced to website',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingOrder = false);
      ScaffoldMessenger.of(context).showAppToast(
        AppToast.snackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteMaterial(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Material',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        content: Text(
          'Materials linked to products cannot be deleted.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    try {
      final token = context.read<AuthProvider>().token;
      final client = ApiClient(token: token);
      await client.delete('/api/admin/auth/materials/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppToast(
        AppToast.snackBar(
          content: Text('Material deleted'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadMaterials();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppToast(
        AppToast.snackBar(
          content: Text('$e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddEdit({Map<String, dynamic>? material}) {
    final nameCtrl = TextEditingController(text: material?['name'] ?? '');
    final slugCtrl = TextEditingController(text: material?['slug'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              Text(
                material != null ? 'Edit Material' : 'New Material',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 20),
              Focus(
                onFocusChange: (f) {
                  if (!f && slugCtrl.text.isEmpty && nameCtrl.text.isNotEmpty) {
                    slugCtrl.text = nameCtrl.text
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                        .replaceAll(RegExp(r'(^-|-$)'), '');
                  }
                },
                child: _field('Material Name', nameCtrl, LucideIcons.layers),
              ),
              const SizedBox(height: 12),
              _field('URL Slug', slugCtrl, LucideIcons.link),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || slugCtrl.text.trim().isEmpty) {
                      return;
                    }
                    final body = {
                      'name': nameCtrl.text.trim(),
                      'nameAr': material?['nameAr'], // Keep existing if edit
                      'slug': slugCtrl.text.trim(),
                    };
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final token = context.read<AuthProvider>().token;
                      final client = ApiClient(token: token);
                      if (material != null) {
                        await client.put(
                          '/api/admin/auth/materials/${material['id']}',
                          body: body,
                        );
                      } else {
                        await client.post(
                          '/api/admin/auth/materials',
                          body: body,
                        );
                      }
                      if (!context.mounted) return;
                      Navigator.pop(ctx);
                      _loadMaterials();
                    } catch (e) {
                      if (!context.mounted) return;
                      messenger.showAppToast(
                        AppToast.snackBar(
                          content: Text('$e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    material != null ? 'Save Changes' : 'Create Material',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              expandedHeight: 130,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              leading: IconButton(
                icon: const Icon(
                  LucideIcons.arrowLeft,
                  color: AppColors.primaryDark,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Materials',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              actions: [
                if (_hasUnsavedOrder)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: TextButton.icon(
                      onPressed: _isSavingOrder ? null : _saveMaterialOrder,
                      icon: _isSavingOrder
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.save, size: 18),
                      label: const Text('Save'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                      ),
                    ),
                  ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(70),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search materials...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        prefixIcon: const Icon(
                          LucideIcons.search,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  LucideIcons.x,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: 5,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const AppShimmer(width: 48, height: 48, shape: BoxShape.circle),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              AppShimmer(width: 120, height: 16),
                              SizedBox(height: 6),
                              AppShimmer(width: 160, height: 12),
                            ],
                          ),
                        ),
                        const AppShimmer(width: 24, height: 24, borderRadius: 6),
                      ],
                    ),
                  ),
                ),
              )
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadMaterials,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _filteredMaterials.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF64748B).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.layers,
                        size: 48,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Materials Found',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try searching for something else.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadMaterials,
                color: AppColors.primaryDark,
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _filteredMaterials.length,
                  buildDefaultDragHandles: _searchController.text.isEmpty,
                  proxyDecorator: (child, index, animation) =>
                      Material(color: Colors.transparent, child: child),
                  onReorder: (oldIndex, newIndex) {
                    if (_searchController.text.isNotEmpty) return;
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _filteredMaterials.removeAt(oldIndex);
                      _filteredMaterials.insert(newIndex, item);
                      _materials = List.from(_filteredMaterials);
                      _hasUnsavedOrder = true;
                    });
                  },
                  itemBuilder: (context, index) {
                    final mat = _filteredMaterials[index];
                    final productCount = mat['_count']?['products'] ?? 0;
                    return Padding(
                      key: ValueKey(mat['id']),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrganizeProductsScreen(
                                entityId: mat['id'],
                                entityName: mat['name'] ?? 'Material',
                                type: OrganizeType.material,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF64748B,
                                  ).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.layers,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mat['name'] ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$productCount products - /${mat['slug']}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  LucideIcons.moreVertical,
                                  color: AppColors.textMuted,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    _showAddEdit(material: mat);
                                  } else if (v == 'delete') {
                                    _deleteMaterial(mat['id']);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.edit, size: 16),
                                        SizedBox(width: 10),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          LucideIcons.trash2,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showAddEdit();
        },
        backgroundColor: AppColors.primaryDark,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: Text(
          'New Material',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      ),
    );
  }
}
