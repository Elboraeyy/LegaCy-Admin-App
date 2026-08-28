import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/features/notifications/notification_provider.dart';
import 'package:admin_app/features/orders/orders_screen.dart';
import 'package:admin_app/features/products/products_screen.dart';
import 'package:admin_app/features/dashboard/dashboard_screen.dart';
import 'package:admin_app/features/reports/reports_screen.dart';
import 'package:admin_app/features/more/more_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  int _currentIndex = 2; // Default: Dashboard (center)

  @override
  void initState() {
    super.initState();
    // Initialize notifications with the auth token
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().token;
      context.read<NotificationProvider>().init(token);
    });
  }

  final _screens = const [
    OrdersScreen(),
    ProductsScreen(),
    DashboardScreen(),
    ReportsScreen(),
    MoreScreen(),
  ];

  final List<IconData> _icons = [
    LucideIcons.shoppingBag,
    LucideIcons.package2,
    LucideIcons.layoutDashboard,
    LucideIcons.barChart3,
    LucideIcons.menu,
  ];

  final List<String> _labels = [
    'Orders',
    'Catalog',
    'Dashboard',
    'Reports',
    'More',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildAnimatedNavBar(),
    );
  }

  Widget _buildAnimatedNavBar() {
    const primaryDark = Color(0xFF12403C);
    const goldAccent = Color(0xFFD4AF37);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double navBarWidth = screenWidth - 32;
    final double itemWidth = navBarWidth / 5;

    return SizedBox(
      height: 144, // 120 for nav bar + 24 for bottom margin
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Solid background to hide content behind the lower half of the nav bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 59, // 24 (margin) + 35 (half of nav bar) = 59. Hides the cut-off behind the solid nav bar.
            child: Container(
              color: AppColors.background,
            ),
          ),

          // The Floating Nav Bar
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            height: 120,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Background Bar
                Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: primaryDark,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: primaryDark.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),

          // Moving Active Bubble Background
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            left: _currentIndex * itemWidth + (itemWidth / 2) - 34,
            bottom: 40,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(6),
              child: Container(
                decoration: const BoxDecoration(
                  color: goldAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Icons Row
          SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (index) {
                final isActive = _currentIndex == index;
                return GestureDetector(
                  onTap: () {
                    if (_currentIndex != index) {
                      HapticFeedback.mediumImpact();
                      setState(() => _currentIndex = index);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: itemWidth,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Active Icon (Floating)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                          bottom: isActive ? 60 : -50, // Center in the bubble
                          child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                            opacity: isActive ? 1.0 : 0.0,
                            child: Icon(
                              _icons[index],
                              size: 28,
                              color: primaryDark,
                            ),
                          ),
                        ),

                        // Inactive Icon & Label
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isActive ? 0.0 : 1.0,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _icons[index],
                                size: 22,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _labels[index],
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
