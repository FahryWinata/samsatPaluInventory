// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import '../utils/app_colors.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import '../services/backup_service.dart';
import '../services/inventory_service.dart';
import '../services/asset_service.dart';
import '../services/user_service.dart';
import '../services/locale_service.dart';
import '../services/migration_service.dart';
import '../utils/extensions.dart';
import '../utils/snackbar_helper.dart';
import '../providers/auth_provider.dart';
import '../widgets/category_management_dialog.dart';
import '../utils/performance_logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final backupService = BackupService();
  final inventoryService = InventoryService();
  final assetService = AssetService();
  final userService = UserService();

  bool notificationsEnabled = true;
  bool autoBackupEnabled = false;
  String databaseSize = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _loadDatabaseSize();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? false;
      });
    }
  }

  Future<void> _loadDatabaseSize() async {
    final size = await backupService.getDatabaseSize();
    if (mounted) {
      setState(() => databaseSize = size);
    }
  }

  Future<void> _importLegacyDatabase() async {
    // Show file picker
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
      dialogTitle: context.t('select_legacy_db'),
    );

    if (!mounted) return;
    if (result == null) return;

    final dbPath = result.files.single.path;
    if (dbPath == null) return;

    // Confirm import
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('import_legacy_db')),
        content: Text(context.t('import_confirm_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('confirm')),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(context.t('importing_data')),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final migrationService = MigrationService();
      await migrationService.migrateFromSQLite(dbPath);

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        showDialog(
          context: context,
          builder: (successContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                SizedBox(width: 12),
                Text('Success'),
              ],
            ),
            content: const Text(
              'Legacy data imported successfully to Supabase!',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(successContext).pop();
                  _loadDatabaseSize();
                },
                child: Text(context.t('ok')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        SnackBarHelper.showError(context, 'Import failed: $e');
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppColors.error),
            const SizedBox(width: 12),
            Text(context.t('clear_all_data')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('clear_data_message')),
            const SizedBox(height: 16),
            Text(
              context.t('type_delete_to_confirm'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (confirmController.text == 'DELETE') {
                Navigator.of(context).pop(true);
              } else {
                SnackBarHelper.showError(
                  context,
                  'incorrect_confirmation_text',
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.t('delete_all')),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(context.t('loading')),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await backupService.clearAllData();

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        SnackBarHelper.showSuccess(context, context.t('data_cleared'));
      }

      _loadDatabaseSize();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        SnackBarHelper.showError(context, '${context.t('error')}: $e');
      }
    }
  }

  void _showLanguageDialog() {
    final localeService = Provider.of<LocaleService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('English'),
              subtitle: Text(context.t('english_us')),
              value: 'en',
              groupValue: localeService.locale.languageCode,
              activeColor: AppColors.primary,
              onChanged: (value) {
                if (value != null) {
                  // FIX: Defer state update/navigation to avoid '!_debugDuringDeviceUpdate' assertion
                  // caused by removing a widget while it's processing a mouse event.
                  Future.microtask(() {
                    localeService.setLocale(Locale(value));
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      SnackBarHelper.showSuccess(
                        context,
                        context.t('language_changed_en'),
                      );
                    }
                  });
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Bahasa Indonesia'),
              subtitle: Text(context.t('indonesian')),
              value: 'id',
              groupValue: localeService.locale.languageCode,
              activeColor: AppColors.primary,
              onChanged: (value) {
                if (value != null) {
                  // FIX: Defer state update/navigation to avoid '!_debugDuringDeviceUpdate' assertion
                  Future.microtask(() {
                    localeService.setLocale(Locale(value));
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      SnackBarHelper.showSuccess(
                        context,
                        context.t('language_changed_id'),
                      );
                    }
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.t('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Inventarisku',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.inventory_2, color: Colors.white, size: 32),
      ),
      children: [
        const SizedBox(height: 16),
        Text(context.t('app_description')),
        const SizedBox(height: 16),
        Text(context.t('app_features')),
        const SizedBox(height: 16),
        Text(
          context.t('copyright'),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  void _showPerformanceReport() {
    final perf = PerformanceLogger();
    final logs = perf.logs;

    // Also print to console
    perf.printReport();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.speed, color: Colors.orange),
            SizedBox(width: 12),
            Text('Performance Report'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: logs.isEmpty
              ? const Center(
                  child: Text(
                    'No performance logs recorded yet.\n\nNavigate through the app to collect metrics.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[logs.length - 1 - index]; // Newest first
                    final durationMs = log.duration.inMilliseconds;
                    final color = durationMs < 500
                        ? Colors.green
                        : (durationMs < 2000 ? Colors.orange : Colors.red);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.2),
                          child: Text(
                            '${durationMs}ms',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                        title: Text(
                          log.operationName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (log.details != null)
                              Text(
                                log.details!,
                                style: const TextStyle(fontSize: 10),
                              ),
                            Text(
                              'Started: ${log.startTime.hour}:${log.startTime.minute.toString().padLeft(2, '0')}:${log.startTime.second.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: log.details != null,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              perf.clearLogs();
              Navigator.of(dialogContext).pop();
              SnackBarHelper.showSuccess(context, 'Logs cleared');
            },
            child: const Text('Clear Logs'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeService = Provider.of<LocaleService>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(context.t('settings'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('settings'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t('manage_preferences'),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // General Settings
            SettingsSection(
              title: context.t('general'),
              children: [
                SettingsTile(
                  icon: Icons.notifications,
                  title: context.t('notifications'),
                  subtitle: context.t('enable_alerts'),
                  trailing: Switch(
                    value: notificationsEnabled,
                    onChanged: (value) async {
                      setState(() => notificationsEnabled = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('notifications_enabled', value);
                    },
                    activeTrackColor: AppColors.primary,
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.language,
                  title: context.t('language'),
                  subtitle: localeService.getLanguageName(
                    localeService.locale.languageCode,
                  ),
                  onTap: _showLanguageDialog,
                ),
              ],
            ),

            // Database Management
            SettingsSection(
              title: context.t('database'),
              children: [
                SettingsTile(
                  icon: Icons.storage,
                  title: context.t('database_size'),
                  subtitle: databaseSize,
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadDatabaseSize,
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.upload_file,
                  title: context.t('import_legacy_db'),
                  subtitle: context.t('import_legacy_desc'),
                  iconColor: AppColors.primary,
                  onTap: _importLegacyDatabase,
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.auto_awesome,
                  title: context.t('auto_backup'),
                  subtitle: context.t('auto_backup_weekly'),
                  trailing: Switch(
                    value: autoBackupEnabled,
                    onChanged: (value) async {
                      final enabledMsg = context.t('auto_backup_enabled_msg');
                      final disabledMsg = context.t('auto_backup_disabled_msg');

                      setState(() => autoBackupEnabled = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('auto_backup_enabled', value);

                      if (value) {
                        await backupService.performAutoBackupIfNeeded();
                      }

                      if (context.mounted) {
                        SnackBarHelper.showInfo(
                          context,
                          value ? enabledMsg : disabledMsg,
                        );
                      }
                    },
                    activeTrackColor: AppColors.primary,
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.delete_forever,
                  title: context.t('clear_all_data'),
                  subtitle: context.t('delete_all_data'),
                  iconColor: AppColors.error,
                  onTap: _clearAllData,
                ),
              ],
            ),

            // Master Data
            SettingsSection(
              title: 'Master Data',
              children: [
                SettingsTile(
                  icon: Icons.category,
                  title: 'Kelola Kategori',
                  subtitle: 'Tambah, edit, hapus kategori aset',
                  iconColor: AppColors.primary,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const CategoryManagementDialog(),
                    );
                  },
                ),
              ],
            ),

            // System Information
            SettingsSection(
              title: context.t('system'),
              children: [
                SettingsTile(
                  icon: Icons.info,
                  title: context.t('about'),
                  subtitle: '${context.t('version')} 1.0.0',
                  onTap: _showAboutDialog,
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.description,
                  title: context.t('privacy_policy'),
                  onTap: () {
                    SnackBarHelper.showInfo(
                      context,
                      context.t('privacy_policy_coming_soon'),
                    );
                  },
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.gavel,
                  title: context.t('terms_of_service'),
                  onTap: () {
                    SnackBarHelper.showInfo(
                      context,
                      context.t('terms_of_service_coming_soon'),
                    );
                  },
                ),
              ],
            ),

            // Developer Tools
            SettingsSection(
              title: 'Developer Tools',
              children: [
                SettingsTile(
                  icon: Icons.speed,
                  title: 'Performance Report',
                  subtitle: 'View loading time metrics',
                  iconColor: Colors.orange,
                  onTap: _showPerformanceReport,
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.delete_sweep,
                  title: 'Clear Performance Logs',
                  subtitle: 'Reset all collected metrics',
                  iconColor: Colors.grey,
                  onTap: () {
                    PerformanceLogger().clearLogs();
                    SnackBarHelper.showSuccess(
                      context,
                      'Performance logs cleared',
                    );
                  },
                ),
              ],
            ),

            // Account Section
            SettingsSection(
              title: 'Akun',
              children: [
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => SettingsTile(
                    icon: Icons.person,
                    title: 'Pengguna Saat Ini',
                    subtitle: auth.currentUser ?? 'Tidak diketahui',
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.logout,
                  title: 'Keluar',
                  subtitle: 'Keluar dari akun',
                  iconColor: AppColors.error,
                  onTap: () => _showLogoutDialog(),
                ),
              ],
            ),

            // Build Info
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.inventory_2,
                        color: AppColors.primary,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Inventarisku',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.t('version')} 1.0.0',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.t('built_with_flutter')} ${Platform.version.split('"')[1]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
