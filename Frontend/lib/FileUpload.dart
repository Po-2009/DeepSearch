import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';

import 'ProtoGenerated/FileUpload//FileUpload.pbgrpc.dart';

class FileUploadClient {
  static final FileUploadClient _instance = FileUploadClient._internal();

  late final ClientChannel _channel;
  late final FileServiceClient _stub;

  FileUploadClient._internal();

  factory FileUploadClient() => _instance;

  Future<void> init() async {
    final port = 50054;//await _getFreePort(50054);
    //await _startGoService(port);

    _channel = ClientChannel(
      'localhost',
      port: port,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    _stub = FileServiceClient(_channel);
  }

  Future<void> uploadFiles(List<PlatformFile> selectedFiles) async {
    final stream = Stream<FileChunk>.fromIterable(
      selectedFiles.map((f) => FileChunk(
        filename: f.name,
        content: f.bytes ?? File(f.path!).readAsBytesSync(),
      )),
    );
    for(var i in selectedFiles){
      print(i.name);
    }
    final response = await _stub.uploadFile(stream);
    print("Files uploaded: ${response.message}");
  }

  Future<void> uploadFilesCount(int selectedFilesLength)async{
    final response = await _stub.sendFilesCount(FilesCount(filesCount: selectedFilesLength));
    print("FilesCount uploaded: ${response.message}");
  }

  Future<List<QueryResult>> sendQueries(List<String> queries) async {
    List<QueryResult> results = [];
    final controller = StreamController<QueryRequest>();

    final responseStream = _stub.sendQuery(controller.stream);
    responseStream.listen((resp) {
      var res = QueryResult(query: resp.query);
      for (var result in resp.matches) {
        res.matches.add(result);
        print('${resp.query} → ${result.filename} [${result.rank.toStringAsFixed(2)}]');
      }
      results.add(res);
    });

    for (final query in queries) {
      controller.add(QueryRequest(query: query));
    }

    await controller.close();
    return results;
  }
  Future<void> _startGoService(int port) async {
    final goBinaryPath = "/Users/poladmagerramli/CLionProjects/DeepSearch/Frontend/lib";

    final process = await Process.start(
      "./file_upload",
      ["--port=$port"],
      workingDirectory: goBinaryPath,
    );

    process.stdout.transform(SystemEncoding().decoder).listen(print);
    process.stderr.transform(SystemEncoding().decoder).listen(print);
  }

  Future<int> _getFreePort(int defaultPort) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }
}