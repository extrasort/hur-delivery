import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/utils/responsive_extensions.dart';
import 'responsive_container.dart';
import '../../core/localization/app_localizations.dart';

/// Non-dismissible dialog that forces user to update the app
class UpdateRequiredDialog extends StatelessWidget {
  final String currentVersion;
  final String requiredVersion;

  const UpdateRequiredDialog({
    super.key,
    required this.currentVersion,
    required this.requiredVersion,
  });

  /// Show update required dialog (non-dismissible)
  static Future<void> show(
    BuildContext context,
    String currentVersion,
    String requiredVersion,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateRequiredDialog(
        currentVersion: currentVersion,
        requiredVersion: requiredVersion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.9),
        body: Center(
          child: Container(
            margin: context.rp(horizontal: 24, vertical: 24),
            constraints: BoxConstraints(maxWidth: context.rw(450)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(context.rs(24)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
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
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warning.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.system_update_alt,
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
                            loc.updateRequired,
                            style: TextStyle(
                              fontSize: context.rf(24),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: context.rs(16)),
                          ResponsiveText(
                            loc.mustUpdateApp,
                            style: TextStyle(
                              fontSize: context.rf(16),
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                SizedBox(height: context.rs(20)),

                // Version info
                Container(
                  margin: context.rp(horizontal: 24, vertical: 0),
                  padding: context.rp(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(context.rs(12)),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Builder(
                        builder: (context) {
                          final loc = AppLocalizations.of(context);
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ResponsiveText(
                                    loc.currentVersion,
                                    style: TextStyle(
                                      fontSize: context.rf(14),
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  ResponsiveText(
                                    currentVersion,
                                    style: TextStyle(
                                      fontSize: context.rf(14),
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: context.rs(8)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ResponsiveText(
                                    loc.requiredVersion,
                                    style: TextStyle(
                                      fontSize: context.rf(14),
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  ResponsiveText(
                                    requiredVersion,
                                    style: TextStyle(
                                      fontSize: context.rf(14),
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: context.rs(28)),

                // Update button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.rs(24),
                    0,
                    context.rs(24),
                    context.rs(24),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Open Play Store or App Store
                        final url = Uri.parse('https://hur.delivery'); // Replace with actual store URL
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: Icon(Icons.file_download, size: context.ri(24)),
                      label: Builder(
                        builder: (context) {
                          final loc = AppLocalizations.of(context);
                          return ResponsiveText(
                            loc.updateApp,
                            style: TextStyle(
                              fontSize: context.rf(18),
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: context.rp(horizontal: 0, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rs(16)),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

