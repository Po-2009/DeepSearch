import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/FileUpload.dart';
import 'ProtoGenerated/FileUpload/FileUpload.pbgrpc.dart';

const _seedColor = Color(0xFF00639B);

final lightColorScheme = ColorScheme.fromSeed(
  seedColor: _seedColor,
  brightness: Brightness.light,
);

final darkColorScheme = ColorScheme.fromSeed(
  seedColor: _seedColor,
  brightness: Brightness.dark,
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepSearch',
      theme: _buildTheme(lightColorScheme),
      darkTheme: _buildTheme(darkColorScheme),
      themeMode: ThemeMode.system,
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        side: BorderSide.none,
        backgroundColor: colorScheme.secondaryContainer,
        labelStyle: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
        deleteIconColor: colorScheme.onSecondaryContainer,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
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

class _HomeScreenState extends State<HomeScreen> {
  static const int _maxFileSize = 4 * 1024 * 1024;

  List<PlatformFile> selectedFiles = [];
  List<String> queries = [];
  List<QueryResult> results = [];
  bool _isSearching = false;
  final _queryController = TextEditingController();
  final _queryFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.fileUploadClient.init();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
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
      default: return Icons.insert_drive_file_outlined;
    }
  }


  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.orange.shade700,
          content: Text(
            'The following files exceed the 4 MB limit and were not added: ${oversizedFileNames.join(', ')}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(selectedFiles.isEmpty ? 'Please select at least one file.' : 'Please enter at least one search query.'),
          backgroundColor: Colors.orangeAccent,
        ),
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
    } catch (e) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search error: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }


  Widget _buildFileChip(PlatformFile file) {
    final theme = Theme.of(context);
    final ext = _getExtension(file.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getFileIcon(ext), size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(file.name, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          InkWell(
            onTap: _isSearching ? null : () => setState(() => selectedFiles.remove(file)),
            customBorder: const CircleBorder(),
            child: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFiles() {
    if (selectedFiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Selected Files (${selectedFiles.length})', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 350, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 4.5),
          itemCount: selectedFiles.length,
          itemBuilder: (context, index) => _buildFileChip(selectedFiles[index]),
        ),
      ],
    );
  }

  Widget _buildQueryInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        TextFormField(
          controller: _queryController,
          focusNode: _queryFocusNode,
          decoration: InputDecoration(
            labelText: 'Search Query',
            hintText: 'Type here and press + or Enter',
            suffixIcon: IconButton(icon: Icon(Icons.add_circle_rounded, color: Theme.of(context).colorScheme.primary), onPressed: _isSearching ? null : _addQuery),
          ),
          onFieldSubmitted: _isSearching ? null : (_) => _addQuery(),
          enabled: !_isSearching,
        ),
        if (queries.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8.0, runSpacing: 8.0, children: queries.map((q) => Chip(label: Text(q), onDeleted: _isSearching ? null : () => setState(() => queries.remove(q)))).toList()),
        ],
      ],
    );
  }

  Widget _buildResultCard(FileMatch match, BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rankPercent = (match.rank * 100);
    final Color progressColor = rankPercent > 80 ? Colors.green.shade400 : rankPercent > 50 ? Colors.orange.shade400 : colorScheme.primary.withValues(alpha: 0.7);

    return Card(
      child: InkWell(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Viewing: ${match.filename}'), duration: const Duration(seconds: 1))),
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_getFileIcon(_getExtension(match.filename)), size: 22, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(match.filename, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: match.rank, minHeight: 6, backgroundColor: colorScheme.surfaceContainerHighest, color: progressColor)),
                  const SizedBox(height: 6),
                  Text('${rankPercent.toStringAsFixed(0)}% Match', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResultsSlivers() {
    final theme = Theme.of(context);
    const horizontalPadding = EdgeInsets.symmetric(horizontal: 16.0);

    if (_isSearching && results.isEmpty) {
      return [const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))];
    }

    if (results.isEmpty && !_isSearching) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: horizontalPadding,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 20),
                  Text('Results will appear here', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Select files, add queries, and start the search.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    List<Widget> slivers = [];
    for (var queryResult in results) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: horizontalPadding.copyWith(top: 24.0, bottom: 16.0),
            child: Text('Results for: "${queryResult.query}"', style: theme.textTheme.titleLarge),
          ),
        ),
      );

      if (queryResult.matches.isEmpty) {
        slivers.add(SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('No matches for this query.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600))))));
      } else {
        slivers.add(
          SliverPadding(
            padding: horizontalPadding,
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.9),
              itemCount: queryResult.matches.length,
              itemBuilder: (context, index) => _buildResultCard(queryResult.matches[index], context),
            ),
          ),
        );
      }
    }
    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DeepSearch')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondaryContainer, foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer),
                    onPressed: _isSearching ? null : _pickFiles,
                    icon: const Icon(Icons.folder_open_rounded, size: 22),
                    label: const Text('Select Files'),
                  ),
                  _buildSelectedFiles(),
                  _buildQueryInput(),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                onPressed: (_isSearching || selectedFiles.isEmpty || queries.isEmpty) ? null : _handleSearch,
                icon: _isSearching ? Container(width: 22, height: 22, padding: const EdgeInsets.all(2.0), child: CircularProgressIndicator(strokeWidth: 2.5, color: Theme.of(context).colorScheme.onPrimary)) : const Icon(Icons.travel_explore_rounded, size: 22),
                label: const Text('Search'),
              ),
            ),
          ),
          ..._buildResultsSlivers(),
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }
}