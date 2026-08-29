import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/auth/auth_provider.dart';
import 'package:admin_app/features/dashboard/providers/todo_provider.dart';
import 'package:admin_app/features/notifications/notification_provider.dart';
import 'package:admin_app/core/services/notification_service.dart';
import 'package:admin_app/features/auth/login_screen.dart';
import 'package:admin_app/features/home/home_shell.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:admin_app/core/services/unread_tracker.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Android system tray automatically displays the notification
  // from the 'notification' field when app is in background/terminated.
  // We do NOT show a local notification here to avoid duplicates.
  // This handler exists only because Firebase requires it to be registered.
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set status bar style
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  } catch (e) {
    debugPrint('SystemUIOverlayStyle error: $e');
  }

  // Initialize notification service safely
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  // Initialize UnreadTracker safely
  try {
    await UnreadTracker.init();
  } catch (e) {
    debugPrint('UnreadTracker init error: $e');
  }

  // Initialize Firebase and messaging safely
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TodoProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const LegacyAdminApp(),
    ),
  );
}

class LegacyAdminApp extends StatefulWidget {
  const LegacyAdminApp({super.key});

  @override
  State<LegacyAdminApp> createState() => _LegacyAdminAppState();
}

class _LegacyAdminAppState extends State<LegacyAdminApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await Future.wait([
        context.read<AuthProvider>().tryAutoLogin().catchError((e) {
          debugPrint('tryAutoLogin error: $e');
        }),
        Future.delayed(const Duration(milliseconds: 2000)),
      ]);
    } catch (e) {
      debugPrint('App init error: $e');
    } finally {
      if (mounted) {
        setState(() => _initialized = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Legacy Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        );
      },
      home: _initialized
          ? Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isLoggedIn) {
                  return const HomeShell();
                }
                return const LoginScreen();
              },
            )
          : const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;
  
  late Animation<double> _loaderScale;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Logo: 0.0 -> 0.6s
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.24, curve: Curves.easeOut)),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.24, curve: Curves.easeOut)),
    );

    // Title: 0.3s -> 0.8s
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.12, 0.32, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.12, 0.32, curve: Curves.easeOut)),
    );

    // Tagline: 0.5s -> 1.0s
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 0.4, curve: Curves.easeOut)),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 0.4, curve: Curves.easeOut)),
    );

    // Loader: 0.0s -> 2.0s
    _loaderScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.8, curve: Curves.easeInOut)),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const goldAccent = Color(0xFFD4AF37);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF12403C),
              Color(0xFF0F2620),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: CustomPaint(
                        size: const Size(60, 60),
                        painter: _LogoPainter(color: goldAccent),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Title
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _titleSlide,
                    child: Opacity(
                      opacity: _titleOpacity.value,
                      child: Text(
                        'LEGACY',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          letterSpacing: 4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // Tagline
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _taglineSlide,
                    child: Opacity(
                      opacity: _taglineOpacity.value,
                      child: Text(
                        'TIMELESS ELEGANCE',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          letterSpacing: 3,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Loader Line
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Transform(
                    transform: Matrix4.diagonal3Values(_loaderScale.value, 1.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 120,
                      height: 2,
                      color: goldAccent,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;
  _LogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Based on original SVG 80x80 logic mapped to generic size
    final scale = size.width / 80;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;

    // Outer circle (r=38)
    canvas.drawCircle(center, 38 * scale, paint);

    // Inner dashed-like circle (r=32)
    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale;
    canvas.drawCircle(center, 32 * scale, innerPaint);

    // Hands
    final handPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;
    
    // Vertical hand (12 o'clock: 40,40 to 40,20)
    canvas.drawLine(center, Offset(center.dx, center.dy - 20 * scale), handPaint);
    // Horizontal hand (3 o'clock: 40,40 to 55,40)
    canvas.drawLine(center, Offset(center.dx + 15 * scale, center.dy), handPaint);

    // Center dot (r=3)
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3 * scale, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
