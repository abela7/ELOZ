import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../../../core/data/history_optimization_models.dart';
import '../../data/services/comprehensive_app_backup_service.dart';
import '../../data/services/history_optimization_service.dart';
import '../../data/services/hive_database_inspector_service.dart';

class ComprehensiveDataBackupScreen extends StatefulWidget {
  const ComprehensiveDataBackupScreen({super.key});

  @override
  State<ComprehensiveDataBackupScreen> createState() =>
      _ComprehensiveDataBackupScreenState();
}

class _ComprehensiveDataBackupScreenState
    extends State<ComprehensiveDataBackupScreen> {
  final ComprehensiveAppBackupService _backupService =
      ComprehensiveAppBackupService();
  final HiveDatabaseInspectorService _hiveInspectorService =
      HiveDatabaseInspectorService();
  final HistoryOptimizationService _historyOptimizationService =
      HistoryOptimizationService.instance;

  bool _isWorking = false;
  String? _status;
  ComprehensiveBackupSummary? _lastSummary;
  bool _lastActionWasImport = false;
  ComprehensiveBackupProgress? _activeProgress;
  ComprehensiveBackupCancellationToken? _cancellationToken;
  late Future<HistoryOptimizationStatus> _historyStatusFuture;

  @override
  void initState() {
    super.initState();
    _historyStatusFuture = _historyOptimizationService.getStatus();
    _historyOptimizationService.refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: isDark
          ? DarkGradient.wrap(child: _buildContent(context))
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Comprehensive Backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOptimizationStatusCard(isDark),
          const SizedBox(height: 12),
          _buildInfoCard(isDark),
          const SizedBox(height: 12),
          _buildActionCard(
            isDark: isDark,
            icon: Icons.ios_share_rounded,
            title: 'Export & Share Backup',
            subtitle:
                'Exports all mini-app data/settings except Finance, then opens share sheet.',
            onTap: _isWorking ? null : _exportAndShare,
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            isDark: isDark,
            icon: Icons.file_upload_rounded,
            title: 'Import Backup',
            subtitle:
                'Restores previously exported backup and replaces current non-Finance data.',
            onTap: _isWorking ? null : _importBackup,
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            isDark: isDark,
            icon: Icons.storage_rounded,
            title: 'Export Full Hive DB (Developer)',
            subtitle:
                'Exports all Hive boxes with inferred columns and sample rows for analysis.',
            onTap: _isWorking ? null : _exportFullHiveDump,
          ),
          if (_isWorking) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(
              minHeight: 3,
              value: _activeProgress?.fraction,
            ),
            const SizedBox(height: 10),
            Text(_status ?? 'Working...'),
            if (_cancellationToken != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _cancelCurrentOperation,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel'),
                ),
              ),
            ],
          ],
          if (_lastSummary != null) ...[
            const SizedBox(height: 18),
            _buildSummaryCard(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildOptimizationStatusCard(bool isDark) {
    return StreamBuilder<HistoryOptimizationStatus>(
      stream: _historyOptimizationService.statusStream,
      builder: (context, snapshot) {
        return FutureBuilder<HistoryOptimizationStatus>(
          future: _historyStatusFuture,
          builder: (context, initialSnapshot) {
            final status = snapshot.data ?? initialSnapshot.data;
            if (status == null) {
              return const SizedBox.shrink();
            }

            final percent = status.overallPercent;
            final paused = status.isPaused;
            final subtitle = status.isComplete
                ? 'History optimization complete.'
                : paused
                ? 'Optimization paused.'
                : 'Optimizing history in background.';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D3139) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Optimizing History',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    minHeight: 3,
                    value: (percent / 100).clamp(0, 1),
                  ),
                  const SizedBox(height: 8),
                  Text('Progress: ${percent.toStringAsFixed(1)}%'),
                  ...status.modules.map(_buildModuleOptimizationLine),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          await _historyOptimizationService.setPaused(!paused);
                          if (!paused) return;
                          await _historyOptimizationService
                              .runSessionBackfill();
                        },
                        icon: Icon(
                          paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        label: Text(paused ? 'Resume' : 'Pause'),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await _historyOptimizationService.runSessionBackfill(
                            maxChunksPerSession: 6,
                          );
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Run Now'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModuleOptimizationLine(ModuleHistoryOptimizationStatus module) {
    final lastIndexed = module.lastIndexedDate;
    final remainingDays = module.remainingDays;
    final lastLabel = lastIndexed == null
        ? 'n/a'
        : '${lastIndexed.year.toString().padLeft(4, '0')}-${lastIndexed.month.toString().padLeft(2, '0')}-${lastIndexed.day.toString().padLeft(2, '0')}';
    final remainingLabel = remainingDays == null
        ? 'n/a'
        : remainingDays <= 0
        ? 'done'
        : '$remainingDays days';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '${module.moduleId}: last indexed $lastLabel, remaining $remainingLabel',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.28)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Included: Tasks, Habits, Sleep, Notification Hub, app settings.',
          ),
          SizedBox(height: 6),
          Text(
            'Excluded: Finance mini-app data/settings (it keeps its own backup flow).',
          ),
          SizedBox(height: 6),
          Text(
            'For reinstall restore: import this first, then restore Finance from its own backup.',
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Card(
      color: isDark ? const Color(0xFF2D3139) : Colors.white,
      child: ListTile(
        enabled: onTap != null,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final summary = _lastSummary!;
    final actionLabel = _lastActionWasImport ? 'Last Import' : 'Last Export';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3139) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Backup time: ${_formatDateTime(summary.backupCreatedAt)}'),
          Text('Hive files: ${summary.hiveFilesCount}'),
          Text('SharedPreferences keys: ${summary.sharedPreferencesCount}'),
          Text('Secure-storage keys: ${summary.secureStorageCount}'),
          Text('Hive payload size: ${_formatBytes(summary.totalHiveBytes)}'),
        ],
      ),
    );
  }

  Future<void> _exportAndShare() async {
    final cancellationToken = ComprehensiveBackupCancellationToken();
    setState(() {
      _isWorking = true;
      _status = 'Creating backup file...';
      _activeProgress = null;
      _cancellationToken = cancellationToken;
    });

    try {
      final result = await _backupService.createShareableBackup(
        onProgress: _handleBackupProgress,
        cancellationToken: cancellationToken,
      );
      if (!mounted) return;

      await Share.shareXFiles([
        XFile(result.file.path),
      ], text: 'Life Manager comprehensive backup (excluding Finance).');

      if (!mounted) return;
      setState(() {
        _lastSummary = result.summary;
        _lastActionWasImport = false;
      });

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup exported (${result.summary.hiveFilesCount} Hive files).',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on ComprehensiveBackupCancelledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export cancelled. No backup changes were saved.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _status = null;
          _activeProgress = null;
          _cancellationToken = null;
        });
      }
    }
  }

  Future<void> _importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select backup file',
      type: FileType.custom,
      allowedExtensions: const ['lmbk', 'backup', 'json'],
    );

    if (!mounted || picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null || path.isEmpty) return;

    final shouldProceed = await _confirmImport();
    if (!mounted || !shouldProceed) return;

    final cancellationToken = ComprehensiveBackupCancellationToken();
    setState(() {
      _isWorking = true;
      _status = 'Importing backup...';
      _activeProgress = null;
      _cancellationToken = cancellationToken;
    });

    try {
      final result = await _backupService.restoreFromFile(
        file: File(path),
        onProgress: _handleBackupProgress,
        cancellationToken: cancellationToken,
      );
      if (!mounted) return;

      setState(() {
        _lastSummary = result.summary;
        _lastActionWasImport = true;
      });

      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import completed. Restart app to refresh all state.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } on ComprehensiveBackupCancelledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import cancelled. Current data was left unchanged.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _status = null;
          _activeProgress = null;
          _cancellationToken = null;
        });
      }
    }
  }

  Future<void> _exportFullHiveDump() async {
    setState(() {
      _isWorking = true;
      _status = 'Building full Hive database dump...';
      _activeProgress = null;
      _cancellationToken = null;
    });

    try {
      final result = await _hiveInspectorService.createShareableDump(
        sampleRowsPerBox: 50,
      );
      if (!mounted) return;

      await Share.shareXFiles([
        XFile(result.file.path),
      ], text: 'Life Manager full Hive database inspector export.');

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hive dump exported (${result.boxCount} boxes, ${result.totalRecords} records).',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hive dump export failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _status = null;
          _activeProgress = null;
          _cancellationToken = null;
        });
      }
    }
  }

  void _handleBackupProgress(ComprehensiveBackupProgress progress) {
    if (!mounted) return;
    setState(() {
      _activeProgress = progress;
      _status = _buildProgressStatus(progress);
    });
  }

  String _buildProgressStatus(ComprehensiveBackupProgress progress) {
    final phase = _phaseLabel(progress.phase);
    if (progress.total > 0) {
      return '$phase ${progress.current}/${progress.total} - ${progress.message}';
    }
    return '$phase - ${progress.message}';
  }

  String _phaseLabel(ComprehensiveBackupPhase phase) {
    switch (phase) {
      case ComprehensiveBackupPhase.scanning:
        return 'Scanning';
      case ComprehensiveBackupPhase.reading:
        return 'Reading';
      case ComprehensiveBackupPhase.encoding:
        return 'Encoding';
      case ComprehensiveBackupPhase.writing:
        return 'Writing';
      case ComprehensiveBackupPhase.finalizing:
        return 'Finalizing';
    }
  }

  void _cancelCurrentOperation() {
    final token = _cancellationToken;
    if (token == null || token.isCancelled) {
      return;
    }
    token.cancel();
    setState(() {
      _status = 'Cancellation requested. Finishing current step...';
    });
  }

  Future<bool> _confirmImport() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
          title: const Text('Import backup?'),
          content: const Text(
            'This will replace all non-Finance app data and settings with data '
            'from the selected backup file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
