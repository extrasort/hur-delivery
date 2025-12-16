import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/utils/responsive_extensions.dart';
import 'responsive_container.dart';
import '../../core/localization/app_localizations.dart';

/// Dialog shown when system is in maintenance mode
class MaintenanceModeDialog {
  static void show(BuildContext context, String userRole) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black.withOpacity(0.85),
          body: Center(
            child: Container(
              margin: context.rp(horizontal: 24, vertical: 24),
              constraints: BoxConstraints(maxWidth: context.rw(450)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(context.rs(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  SizedBox(height: context.rs(32)),
                  Container(
                    width: context.rw(80),
                    height: context.rw(80),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.build,
                      color: Colors.white,
                      size: context.ri(40),
                    ),
                  ),
                  SizedBox(height: context.rs(24)),

                  // Title
                  Builder(
                    builder: (context) {
                      final loc = AppLocalizations.of(context);
                      return Padding(
                        padding: context.rp(horizontal: 24, vertical: 0),
                        child: Column(
                          children: [
                            ResponsiveText(
                              loc.maintenanceTitle,
                              style: TextStyle(
                                fontSize: context.rf(24),
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: context.rs(16)),
                            ResponsiveText(
                              _getMessage(userRole, loc),
                              style: TextStyle(
                                fontSize: context.rf(16),
                                color: AppColors.textSecondary,
                                height: 1.6,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  SizedBox(height: context.rs(28)),

                  // Info box
                  Container(
                    margin: context.rp(horizontal: 24, vertical: 0),
                    padding: context.rp(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(context.rs(12)),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: context.ri(20),
                        ),
                        SizedBox(width: context.rs(12)),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final loc = AppLocalizations.of(context);
                              return ResponsiveText(
                                loc.maintenanceInfo,
                                style: TextStyle(
                                  fontSize: context.rf(14),
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: context.rs(24)),

                  // OK button
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.rs(24),
                      0,
                      context.rs(24),
                      context.rs(24),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: context.rp(horizontal: 0, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.rs(16)),
                          ),
                          elevation: 0,
                        ),
                        child: Builder(
                          builder: (context) {
                            final loc = AppLocalizations.of(context);
                            return ResponsiveText(
                              loc.understood,
                              style: TextStyle(
                                fontSize: context.rf(18),
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _getMessage(String userRole, AppLocalizations loc) {
    switch (userRole) {
      case 'driver':
        return loc.maintenanceMessageDriver;
      case 'merchant':
        return loc.maintenanceMessageMerchant;
      default:
        return loc.maintenanceMessageDefault;
    }
  }
}

/// Banner widget to show at top of screen during maintenance mode
class MaintenanceModeBanner extends StatelessWidget {
  const MaintenanceModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.build,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Builder(
              builder: (context) {
                final loc = AppLocalizations.of(context);
                return Text(
                  loc.maintenanceBanner,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

