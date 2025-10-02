import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:deep_search/FileUpload.dart';
import 'ProtoGenerated/FileUpload/FileUpload.pbgrpc.dart';
import 'package:provider/provider.dart';
import 'ThemeNotifier.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path/path.dart' as path;

const _primaryColor = Color(0xFF6366F1);
const _secondaryColor = Color(0xFF8B5CF6);
const _accentColor = Color(0xFF06B6D4);
const _successColor = Color(0xFF10B981);
const _warningColor = Color(0xFFF59E0B);
const _errorColor = Color(0xFFEF4444);

final lightColorScheme = ColorScheme.fromSeed(
  seedColor: _primaryColor,
  brightness: Brightness.light,
  primary: _primaryColor,
  secondary: _secondaryColor,
  tertiary: _accentColor,
  surface: const Color(0xFFFAFAFA),
  surfaceContainer: const Color(0xFFF5F5F7),
  surfaceContainerHighest: const Color(0xFFE5E7EB),
);

final darkColorScheme = ColorScheme.fromSeed(
  seedColor: _primaryColor,
  brightness: Brightness.dark,
  primary: _primaryColor,
  secondary: _secondaryColor,
  tertiary: _accentColor,
  surface: const Color(0xFF0F0F23),
  surfaceContainer: const Color(0xFF1A1B3A),
  surfaceContainerHighest: const Color(0xFF2D2E5F),
);

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'DeepSearch',
      theme: _buildTheme(lightColorScheme),
      darkTheme: _buildTheme(darkColorScheme),
      themeMode: themeProvider.themeMode,
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildTheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: 'SF Pro Display', // Modern font
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20.0),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20.0),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceContainer.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        hintStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 16,
        ),
        labelStyle: TextStyle(
          color: colorScheme.primary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
        side: BorderSide.none,
        backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
        labelStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        deleteIconColor: colorScheme.primary.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark
            ? colorScheme.surfaceContainer
            : Colors.white,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final FileUploadClient fileUploadClient = FileUploadClient();
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const int _maxFileSize = 4 * 1024 * 1024 * 1024;

  List<PlatformFile> selectedFiles = [];
  List<String> queries = [];
  List<QueryResult> results = [];
  bool _isSearching = false;
  final _queryController = TextEditingController();
  final _queryFocusNode = FocusNode();

  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    widget.fileUploadClient.init();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String? _getExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < filename.length - 1) {
      return filename.substring(dotIndex + 1).toLowerCase();
    }
    return null;
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx': return Icons.article_rounded;
      case 'txt': case 'md': return Icons.description_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String? extension, ColorScheme colorScheme) {
    switch (extension?.toLowerCase()) {
      case 'pdf': return const Color(0xFFDC2626); // Red
      case 'doc': case 'docx': return const Color(0xFF1D4ED8); // Blue
      case 'txt': case 'md': return const Color(0xFF059669); // Green
      default: return colorScheme.primary;
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true,allowedExtensions: ["pdf","doc","docx","md","txt"],type: FileType.custom);
    if (result == null) return;

    final List<PlatformFile> validFiles = [];
    final List<String> oversizedFileNames = [];

    for (var newFile in result.files) {
      if (selectedFiles.any((existing) => existing.name == newFile.name && existing.size == newFile.size)) {
        continue;
      }

      if (newFile.size > _maxFileSize) {
        oversizedFileNames.add(newFile.name);
      } else {
        validFiles.add(newFile);
      }
    }

    if (validFiles.isNotEmpty) {
      setState(() {
        selectedFiles.addAll(validFiles);
      });
    }

    if (oversizedFileNames.isNotEmpty && mounted) {
      _showModernSnackBar(
        'File size limit exceeded',
        'Files over 4GB: ${oversizedFileNames.join(', ')}',
        _warningColor,
        Icons.warning_rounded,
      );
    }
  }

  void _showModernSnackBar(String title, String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addQuery() {
    if (_queryController.text.trim().isNotEmpty) {
      setState(() {
        queries.add(_queryController.text.trim());
        _queryController.clear();
        _queryFocusNode.requestFocus();
      });
    }
  }

  Future<void> _handleSearch() async {
    if (selectedFiles.isEmpty || queries.isEmpty) {
      _showModernSnackBar(
        selectedFiles.isEmpty ? 'No files selected' : 'No queries added',
        selectedFiles.isEmpty ? 'Please select files to search' : 'Add search queries to continue',
        _warningColor,
        Icons.info_outline_rounded,
      );
      return;
    }

    setState(() {
      _isSearching = true;
      results.clear();
    });
    FocusScope.of(context).unfocus();

    try {
      results.clear();
      await widget.fileUploadClient.uploadFilesCount(selectedFiles.length);
      await widget.fileUploadClient.uploadFiles(selectedFiles);
      final searchResults = await widget.fileUploadClient.sendQueries(queries);
      setState(() {
        results = searchResults;
      });
      final resCount = results.fold(0, (sum, r) => sum + r.matches.length);
      _showModernSnackBar(
        'Search completed!',
        'Found $resCount matches',
        _successColor,
        Icons.check_circle_rounded,
      );
    } catch (e) {
      if (mounted) {
        _showModernSnackBar(
          'Search failed',
          'Error: $e',
          _errorColor,
          Icons.error_outline_rounded,
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Widget _buildModernFileChip(PlatformFile file) {
    final theme = Theme.of(context);
    final ext = _getExtension(file.name);
    final fileColor = _getFileColor(ext, theme.colorScheme);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fileColor.withValues(alpha: 0.1),
            fileColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: fileColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: fileColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getFileIcon(ext),
                size: 20,
                color: fileColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    file.path!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _isSearching ? null : () => setState(() => selectedFiles.remove(file)),
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFiles() {
    if (selectedFiles.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Files',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${selectedFiles.length} files ready to search',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...selectedFiles.map((file) => _buildModernFileChip(file)),
        ],
      ),
    );
  }

  Widget _buildQueryInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.05),
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentColor, _secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Search Queries',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _queryController,
                focusNode: _queryFocusNode,
                decoration: InputDecoration(
                  labelText: 'What are you looking for?',
                  hintText: 'Type your search query here...',
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      onPressed: _isSearching ? null : _addQuery,
                    ),
                  ),
                ),
                onFieldSubmitted: _isSearching ? null : (_) => _addQuery(),
                enabled: !_isSearching,
              ),
              if (queries.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12.0,
                  runSpacing: 12.0,
                  children: queries.map((q) =>
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _primaryColor.withValues(alpha: 0.1),
                              _secondaryColor.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: _primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              q,
                              style: TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!_isSearching) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => setState(() => queries.remove(q)),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: _primaryColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                  ).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(FileMatch match, BuildContext context) {
    final theme = Theme.of(context);
    final rankPercent = (match.rank * 100);
    final ext = _getExtension(match.filename);
    final fileColor = _getFileColor(ext, theme.colorScheme);

    Color progressColor;
    if (rankPercent >= 80) {
      progressColor = _successColor;
    } else if (rankPercent >= 60) {
      progressColor = _warningColor;
    } else if (rankPercent >= 40) {
      progressColor = _accentColor;
    } else {
      progressColor = theme.colorScheme.outline;
    }

    return Card(
      child: InkWell(
        onTap: () => OpenFile.open(match.filename),
        borderRadius: BorderRadius.circular(24.0),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                fileColor.withValues(alpha: 0.05),
                progressColor.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: progressColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: fileColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _getFileIcon(ext),
                      size: 24,
                      color: fileColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          path.basename(match.filename),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${rankPercent.toStringAsFixed(0)}% Match',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: progressColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: match.rank,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [progressColor, progressColor.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResultsSlivers() {
    final theme = Theme.of(context);
    const horizontalPadding = EdgeInsets.symmetric(horizontal: 20.0);

    if (_isSearching && results.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryColor, _secondaryColor],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Searching your files...',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This may take a moment',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (results.isEmpty && !_isSearching) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: horizontalPadding,
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _primaryColor.withValues(alpha: 0.1),
                            _secondaryColor.withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.travel_explore_rounded,
                        size: 60,
                        color: _primaryColor.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Ready to search!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Upload files and add search queries to get started',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }

    List<Widget> slivers = [];
    for (int i = 0; i < results.length; i++) {
      final queryResult = results[i];

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: horizontalPadding.copyWith(top: 32.0, bottom: 20.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _primaryColor.withValues(alpha: 0.08),
                    _accentColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _primaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_primaryColor, _accentColor],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Query ${i + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '"${queryResult.query}"',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _successColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${queryResult.matches.length} matches',
                          style: TextStyle(
                            color: _successColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (queryResult.matches.isEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search_off_rounded,
                        size: 30,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No matches found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search terms',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: horizontalPadding,
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: queryResult.matches.length,
              itemBuilder: (context, index) => _buildResultCard(queryResult.matches[index], context),
            ),
          ),
        );
      }
    }
    return slivers;
  }

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
    required List<Color> gradientColors,
    bool isLoading = false,
    bool isPrimary = true,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        )
            : LinearGradient(
          colors: [
            theme.colorScheme.outline.withValues(alpha: 0.3),
            theme.colorScheme.outline.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: onPressed != null
            ? [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/DeepSearch.png',
              height: 100,
            ),

            const SizedBox(width: 4),

            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [_primaryColor, _secondaryColor],
              ).createShader(bounds),
              child: const Text(
                'DeepSearch',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              final newMode = themeProvider.themeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;

              themeProvider.setThemeMode(newMode);
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _buildGradientButton(
                      text: 'Select Files',
                      icon: Icons.cloud_upload_rounded,
                      onPressed: _isSearching ? null : _pickFiles,
                      gradientColors: [_accentColor, _secondaryColor],
                      isPrimary: false,
                    ),
                    _buildSelectedFiles(),
                    _buildQueryInput(),
                    const SizedBox(height: 32),
                    _buildGradientButton(
                      text: _isSearching ? 'Searching...' : 'Start Search',
                      icon: Icons.travel_explore_rounded,
                      onPressed: (_isSearching || selectedFiles.isEmpty || queries.isEmpty)
                          ? null
                          : _handleSearch,
                      gradientColors: [_primaryColor, _secondaryColor],
                      isLoading: _isSearching,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            ..._buildResultsSlivers(),
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }
}