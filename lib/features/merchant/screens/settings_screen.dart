import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../shared/widgets/language_switcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/notification_manager.dart';
import '../../../core/localization/app_localizations.dart';

class MerchantSettingsScreen extends StatefulWidget {
  const MerchantSettingsScreen({super.key});

  @override
  State<MerchantSettingsScreen> createState() => _MerchantSettingsScreenState();
}

class _MerchantSettingsScreenState extends State<MerchantSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  PermissionStatus _notificationPermissionStatus = PermissionStatus.granted;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    setState(() {
      _notificationPermissionStatus = status;
      _notificationsEnabled = status.isGranted;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Request permission
      final status = await Permission.notification.request();
      if (status.isGranted) {
        setState(() {
          _notificationsEnabled = true;
          _notificationPermissionStatus = status;
        });
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.notificationsEnabled),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (status.isPermanentlyDenied) {
        _showPermissionDialog();
      } else {
        setState(() {
          _notificationsEnabled = false;
          _notificationPermissionStatus = status;
        });
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.notificationsDenied),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } else {
      // Direct user to settings to disable
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.notificationSettings),
        content: Text(loc.notificationSettingsHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(loc.openSettings),
          ),
        ],
      ),
    );
  }


  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Hur Delivery',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.local_shipping, color: Colors.white, size: 30),
      ),
      children: [
        Text(AppLocalizations.of(context).appDescription),
        const SizedBox(height: 8),
        const Text('© 2025 Hur Delivery. All rights reserved.'),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: ResponsiveText(AppLocalizations.of(context).settings, style: TextStyle(fontSize: context.rf(20))),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: context.ri(20)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: context.rp(horizontal: 16, vertical: 16),
        children: [
          // Notifications Section
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Column(
                children: [
                  _buildSectionHeader(loc.notifications),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Icon(
                            _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                          ),
                          title: Text(loc.instantNotifications),
                          subtitle: Text(
                            _notificationsEnabled
                                ? loc.receiveNotifications
                                : loc.notificationsDisabled,
                          ),
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeColor: AppColors.primary,
                        ),
                        if (_notificationsEnabled) ...[
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.volume_up),
                            title: Text(loc.sound),
                            subtitle: Text(loc.soundSubtitle),
                            value: _soundEnabled,
                            onChanged: (value) {
                              setState(() => _soundEnabled = value);
                              _saveSetting('sound_enabled', value);
                            },
                            activeColor: AppColors.primary,
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.vibration),
                            title: Text(loc.vibration),
                            subtitle: Text(loc.vibrationSubtitle),
                            value: _vibrationEnabled,
                            onChanged: (value) {
                              setState(() => _vibrationEnabled = value);
                              _saveSetting('vibration_enabled', value);
                              if (value) {
                                HapticFeedback.mediumImpact();
                              }
                            },
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: context.rs(24)),
                  // App Section
                  _buildSectionHeader(loc.app),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.info_outline, size: context.ri(24)),
                          title: ResponsiveText(loc.aboutApp, style: TextStyle(fontSize: context.rf(16))),
                          trailing: Icon(Icons.arrow_forward_ios, size: context.ri(16)),
                          onTap: _showAboutDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.policy_outlined, size: context.ri(24)),
                          title: ResponsiveText(loc.privacyPolicy, style: TextStyle(fontSize: context.rf(16))),
                          trailing: Icon(Icons.arrow_forward_ios, size: context.ri(16)),
                          onTap: () => context.push('/merchant-dashboard/privacy-policy'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.description_outlined, size: context.ri(24)),
                          title: ResponsiveText(loc.termsAndConditions, style: TextStyle(fontSize: context.rf(16))),
                          trailing: Icon(Icons.arrow_forward_ios, size: context.ri(16)),
                          onTap: () => context.push('/merchant-dashboard/terms-conditions'),
                        ),
                        const Divider(height: 1),
                        const LanguageSwitcherTile(),
                      ],
                    ),
                  ),
                  SizedBox(height: context.rs(24)),
                  // Version Info
                  Center(
                    child: ResponsiveText(
                      loc.version('1.0.0'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ).responsive(context),
                    ),
                  ),
                  SizedBox(height: context.rs(8)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.rs(8), right: context.rs(4)),
      child: ResponsiveText(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

