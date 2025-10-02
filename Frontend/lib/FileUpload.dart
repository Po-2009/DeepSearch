import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:path/path.dart' as path;
import 'ProtoGenerated/FileUpload/FileUpload.pbgrpc.dart';

String normalizeQuery(String query) {
  return query
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .join(' ');
}

class FileUploadClient {
  static final FileUploadClient _instance = FileUploadClient._internal();

  late final ClientChannel _channel;
  late final FileServiceClient _stub;

  FileUploadClient._internal();

  factory FileUploadClient() => _instance;

  Future<void> init() async {
    var port = 50054;
    try {
       port = await _getFreePort(50054);
      await _startGoService(port);
    }catch (e){
      if (kDebugMode) {
        print(e);
      }
    }

    _channel = ClientChannel(
      'localhost',
      port: port,
      options: ChannelOptions(
          credentials: const ChannelCredentials.insecure(),
      ),
    );

    _stub = FileServiceClient(_channel);
  }
  Future<void> uploadFiles(List<PlatformFile> selectedFiles) async {
    final controller = StreamController<FileChunk>();
    int i =0;
    unawaited(Future(() async {
      try {
        for (var file in selectedFiles) {
          final fileStream = File(file.path!).openRead();
          const chunkSize = 1024 * 1024; // 1 МБ
          List<int> buffer = [];

          await for (final data in fileStream) {
            buffer.addAll(data);
            while (buffer.length >= chunkSize){
              i++;
              if (kDebugMode) {
                print("${buffer.length}  $i");
              }
              final chunk = buffer.sublist(0, chunkSize);
              controller.add(FileChunk(
                filename: file.path,
                content: chunk,
              ));
              buffer = buffer.sublist(chunkSize);
            }
          }

          if (buffer.isNotEmpty) {
            controller.add(FileChunk(
              filename: file.path,
              content: buffer,
            ));
          }
        }
      } catch (e) {
        controller.addError(e);
      } finally {
        controller.close();
      }
    }));

    try {
      final response = await _stub.uploadFile(controller.stream);
      if (kDebugMode) {
        print("Files uploaded: ${response.message}");
      }
    } on GrpcError catch (e) {
      if (kDebugMode) {
        print("Error uploading files: ${e.message}");
      }
    }
  }
  Future<void> uploadFilesCount(int selectedFilesLength)async{
    final response = await _stub.sendFilesCount(FilesCount(filesCount: selectedFilesLength));
    if (kDebugMode) {
      print("FilesCount uploaded: ${response.message}");
    }
  }

  Future<List<QueryResult>> sendQueries(List<String> queries) async {
    List<String> normalizedQueries = [];
    for(String query in queries){
      normalizedQueries.add(normalizeQuery(query));
    }
    final completer = Completer<List<QueryResult>>();
    final results = <QueryResult>[];
    final controller = StreamController<QueryRequest>();

    final responseStream = _stub.sendQuery(controller.stream);

    responseStream.listen(
            (resp) {
          var res = QueryResult(query: resp.query);
          for (var result in resp.matches) {
            res.matches.add(result);
            if (kDebugMode) {
              print('${resp.query} → ${result.filename} [${result.rank.toStringAsFixed(2)}]');
            }
          }
          results.add(res);
        },
        onDone: () {
          if (kDebugMode) {
            print("Stream is done. Completing with ${results.length} results.");
          }
          completer.complete(results);
        },
        onError: (error) {
          if (kDebugMode) {
            print("Stream error: $error");
          }
          completer.completeError(error);
        },
        cancelOnError: true
    );

    if (kDebugMode) {
      print("Sending ${normalizedQueries.length} queries to the stream...");
    }
    for (final query in normalizedQueries) {
      controller.add(QueryRequest(query: query));
    }
    await controller.close();

    return completer.future;
  }
  Future<void> _startGoService(int port) async {
    final String executableFile = Platform.resolvedExecutable;
    final String macosDir = path.dirname(executableFile);
    final String contentsDir = path.dirname(macosDir);
    final String binaryPath = path.join(contentsDir, 'Resources', 'bin', "FileUpload");

    final process = await Process.start(
      binaryPath,
      ["--port=$port"],
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