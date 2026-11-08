import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/widgets/premium_card.dart';
import '../../core/providers.dart';
import '../../services/storage_service.dart';

// ──────────────────────────────────────────────
// Constants
// ──────────────────────────────────────────────
const _kStatsKeyFilesManaged = 'st_files_managed';
const _kStatsKeyStorageSaved = 'st_storage_saved';
const _kStatsKeyWhiteboardsCreated = 'st_whiteboards';
const _kStatsKeyCleanupsRun = 'st_cleanups';
const _kStatsKeyRecentActivity = 'st_recent_activity';

class StorageToolkitPage extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const StorageToolkitPage({super.key, required this.onBack});

  @override
  ConsumerState<StorageToolkitPage> createState() => _StorageToolkitPageState();
}

class _StorageFileItem {
  final String path;
  final String name;
  final int size;
  final String extension;

  _StorageFileItem({
    required this.path,
    required this.name,
    required this.size,
    required this.extension,
  });
}

class _RecentActivityEntry {
  final String action;
  final String detail;
  final DateTime timestamp;

  _RecentActivityEntry({
    required this.action,
    required this.detail,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _StorageToolkitPageState extends ConsumerState<StorageToolkitPage>
    with SingleTickerProviderStateMixin {
  // ── State ──
  String? _selectedDirectory;
  bool _isScanning = false;
  String? _scanError;
  bool _showDashboard = true; // Toggle between dashboard and sections

  // Scan results
  final List<_StorageFileItem> _files = [];
  int _totalSize = 0;
  int _totalDirs = 0;

  // Categorized sizes
  int _sizeImages = 0;
  int _sizeVideos = 0;
  int _sizeDocuments = 0;
  int _sizeArchives = 0;
  int _sizeOthers = 0;

  // Duplicates
  final Map<int, List<_StorageFileItem>> _duplicateGroups = {};
  final Set<String> _selectedDuplicatesForDelete = {};

  // Cleanable files
  final List<_StorageFileItem> _cleanableFiles = [];

  // Large file sort
  String _largeFileSort = 'size'; // 'size', 'name', 'date'
  String _largeFileSearch = '';
  final TextEditingController _largeFileSearchCtrl = TextEditingController();

  // Cumulative stats
  int _filesManaged = 0;
  int _storageSaved = 0; // bytes
  int _whiteboardsCreated = 0;
  int _cleanupsRun = 0;
  List<_RecentActivityEntry> _recentActivity = [];

  // Scanning progress animation
  late AnimationController _scanProgressCtrl;
  late Animation<double> _scanProgressAnim;
  int _filesScanned = 0;
  int _estimatedTotal = 1;
  double _scanProgress = 0.0;

  // Active section for scrolling
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scanProgressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scanProgressAnim = CurvedAnimation(
      parent: _scanProgressCtrl,
      curve: Curves.easeInOutCubic,
    );
    _loadStats();
  }

  @override
  void dispose() {
    _scanProgressCtrl.dispose();
    _largeFileSearchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Stats Persistence ──
  void _loadStats() {
    _filesManaged = StorageService.getInt(_kStatsKeyFilesManaged) ?? 0;
    _storageSaved = StorageService.getInt(_kStatsKeyStorageSaved) ?? 0;
    _whiteboardsCreated = StorageService.getInt(_kStatsKeyWhiteboardsCreated) ?? 0;
    _cleanupsRun = StorageService.getInt(_kStatsKeyCleanupsRun) ?? 0;
    _loadRecentActivity();
  }

  void _loadRecentActivity() {
    final raw = StorageService.getString(_kStatsKeyRecentActivity);
    if (raw != null && raw.isNotEmpty) {
      try {
        final lines = raw.split('\n');
        _recentActivity = lines.map((line) {
          final parts = line.split('|||');
          if (parts.length >= 3) {
            return _RecentActivityEntry(
              action: parts[0],
              detail: parts[1],
              timestamp: DateTime.tryParse(parts[2]) ?? DateTime.now(),
            );
          }
          return _RecentActivityEntry(action: parts[0], detail: parts.length > 1 ? parts[1] : '');
        }).toList();
      } catch (_) {}
    }
  }

  Future<void> _addRecentActivity(String action, String detail) async {
    final entry = _RecentActivityEntry(action: action, detail: detail);
    setState(() {
      _recentActivity.insert(0, entry);
      if (_recentActivity.length > 10) {
        _recentActivity = _recentActivity.sublist(0, 10);
      }
    });
    final serialized = _recentActivity
        .map((e) => '${e.action}|||${e.detail}|||${e.timestamp.toIso8601String()}')
        .join('\n');
    await StorageService.setString(_kStatsKeyRecentActivity, serialized);
  }

  Future<void> _incrementFilesManaged(int count) async {
    _filesManaged += count;
    await StorageService.setInt(_kStatsKeyFilesManaged, _filesManaged);
  }

  Future<void> _addStorageSaved(int bytes) async {
    _storageSaved += bytes;
    await StorageService.setInt(_kStatsKeyStorageSaved, _storageSaved);
  }

  Future<void> _incrementCleanupsRun() async {
    _cleanupsRun++;
    await StorageService.setInt(_kStatsKeyCleanupsRun, _cleanupsRun);
  }

  // ── Directory Selection & Scanning ──
  Future<void> _selectDirectory() async {
    try {
      final String? path = await FilePicker.getDirectoryPath();
      if (path != null) {
        setState(() {
          _selectedDirectory = path;
          _scanError = null;
          _showDashboard = true;
        });
        _runScan();
      }
    } catch (e) {
      setState(() => _scanError = 'Failed to choose directory: $e');
    }
  }

  Future<void> _runScan() async {
    final path = _selectedDirectory;
    if (path == null) return;

    setState(() {
      _isScanning = true;
      _scanError = null;
      _files.clear();
      _totalSize = 0;
      _totalDirs = 0;
      _sizeImages = 0;
      _sizeVideos = 0;
      _sizeDocuments = 0;
      _sizeArchives = 0;
      _sizeOthers = 0;
      _duplicateGroups.clear();
      _cleanableFiles.clear();
      _selectedDuplicatesForDelete.clear();
      _filesScanned = 0;
      _estimatedTotal = 1;
      _scanProgress = 0.0;
      _scanProgressCtrl.value = 0.0;
    });

    try {
      final dir = Directory(path);
      if (!await dir.exists()) throw Exception('Directory does not exist');

      // First pass: count total files for progress estimation
      int totalCount = 0;
      try {
        await for (final _ in dir.list(recursive: true, followLinks: false).handleError((_) {})) {
          totalCount++;
        }
      } catch (_) {}
      _estimatedTotal = math.max(totalCount, 1);

      int fileCount = 0;
      final Map<String, List<_StorageFileItem>> duplicateDetectionMap = {};

      await for (final entity in dir.list(recursive: true, followLinks: false).handleError((error) {
        debugPrint('Bypassing inaccessible entry: $error');
      })) {
        if (entity is File) {
          final length = await entity.length();
          final name = entity.path.split(Platform.isWindows ? '\\' : '/').last;
          final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';

          final fileItem = _StorageFileItem(
            path: entity.path,
            name: name,
            size: length,
            extension: ext,
          );

          _files.add(fileItem);
          _totalSize += length;
          fileCount++;

          // Categorize sizes
          if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext)) {
            _sizeImages += length;
          } else if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'mp3', 'wav', 'm4a'].contains(ext)) {
            _sizeVideos += length;
          } else if (['pdf', 'docx', 'xlsx', 'pptx', 'txt', 'csv', 'md'].contains(ext)) {
            _sizeDocuments += length;
          } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
            _sizeArchives += length;
          } else {
            _sizeOthers += length;
          }

          // Duplicate detection (size + name)
          final dupKey = '${length}_$name';
          if (duplicateDetectionMap.containsKey(dupKey)) {
            duplicateDetectionMap[dupKey]!.add(fileItem);
          } else {
            duplicateDetectionMap[dupKey] = [fileItem];
          }

          if (ext == 'tmp' || ext == 'log' || name.startsWith('~') || entity.path.contains('cache')) {
            _cleanableFiles.add(fileItem);
          }

          // Update progress
          fileCount++;
          _filesScanned = fileCount;
          _scanProgress = (fileCount / _estimatedTotal).clamp(0.0, 0.99);
          _scanProgressCtrl.animateTo(_scanProgress, duration: const Duration(milliseconds: 100));

          if (fileCount >= 800) break;
        } else if (entity is Directory) {
          _totalDirs++;
        }
      }

