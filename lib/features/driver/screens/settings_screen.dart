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
import '../../../core/localization/app_localizations.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _locationAlwaysOn = true;
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
      _soundEnabled = prefs.getBool('driver_sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('driver_vibration_enabled') ?? true;
      _locationAlwaysOn = prefs.getBool('driver_location_always_on') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
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
      }
    } else {
      _showPermissionDialog();
    }
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.locationAlways.status;
    if (!status.isGranted) {
      final loc = AppLocalizations.of(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(loc.locationPermissionRequiredTitle),
          content: Text(loc.locationPermissionRequiredDriver),
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
    final loc = AppLocalizations.of(context);
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
        Text(loc.appDescriptionDriver),
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
        title: Text(AppLocalizations.of(context).settings),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
                padding: const EdgeInsets.all(16),
      children: [
          Builder(
            builder: (context) {
              final loc = AppLocalizations.of(context);
              return Column(
                children: [
                  // Notifications Section
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
                                ? loc.receiveOrderNotifications
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
                              _saveSetting('driver_sound_enabled', value);
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
                              _saveSetting('driver_vibration_enabled', value);
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
                  const SizedBox(height: 24),
                  // Location Section (Important for Drivers)
                  _buildSectionHeader(loc.location),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(loc.locationPermission),
                          subtitle: Text(loc.locationPermissionSubtitle),
                          trailing: ElevatedButton(
                            onPressed: _checkLocationPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(loc.check),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // App Section
                  _buildSectionHeader(loc.app),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: Text(loc.aboutApp),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _showAboutDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.policy_outlined),
                          title: Text(loc.privacyPolicy),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => context.push('/driver/privacy-policy'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(loc.termsAndConditions),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => context.push('/driver/terms-conditions'),
                        ),
                        const Divider(height: 1),
                        LanguageSwitcherTile(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Version Info
                  Center(
                    child: Text(
                      loc.version('1.0.0'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
