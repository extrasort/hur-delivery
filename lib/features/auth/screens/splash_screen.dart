import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/version_check_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/update_required_dialog.dart';

/// Animated Splash Screen with Bike Image
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _mainController;
  late AnimationController _bikeController;
  late AnimationController _windController;
  late AnimationController _logoController;
  late AnimationController _floatController;
  late AnimationController _tiltController;

  // Animations
  late Animation<double> _bikeEntry;
  late Animation<double> _bikeScale;
  late Animation<double> _windProgress;
  late Animation<double> _logoReveal;
  late Animation<double> _bikeFloat;
  late Animation<double> _bikeTilt;

  // Wind lines
  final List<WindLine> _windLines = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeWindLines();
    _initializeApp();
  }

  void _initializeAnimations() {
    // Main controller (900ms - reduced by 70% from original 3 seconds)
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // Bike entry controller (faster)
    _bikeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Wind controller (continuous)
    _windController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat();

    // Logo reveal controller (faster)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Float controller (continuous smooth floating)
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Tilt controller (continuous smooth tilting)
    _tiltController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Initialize animations
    _bikeEntry = Tween<double>(
      begin: -400.0,
      end: 20.0,
    ).animate(CurvedAnimation(
      parent: _bikeController,
      curve: Curves.easeOutCubic,
    ));

    _bikeScale = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bikeController,
      curve: Curves.easeOutBack,
    ));

    _windProgress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _windController,
      curve: Curves.linear,
    ));

    _logoReveal = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutCubic,
    ));

    _bikeFloat = Tween<double>(
      begin: -8.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));

    _bikeTilt = Tween<double>(
      begin: -0.03,
      end: 0.03,
    ).animate(CurvedAnimation(
      parent: _tiltController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _mainController.forward();
    _bikeController.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _logoController.forward();
      }
    });
  }

  void _initializeWindLines() {
    // Create wind lines concentrated behind the bike (centered area)
    for (int i = 0; i < 40; i++) {
      _windLines.add(WindLine(
        // Y position concentrated around center (behind bike area)
        y: (_random.nextDouble() * 200 - 100) + (_random.nextDouble() * 100 - 50),
        length: _random.nextDouble() * 100 + 50,
        speed: _random.nextDouble() * 3.5 + 2.5,
        thickness: _random.nextDouble() * 3 + 1.5,
        opacity: _random.nextDouble() * 0.6 + 0.3,
      ));
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Check version FIRST before anything else
      final versionService = VersionCheckService();
      final updateRequired = await versionService.isUpdateRequired();

      if (!mounted) return;

      if (updateRequired) {
        // Show update required dialog (non-dismissible)
        final currentVersion = await versionService.getCurrentAppVersion();
        final minVersion = await versionService.getMinimumRequiredVersion() ?? '1.0.0';
        
        if (mounted) {
          await UpdateRequiredDialog.show(context, currentVersion, minVersion);
        }
        return; // Stop here - don't proceed with app initialization
      }

      // Version OK - proceed with normal initialization
      final authProvider = context.read<AuthProvider>();
      await authProvider.initialize();

      // Reduced by 70%: 3 seconds -> 900ms
      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        final user = authProvider.user;
        if (user != null) {
          if (user.verificationStatus != 'approved') {
            context.go('/verification-pending');
          } else {
            // Go directly to dashboard, skip welcome screen
            switch (user.role) {
              case 'merchant':
                context.go('/merchant-dashboard');
                break;
              case 'driver':
                context.go('/driver-dashboard');
                break;
              case 'admin':
                context.go('/admin-dashboard');
                break;
              default:
                context.go('/');
            }
          }
        } else {
          context.go('/');
        }
      } else {
        context.go('/');
      }
    } catch (e) {
      print('Initialization error: $e');
      if (mounted) {
        context.go('/');
      }
    }
  }


  @override
  void dispose() {
    _mainController.dispose();
    _bikeController.dispose();
    _windController.dispose();
    _logoController.dispose();
    _floatController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.9),
              AppColors.primary,
              AppColors.primary.withOpacity(0.95),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -100,
              right: -100,
              child: Opacity(
                opacity: 0.08,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: -150,
              left: -150,
              child: Opacity(
                opacity: 0.08,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),

            // Wind lines behind the bike (layer under the bike)
            Center(
              child: AnimatedBuilder(
                animation: _windController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(600, 400),
                    painter: WindLinesPainter(
                      windLines: _windLines,
                      progress: _windProgress.value,
                    ),
                  );
                },
              ),
            ),

            // Bike image with flowing animations (on top of wind lines)
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _bikeController,
                  _floatController,
                  _tiltController,
                ]),
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_bikeEntry.value, _bikeFloat.value),
                    child: Transform.scale(
                      scale: _bikeScale.value,
                      child: Transform.rotate(
                        angle: _bikeTilt.value,
                        child: Image.asset(
                          'assets/images/bike.png',
                          width: 350,
                          height: 350,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Logo and loading at bottom
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoReveal.value,
                    child: Column(
                      children: [
                        // Loading text
                        Builder(
                          builder: (context) {
                            final loc = AppLocalizations.of(context);
                            return Column(
                              children: [
                                Text(
                                  loc.loading,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Subtitle
                                Text(
                                  loc.fastDeliveryService,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Aesthetic loading indicator with animation
                        SizedBox(
                          width: 220,
                          child: Column(
                            children: [
                              // Animated loading bar
                              Stack(
                                children: [
                                  // Background track
                                  Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Animated progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedBuilder(
                                      animation: _mainController,
                                      builder: (context, child) {
                                        return Container(
                                          height: 8,
                                          width: 220 * _mainController.value,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF60A5FA), // Light blue
                                                Colors.white,
                                                Color(0xFF60A5FA), // Light blue
                                              ],
                                              stops: [0.0, 0.5, 1.0],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withOpacity(0.5),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Loading percentage
                              AnimatedBuilder(
                                animation: _mainController,
                                builder: (context, child) {
                                  return Text(
                                    '${(_mainController.value * 100).toInt()}%',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Wind line data class
class WindLine {
  final double y;
  final double length;
  final double speed;
  final double thickness;
  final double opacity;

  WindLine({
    required this.y,
    required this.length,
    required this.speed,
    required this.thickness,
    required this.opacity,
  });
}

/// Wind lines painter - positioned behind the bike
class WindLinesPainter extends CustomPainter {
  final List<WindLine> windLines;
  final double progress;

  WindLinesPainter({
    required this.windLines,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (var line in windLines) {
      // Calculate position - starting from behind/left of bike, moving left
      final startX = centerX - 100 - ((progress * line.speed * 100) % (size.width / 2 + line.length));
      final endX = startX - line.length;

      // Only draw if in visible area behind the bike
      if (startX > 0 && endX < centerX + 100) {
        paint.strokeWidth = line.thickness;
        paint.shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(line.opacity),
            Colors.white.withOpacity(0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromPoints(
          Offset(startX, centerY + line.y),
          Offset(endX, centerY + line.y),
        ));

        canvas.drawLine(
          Offset(startX, centerY + line.y),
          Offset(endX, centerY + line.y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(WindLinesPainter oldDelegate) => true;
}