      // Populate duplicates
      int dupIndex = 0;
      duplicateDetectionMap.forEach((key, list) {
        if (list.length > 1) {
          _duplicateGroups[dupIndex++] = list;
        }
      });

      _files.sort((a, b) => b.size.compareTo(a.size));
      await _incrementFilesManaged(_files.length);
      await _addRecentActivity('Scan', 'Scanned ${_formatBytes(_totalSize)} across ${_files.length} files');

    } catch (e) {
      setState(() => _scanError = 'Scan failed: $e');
    } finally {
      setState(() {
        _isScanning = false;
        _scanProgress = 1.0;
        _scanProgressCtrl.animateTo(1.0, duration: const Duration(milliseconds: 300));
      });
    }
  }

  // ── File Operations ──
  void _deleteFile(String path, {VoidCallback? onSuccess}) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        await file.delete();
        await _addStorageSaved(size);
        await _addRecentActivity('Delete', 'Deleted ${path.split(Platform.isWindows ? '\\' : '/').last} (${_formatBytes(size)})');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${_formatBytes(size)}'),
              backgroundColor: FocusOsTheme.of(context).surfaceAlt,
              duration: const Duration(seconds: 1),
            ),
          );
        }
        if (onSuccess != null) onSuccess();
        _runScan();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _deleteSelectedDuplicates() async {
    if (_selectedDuplicatesForDelete.isEmpty) return;
    int totalDeleted = 0;
    int totalSize = 0;
    for (final path in _selectedDuplicatesForDelete) {
      try {
        final f = File(path);
        if (await f.exists()) {
          totalSize += await f.length();
          await f.delete();
          totalDeleted++;
        }
      } catch (_) {}
    }
    await _addStorageSaved(totalSize);
    await _addRecentActivity('Bulk Delete', 'Deleted $totalDeleted duplicate files (${_formatBytes(totalSize)})');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $totalDeleted duplicate files (${_formatBytes(totalSize)})'),
          backgroundColor: FocusOsTheme.of(context).surfaceAlt,
        ),
      );
    }
    _runScan();
  }

  void _keepNewestInGroup(int groupIdx) {
    final group = _duplicateGroups[groupIdx];
    if (group == null || group.length <= 1) return;
    group.sort((a, b) => b.path.compareTo(a.path)); // Rough newest-first
    final toDelete = group.sublist(1);
    for (final f in toDelete) {
      _selectedDuplicatesForDelete.add(f.path);
    }
    setState(() {});
  }

  void _keepOldestInGroup(int groupIdx) {
    final group = _duplicateGroups[groupIdx];
    if (group == null || group.length <= 1) return;
    final toDelete = group.sublist(1);
    for (final f in toDelete) {
      _selectedDuplicatesForDelete.add(f.path);
    }
    setState(() {});
  }

  void _cleanTempFiles() async {
    if (_cleanableFiles.isEmpty) return;
    int cleanedCount = 0;
    int totalSize = 0;
    for (final file in _cleanableFiles) {
      try {
        final f = File(file.path);
        if (await f.exists()) {
          totalSize += await f.length();
          await f.delete();
          cleanedCount++;
        }
      } catch (_) {}
    }
    await _addStorageSaved(totalSize);
    await _incrementCleanupsRun();
    await _addRecentActivity('Cleanup', 'Cleaned $cleanedCount temp/log files (${_formatBytes(totalSize)})');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleaned $cleanedCount files (${_formatBytes(totalSize)})'),
          backgroundColor: FocusOsTheme.of(context).surfaceAlt,
        ),
      );
    }
    _runScan();
  }

  void _simulateEmptyRecycleBin() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Recycle Bin emptied successfully'),
        backgroundColor: FocusOsTheme.of(context).surfaceAlt,
      ),
    );
  }

  void _simulateDeleteLogs() async {
    if (_cleanableFiles.isEmpty) return;
    int deletedLogs = 0;
    int totalSize = 0;
    for (final file in _cleanableFiles.where((f) => f.extension == 'log')) {
      try {
        final f = File(file.path);
        if (await f.exists()) {
          totalSize += await f.length();
          await f.delete();
          deletedLogs++;
        }
      } catch (_) {}
    }
    await _addStorageSaved(totalSize);
    await _addRecentActivity('Delete Logs', 'Deleted $deletedLogs log files (${_formatBytes(totalSize)})');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $deletedLogs log files (${_formatBytes(totalSize)})'),
          backgroundColor: FocusOsTheme.of(context).surfaceAlt,
        ),
      );
    }
    _runScan();
  }

  void _organizeFiles() async {
    final path = _selectedDirectory;
    if (path == null || _files.isEmpty) return;
    int organizedCount = 0;
    try {
      for (final file in _files) {
        final ext = file.extension;
        String folderName = '';
        if (['pdf'].contains(ext)) folderName = 'PDFs';
        else if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) folderName = 'Images';
        else if (['mp4', 'mkv', 'avi', 'mov', 'wmv'].contains(ext)) folderName = 'Videos';
        else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) folderName = 'Archives';
        else if (['docx', 'xlsx', 'pptx', 'txt', 'csv', 'md'].contains(ext)) folderName = 'Documents';
        if (folderName.isNotEmpty) {
          final targetDir = Directory('$path/$folderName');
          if (!await targetDir.exists()) await targetDir.create();
          final sourceFile = File(file.path);
          final targetPath = '${targetDir.path}/${file.name}';
          if (!await File(targetPath).exists()) {
            await sourceFile.rename(targetPath);
            organizedCount++;
          }
        }
      }
      await _addRecentActivity('Organize', 'Organized $organizedCount files into folders');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Organized $organizedCount files'),
            backgroundColor: FocusOsTheme.of(context).surfaceAlt,
          ),
        );
      }
      _runScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error organizing: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _openFileLocation(String path) {
    try {
      final dir = Directory(path).parent;
      if (Platform.isWindows) {
        Process.run('explorer', ['/select,', path]);
      } else if (Platform.isMacOS) {
        Process.run('open', ['-R', path]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [dir.path]);
      }
    } catch (e) {
      debugPrint('Failed to open location: $e');
    }
  }

  // ── Helpers ──
  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (bytes > 0) ? (bytes / 1024.0).floor() : 0;
    final value = bytes / (1 << (i.clamp(0, 4) * 10));
    return '${value.toStringAsFixed(1)} ${suffixes[i.clamp(0, suffixes.length - 1)]}';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final notesCount = ref.watch(stickyNotesProvider).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: motion.PremiumEnterTransition(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.borderSubtle.withValues(alpha: 0.5),
                    ),
                    child: Icon(Icons.arrow_back, size: 16, color: tokens.textPrimary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Storage Toolkit',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                      Text('One-click cleanup, large file manager, duplicate finder',
                          style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
                    ],
                  ),
                ),
                // Action buttons
                if (_selectedDirectory != null && !_isScanning)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _selectDirectory,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: tokens.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text('Rescan', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _showDashboard = !_showDashboard),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Icon(
                            _showDashboard ? Icons.list_rounded : Icons.dashboard_rounded,
                            size: 14,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Error Banner ──
            if (_scanError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_scanError!, style: const TextStyle(color: Colors.redAccent, fontSize: 11))),
                    GestureDetector(
                      onTap: () => setState(() => _scanError = null),
                      child: Icon(Icons.close, size: 14, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),

            // ── Main Body ──
            Expanded(
              child: _selectedDirectory == null
                  ? _buildLandingState(tokens)
                  : _isScanning
                      ? _buildScanningState(tokens)
                      : SingleChildScrollView(
                          controller: _scrollCtrl,
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Directory banner
                                _buildDirectoryBanner(tokens),
                                const SizedBox(height: 16),

                                // Dashboard + Sections
                                if (_showDashboard) _buildDashboardSection(tokens, notesCount),
                                _buildScannerSection(tokens),
                                const SizedBox(height: 16),
                                _buildCleanupSection(tokens),
                                const SizedBox(height: 16),
                                _buildLargeFileSection(tokens),
                                const SizedBox(height: 16),
                                _buildDuplicateSection(tokens),
                                const SizedBox(height: 16),
                                _buildOrganizerSection(tokens),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Landing State ──
  Widget _buildLandingState(ThemeTokens tokens) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dashboard Preview
              _buildDashboardSection(tokens, ref.watch(stickyNotesProvider).length),

              const SizedBox(height: 32),

              // CTA
              GestureDetector(
                onTap: _selectDirectory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tokens.accent, tokens.accentSecondary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Select Folder to Scan',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Scanning State ──
  Widget _buildScanningState(ThemeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: tokens.borderSubtle,
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AnimatedBuilder(
                  animation: _scanProgressAnim,
                  builder: (context, _) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _scanProgressAnim.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [tokens.accent, tokens.accentSecondary],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Percentage text
            AnimatedBuilder(
              animation: _scanProgressAnim,
              builder: (context, _) {
                final pct = (_scanProgressAnim.value * 100).toInt();
                return Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                    fontFamily: 'monospace',
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Stats
            AnimatedBuilder(
              animation: _scanProgressAnim,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildScanStat(tokens, '${_filesScanned.toInt().toString()} files scanned', Icons.description_outlined),
                    Container(width: 1, height: 20, color: tokens.borderSubtle, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    _buildScanStat(tokens, '${_formatBytes(_totalSize)} analyzed', Icons.storage_rounded),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Spinning indicator
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: 10),
            Text('Scanning directories...', style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildScanStat(ThemeTokens tokens, String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: tokens.textMuted),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
      ],
    );
  }

  // ── Directory Banner ──
  Widget _buildDirectoryBanner(ThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_copy_outlined, size: 16, color: tokens.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedDirectory!,
              style: TextStyle(fontSize: 11, color: tokens.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${_files.length} files  ·  ${_formatBytes(_totalSize)}',
              style: TextStyle(fontSize: 9, color: tokens.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // DASHBOARD SECTION
  // ═══════════════════════════════════════════
  Widget _buildDashboardSection(ThemeTokens tokens, int notesCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSectionHeader(
          icon: Icons.dashboard_rounded,
          title: 'Overview',
          subtitle: 'Your productivity dashboard',
        ),
        const SizedBox(height: 14),

        // Metrics grid
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildStatCard(
                  tokens: tokens,
                  icon: Icons.insert_drive_file_rounded,
                  iconColor: const Color(0xFF6366F1),
                  label: 'Total Files Managed',
                  value: '${_filesManaged.toInt()}',
                  subtitle: 'Across all scans',
                ),
                _buildStatCard(
                  tokens: tokens,
                  icon: Icons.cloud_off_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'Storage Saved',
                  value: _formatBytes(_storageSaved),
                  subtitle: 'Cleaned & deleted',
                ),
                _buildStatCard(
                  tokens: tokens,
                  icon: Icons.draw_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  label: 'Whiteboards Created',
                  value: '$_whiteboardsCreated',
                  subtitle: 'Visual notes & sketches',
                ),
                _buildStatCard(
                  tokens: tokens,
                  icon: Icons.sticky_note_2_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'Notes Created',
                  value: '$notesCount',
                  subtitle: 'Sticky notes',
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 14),

        // Recent Activity
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 14, color: tokens.accent),
                  const SizedBox(width: 8),
                  Text('Recent Activity',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                ],
              ),
              const SizedBox(height: 10),
              if (_recentActivity.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No activity yet. Start scanning to track your progress.',
                      style: TextStyle(fontSize: 10.5, color: tokens.textMuted)),
                )
              else
                ...List.generate(_recentActivity.length.clamp(0, 5), (i) {
                  final entry = _recentActivity[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: tokens.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.detail,
                            style: TextStyle(fontSize: 10.5, color: tokens.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _timeAgo(entry.timestamp),
                          style: TextStyle(fontSize: 9, color: tokens.textMuted, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required ThemeTokens tokens,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tokens.textPrimary, fontFamily: 'monospace')),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10.5, color: tokens.textSecondary)),
          Text(subtitle, style: TextStyle(fontSize: 8.5, color: tokens.textMuted)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // SCANNER SECTION
  // ═══════════════════════════════════════════
  Widget _buildScannerSection(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSectionHeader(
          icon: Icons.radar_rounded,
          title: 'Scan Directory',
          subtitle: '${_files.length} files · ${_formatBytes(_totalSize)} · $_totalDirs directories',
        ),
        const SizedBox(height: 14),

        // Scan results mini-view
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category breakdown
              _buildScanCategoryRow(tokens, 'Images', _sizeImages, const Color(0xFF10B981)),
              _buildScanCategoryRow(tokens, 'Audio & Video', _sizeVideos, const Color(0xFF3B82F6)),
              _buildScanCategoryRow(tokens, 'Documents', _sizeDocuments, const Color(0xFFF59E0B)),
              _buildScanCategoryRow(tokens, 'Archives', _sizeArchives, const Color(0xFF8B5CF6)),
              _buildScanCategoryRow(tokens, 'Others', _sizeOthers, const Color(0xFF6B7280)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanCategoryRow(ThemeTokens tokens, String name, int size, Color color) {
    final pct = _totalSize > 0 ? (size / _totalSize) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: TextStyle(fontSize: 11, color: tokens.textSecondary))),
              Text('${_formatBytes(size)} (${(pct * 100).toStringAsFixed(1)}%)',
                  style: TextStyle(fontSize: 10.5, color: tokens.textPrimary, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: tokens.background,
              color: color,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ONE-CLICK CLEANUP SECTION
  // ═══════════════════════════════════════════
  Widget _buildCleanupSection(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSectionHeader(
          icon: Icons.cleaning_services_rounded,
          title: 'One-Click Cleanup',
          subtitle: '${_cleanupsRun} cleanups performed · ${_cleanableFiles.length} temp files found',
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _buildCleanupCard(
                tokens: tokens,
                icon: Icons.delete_sweep_rounded,
                label: 'Delete Temp Files',
                detail: '${_cleanableFiles.length} files',
                color: const Color(0xFFEF4444),
                onTap: _cleanableFiles.isNotEmpty ? _cleanTempFiles : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCleanupCard(
                tokens: tokens,
                icon: Icons.delete_rounded,
                label: 'Empty Recycle Bin',
                detail: 'System recycle bin',
                color: const Color(0xFFF59E0B),
                onTap: _simulateEmptyRecycleBin,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCleanupCard(
                tokens: tokens,
                icon: Icons.article_outlined,
                label: 'Delete Logs',
                detail: '${_cleanableFiles.where((f) => f.extension == 'log').length} log files',
                color: const Color(0xFF3B82F6),
                onTap: _cleanableFiles.isNotEmpty ? _simulateDeleteLogs : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCleanupCard({
    required ThemeTokens tokens,
    required IconData icon,
    required String label,
    required String detail,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
            const SizedBox(height: 2),
            Text(detail, style: TextStyle(fontSize: 10, color: tokens.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // LARGE FILE MANAGER SECTION
  // ═══════════════════════════════════════════
  Widget _buildLargeFileSection(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSectionHeader(
          icon: Icons.pie_chart_rounded,
          title: 'Large File Manager',
          subtitle: 'Find and remove space hogs',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${_files.length} files total',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: tokens.accent)),
          ),
        ),
        const SizedBox(height: 12),

        // Controls
        Row(
          children: [
            // Sort dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_rounded, size: 12, color: tokens.textSecondary),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _largeFileSort,
                      dropdownColor: tokens.surfaceAlt,
                      style: TextStyle(fontSize: 11, color: tokens.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'size', child: Text('Sort by Size', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: 'name', child: Text('Sort by Name', style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (v) => setState(() => _largeFileSort = v ?? 'size'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Search
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 14, color: tokens.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _largeFileSearchCtrl,
                        style: TextStyle(fontSize: 11, color: tokens.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search files...',
                          hintStyle: TextStyle(fontSize: 11, color: tokens.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (v) => setState(() => _largeFileSearch = v.toLowerCase()),
                      ),
                    ),
                    if (_largeFileSearch.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _largeFileSearchCtrl.clear();
                          setState(() => _largeFileSearch = '');
                        },
                        child: Icon(Icons.close, size: 14, color: tokens.textMuted),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // File list
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: _files.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text('No files found. Select a directory to scan.',
                        style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  itemCount: _getLargeFiles().length.clamp(0, 50),
                  separatorBuilder: (_, __) => Divider(height: 1, color: tokens.borderSubtle),
                  itemBuilder: (context, index) {
                    final file = _getLargeFiles()[index];
                    return _buildFileRow(tokens, file);
                  },
                ),
        ),
      ],
    );
  }

  List<_StorageFileItem> _getLargeFiles() {
    var sorted = List<_StorageFileItem>.from(_files);
    if (_largeFileSort == 'name') {
      sorted.sort((a, b) => a.name.compareTo(b.name));
    } else {
      sorted.sort((a, b) => b.size.compareTo(a.size));
    }
    if (_largeFileSearch.isNotEmpty) {
      sorted = sorted.where((f) => f.name.toLowerCase().contains(_largeFileSearch)).toList();
    }
    return sorted;
  }

  Widget _buildFileRow(ThemeTokens tokens, _StorageFileItem file) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 14, color: tokens.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, style: TextStyle(fontSize: 11, color: tokens.textPrimary, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(file.path, style: TextStyle(fontSize: 8, color: tokens.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.background,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_formatBytes(file.size), style: TextStyle(fontSize: 9, color: tokens.textSecondary, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _openFileLocation(file.path),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.folder_open_rounded, size: 12, color: tokens.accent),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _deleteFile(file.path),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.delete_outline, size: 12, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // DUPLICATE FINDER SECTION
  // ═══════════════════════════════════════════
  Widget _buildDuplicateSection(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSectionHeader(
          icon: Icons.file_copy_rounded,
          title: 'Duplicate Finder',
          subtitle: '${_duplicateGroups.length} duplicate groups · ${_selectedDuplicatesForDelete.length} selected for deletion',
          trailing: _duplicateGroups.isNotEmpty
              ? Row(
                  children: [
                    GestureDetector(
                      onTap: _selectedDuplicatesForDelete.isNotEmpty ? _deleteSelectedDuplicates : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _selectedDuplicatesForDelete.isNotEmpty
                              ? Colors.red.withValues(alpha: 0.15)
                              : tokens.borderSubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Delete Selected (${_selectedDuplicatesForDelete.length})',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _selectedDuplicatesForDelete.isNotEmpty ? Colors.redAccent : tokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 12),

        // Action buttons row
        if (_duplicateGroups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                _buildDupAction(tokens, 'Keep Newest', Icons.schedule_rounded, const Color(0xFF10B981), () {
                  for (final key in _duplicateGroups.keys) _keepNewestInGroup(key);
                }),
                const SizedBox(width: 8),
                _buildDupAction(tokens, 'Keep Oldest', Icons.history_rounded, const Color(0xFF3B82F6), () {
                  for (final key in _duplicateGroups.keys) _keepOldestInGroup(key);
                }),
                const SizedBox(width: 8),
                _buildDupAction(tokens, 'Deselect All', Icons.deselect_rounded, tokens.textSecondary, () {
                  setState(() => _selectedDuplicatesForDelete.clear());
                }),
              ],
            ),
          ),

        // Duplicate groups
        Container(
          constraints: const BoxConstraints(maxHeight: 350),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: _duplicateGroups.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 28, color: tokens.textMuted),
                        const SizedBox(height: 8),
                        Text('No duplicate files detected.', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(10),
                  itemCount: _duplicateGroups.length,
                  itemBuilder: (context, groupKey) {
                    final group = _duplicateGroups[groupKey]!;
                    final anySelected = group.any((f) => _selectedDuplicatesForDelete.contains(f.path));
                    final allSelected = group.every((f) => _selectedDuplicatesForDelete.contains(f.path));
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: anySelected ? Colors.red.withValues(alpha: 0.03) : tokens.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: anySelected ? Colors.red.withValues(alpha: 0.15) : tokens.borderSubtle,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group header
                          Row(
                            children: [
                              Icon(Icons.file_copy_rounded, size: 12, color: tokens.accent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(group.first.name,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              Text('${group.length} copies', style: TextStyle(fontSize: 9, color: tokens.accent)),
                              const SizedBox(width: 8),
                              Text(_formatBytes(group.first.size),
                                  style: TextStyle(fontSize: 9, color: tokens.textMuted, fontFamily: 'monospace')),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Quick actions
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _keepNewestInGroup(groupKey),
                                child: Text('Keep Newest', style: TextStyle(fontSize: 8.5, color: const Color(0xFF10B981), fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _keepOldestInGroup(groupKey),
                                child: Text('Keep Oldest', style: TextStyle(fontSize: 8.5, color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                              ),
                              const Spacer(),
                              if (!allSelected)
                                GestureDetector(
                                  onTap: () {
                                    for (final f in group.skip(1)) {
                                      setState(() => _selectedDuplicatesForDelete.add(f.path));
                                    }
                                  },
                                  child: Text('Select Dups', style: TextStyle(fontSize: 8.5, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // File list
                          ...group.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final isSelected = _selectedDuplicatesForDelete.contains(item.path);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  // Selection checkbox
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedDuplicatesForDelete.remove(item.path);
                                        } else {
                                          _selectedDuplicatesForDelete.add(item.path);
                                        }
                                      });
                                    },
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.redAccent : Colors.transparent,
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(
                                          color: isSelected ? Colors.redAccent : tokens.borderMedium,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 10, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  // Path
                                  Expanded(
                                    child: Text(
                                      item.path,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isSelected ? Colors.redAccent : tokens.textSecondary,
                                        fontFamily: 'monospace',
                                        decoration: isSelected ? TextDecoration.lineThrough : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (idx + 1 != group.length) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _deleteFile(item.path),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Icon(Icons.delete_outline, size: 10, color: Colors.redAccent),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDupAction(ThemeTokens tokens, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ORGANIZER SECTION
  // ═══════════════════════════════════════════
  Widget _buildOrganizerSection(ThemeTokens tokens) {
    final organizeCount = _files.where((f) {
      final ext = f.extension;
      return ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mkv', 'zip', 'rar', 'docx', 'xlsx', 'txt'].contains(ext);
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSectionHeader(
          icon: Icons.auto_awesome_motion_rounded,
          title: 'Smart Organizer',
          subtitle: 'Group files into categorized folders by type',
          trailing: organizeCount > 0
              ? GestureDetector(
                  onTap: _organizeFiles,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [tokens.accent, tokens.accentSecondary]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Organize $organizeCount Files',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: tokens.accent),
                  const SizedBox(width: 8),
                  Text('Organization Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                ],
              ),
              const SizedBox(height: 10),
              Text('Files found that can be organized: $organizeCount items',
                  style: TextStyle(fontSize: 10.5, color: tokens.textSecondary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOrganizeRule(tokens, 'PDFs', '.pdf', '📄'),
                    _buildOrganizeRule(tokens, 'Images', '.png, .jpg, .gif, .webp', '🖼️'),
                    _buildOrganizeRule(tokens, 'Videos', '.mp4, .mkv, .avi, .mov', '🎬'),
                    _buildOrganizeRule(tokens, 'Archives', '.zip, .rar, .7z, .tar', '📦'),
                    _buildOrganizeRule(tokens, 'Documents', '.docx, .txt, .csv, .md', '📝'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrganizeRule(ThemeTokens tokens, String folder, String exts, String emoji) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Text('$folder/', style: TextStyle(fontSize: 10.5, color: tokens.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          Text('  ←  ', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
          Text(exts, style: TextStyle(fontSize: 9.5, color: tokens.textSecondary, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
