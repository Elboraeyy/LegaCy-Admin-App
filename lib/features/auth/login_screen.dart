import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:admin_app/features/auth/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Staggered Animations
  late AnimationController _animController;
  late Animation<double> _fadeBrand;
  late Animation<Offset> _slideBrand;
  late Animation<double> _fadeDesc;
  late Animation<Offset> _slideDesc;
  late Animation<Offset> _slideForm;

  // Focus nodes to track input focus and animate borders
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // Button press animation
  bool _isButtonPressed = false;
  bool _didLoadSavedCredentials = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Brand Title Animation
    _fadeBrand = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _slideBrand = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );

    // Description Animation
    _fadeDesc = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 0.7, curve: Curves.easeOut)),
    );
    _slideDesc = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic)),
    );

    // Form Animation
    _slideForm = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.4, 1.0, curve: Curves.easeOutExpo)),
    );

    _animController.forward();
    _loadSavedCredentials();

    // Add listeners to trigger rebuilds on focus change
    _emailFocus.addListener(() {
      _fillSavedCredentialsIfEmpty();
      setState(() {});
    });
    _passwordFocus.addListener(() {
      _fillSavedCredentialsIfEmpty();
      setState(() {});
    });
  }

  Future<void> _loadSavedCredentials() async {
    final auth = context.read<AuthProvider>();
    final credentials = await auth.getSavedCredentials();

    if (!mounted) return;

    setState(() {
      _emailController.text = credentials.email ?? '';
      _passwordController.text = credentials.password ?? '';
      _didLoadSavedCredentials = true;
    });
  }

  Future<void> _fillSavedCredentialsIfEmpty() async {
    if (!_didLoadSavedCredentials) return;
    if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final credentials = await auth.getSavedCredentials();
    if (!mounted) return;

    if (_emailController.text.isEmpty && credentials.email != null) {
      _emailController.text = credentials.email!;
    }
    if (_passwordController.text.isEmpty && credentials.password != null) {
      _passwordController.text = credentials.password!;
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }
    
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      HapticFeedback.heavyImpact();
      TextInput.finishAutofillContext(shouldSave: true);
    } else {
      HapticFeedback.vibrate();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // Colors
  static const primaryDark = Color(0xFF12403C);
  static const goldAccent = Color(0xFFD4AF37);
  static const bgSurface = Color(0xFFFCF8F3);
  static const textMutedBrand = Color(0xFFA3B8B0);
  static const textMutedForm = Color(0xFF5C6B66);
  static const borderColor = Color(0xFFD1CFCA);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: primaryDark,
      body: Stack(
        children: [
          // --- Fixed Header Background ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radial Gradient
                Positioned(
                  top: -size.width * 0.5,
                  child: Container(
                    width: size.width * 1.5,
                    height: size.width * 1.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          goldAccent.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
                
                // Content
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: size.height * 0.05),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SlideTransition(
                          position: _slideBrand,
                          child: FadeTransition(
                            opacity: _fadeBrand,
                            child: Text(
                              'Legacy Admin',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 32,
                                height: 1.1,
                                color: goldAccent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SlideTransition(
                          position: _slideDesc,
                          child: FadeTransition(
                            opacity: _fadeDesc,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'Orchestrate excellence. Manage your inventory, orders, and customer relationships from one central command center.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  height: 1.6,
                                  color: textMutedBrand,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- Draggable Bottom Sheet Form ---
          // Using NotificationListener to allow scroll behaviors similar to web
          SlideTransition(
            position: _slideForm,
            child: NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                // Dimiss keyboard if dragged down
                if (notification.extent < notification.initialExtent && keyboardHeight > 0) {
                  FocusScope.of(context).unfocus();
                }
                return true;
              },
              child: DraggableScrollableSheet(
                initialChildSize: keyboardHeight > 0 ? 0.52 : 0.65,
                minChildSize: keyboardHeight > 0 ? 0.45 : 0.65,
                maxChildSize: keyboardHeight > 0 ? 0.85 : 1.0,
                snap: true,
                snapSizes: keyboardHeight > 0 ? const [0.52, 0.72] : const [0.65, 1.0],
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: bgSurface,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: CustomScrollView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              12,
                              24,
                              32 + keyboardHeight,
                            ),
                            child: Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                return AutofillGroup(
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Top Pill Indicator
                                      Center(
                                        child: Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: borderColor,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: keyboardHeight > 0 ? 20 : 40),
                                      
                                      Text(
                                        'Welcome Back',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 24,
                                          color: primaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Enter your credentials to access the dashboard.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          color: textMutedForm,
                                        ),
                                      ),
                                      const SizedBox(height: 40),

                                      // Email Input
                                      _buildLabel('EMAIL ADDRESS'),
                                      const SizedBox(height: 8),
                                      _buildAnimatedTextField(
                                        controller: _emailController,
                                        focusNode: _emailFocus,
                                        hint: 'admin@legecystore.com',
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.email,
                                          AutofillHints.username,
                                        ],
                                        prefixIcon: Icon(
                                          LucideIcons.mail,
                                          size: 18,
                                          color: _emailFocus.hasFocus ? primaryDark : textMutedForm.withValues(alpha: 0.6),
                                        ),
                                        validator: (value) => (value == null || value.isEmpty) ? 'Email is required' : null,
                                      ),
                                      const SizedBox(height: 24),

                                      // Password Input
                                      _buildLabel('PASSWORD'),
                                      const SizedBox(height: 8),
                                      _buildAnimatedTextField(
                                        controller: _passwordController,
                                        focusNode: _passwordFocus,
                                        hint: 'Enter your password',
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [AutofillHints.password],
                                        prefixIcon: Icon(
                                          LucideIcons.lock,
                                          size: 18,
                                          color: _passwordFocus.hasFocus ? primaryDark : textMutedForm.withValues(alpha: 0.6),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye, 
                                            size: 18, 
                                            color: _passwordFocus.hasFocus ? primaryDark : textMutedForm
                                          ),
                                          onPressed: () {
                                            HapticFeedback.selectionClick();
                                            setState(() => _obscurePassword = !_obscurePassword);
                                          },
                                        ),
                                        onFieldSubmitted: (_) => _handleLogin(),
                                        validator: (value) => (value == null || value.isEmpty) ? 'Password is required' : null,
                                      ),
                                      
                                      if (_emailController.text.isNotEmpty || _passwordController.text.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        TextButton.icon(
                                          onPressed: auth.isLoading
                                              ? null
                                              : () {
                                                  HapticFeedback.selectionClick();
                                                  setState(() {
                                                    _emailController.clear();
                                                    _passwordController.clear();
                                                  });
                                                },
                                          icon: const Icon(LucideIcons.rotateCcw, size: 16),
                                          label: const Text('Use another account'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: textMutedForm,
                                            textStyle: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 32),
                                      
                                      // Submit Button with Pressed Animation
                                      GestureDetector(
                                        onTapDown: (_) => setState(() => _isButtonPressed = true),
                                        onTapUp: (_) => setState(() => _isButtonPressed = false),
                                        onTapCancel: () => setState(() => _isButtonPressed = false),
                                        onTap: auth.isLoading ? null : _handleLogin,
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          curve: Curves.easeInOut,
                                          transform: Matrix4.diagonal3Values(_isButtonPressed ? 0.96 : 1.0, _isButtonPressed ? 0.96 : 1.0, 1.0),
                                          transformAlignment: Alignment.center,
                                          width: double.infinity,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: primaryDark,
                                            borderRadius: BorderRadius.circular(999),
                                            boxShadow: _isButtonPressed 
                                              ? [] 
                                              : [
                                                  BoxShadow(
                                                    color: primaryDark.withValues(alpha: 0.3),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 6),
                                                  )
                                                ],
                                          ),
                                          child: Center(
                                            child: auth.isLoading
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                  )
                                                : Text(
                                                    'AUTHENTICATE',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: 1.5,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),

                                      // Error Message
                                      if (auth.errorMessage != null) ...[
                                        const SizedBox(height: 24),
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            border: Border.all(color: const Color(0xFFFCA5A5)),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            auth.errorMessage!,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFFB91C1C),
                                            ),
                                          ),
                                        ),
                                      ],
                                      
                                      SizedBox(height: keyboardHeight > 0 ? 16 : 32),
                                      
                                      // Footer
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(LucideIcons.shieldCheck, size: 14, color: textMutedBrand),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Protected by Legacy Security Systems',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: textMutedBrand,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: primaryDark,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Iterable<String>? autofillHints,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    final isFocused = focusNode.hasFocus;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isFocused 
            ? [BoxShadow(color: primaryDark.withValues(alpha: 0.1), blurRadius: 0, spreadRadius: 4)]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        cursorColor: primaryDark,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: primaryDark,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: textMutedForm.withValues(alpha: 0.5),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(16),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryDark, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFB91C1C)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 1.5),
          ),
        ),
      ),
    );
  }
}
