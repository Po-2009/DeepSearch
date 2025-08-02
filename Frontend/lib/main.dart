import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/FileUpload.dart';
import 'package:grpc/grpc.dart';

import 'ProtoGenerated/FileUpload//FileUpload.pbgrpc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Search Client',
      theme: ThemeData(useMaterial3: true),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  HomeScreen();
  final fileUploadClient = FileUploadClient();

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PlatformFile> selectedFiles = [];
  List<String> queries = [];
  List<QueryResult> results = [];


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        selectedFiles.addAll(result.files);
      });
    }
  }


  Future<void> handleSearch() async {
    results.clear();
    await widget.fileUploadClient.init();
    await widget.fileUploadClient.uploadFilesCount(selectedFiles.length);
    await widget.fileUploadClient.uploadFiles(selectedFiles);
    results = await widget.fileUploadClient.sendQueries(queries);
  }

  @override
  Widget build(BuildContext context) {
    final queryController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Search from files')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: pickFiles,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose files'),
            ),
            if (selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Selected: ${selectedFiles.length} files'),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: queryController,
                    decoration: const InputDecoration(labelText: 'Request'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      queries.add(queryController.text);
                      queryController.clear();
                    });
                  },
                ),
              ],
            ),
            if (queries.isNotEmpty)
              Wrap(
                children: queries
                    .map((q) => Chip(label: Text(q)))
                    .toList(),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: handleSearch,
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: results.map((r) => ListTile(title: Text(r.query))).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }
}