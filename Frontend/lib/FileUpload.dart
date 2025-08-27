import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:grpc/grpc.dart';
import 'package:path/path.dart' as path;
import 'ProtoGenerated/FileUpload/FileUpload.pbgrpc.dart';

class FileUploadClient {
  static final FileUploadClient _instance = FileUploadClient._internal();

  late final ClientChannel _channel;
  late final FileServiceClient _stub;

  FileUploadClient._internal();

  factory FileUploadClient() => _instance;

  Future<void> init() async {
    var port = 0;
    try {
       port = await _getFreePort(50054);
      await _startGoService(port);
    }catch (e){
      print(e);
    }

    _channel = ClientChannel(
      'localhost',
      port: port,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    _stub = FileServiceClient(_channel);
  }
  Future<void> uploadFiles(List<PlatformFile> selectedFiles) async {
    final controller = StreamController<FileChunk>();

    // Запускаем асинхронную операцию в отдельном потоке
    unawaited(Future(() async {
      try {
        for (var file in selectedFiles) {
          // Чтение файла по частям
          final fileStream = File(file.path!).openRead();
          const chunkSize = 1024 * 1024; // 1 МБ
          List<int> buffer = [];

          await for (final data in fileStream) {
            buffer.addAll(data);
            while (buffer.length >= chunkSize) {
              final chunk = buffer.sublist(0, chunkSize);
              controller.add(FileChunk(
                filename: file.name,
                content: chunk,
              ));
              buffer = buffer.sublist(chunkSize);
            }
          }

          // Отправляем оставшиеся данные
          if (buffer.isNotEmpty) {
            controller.add(FileChunk(
              filename: file.name,
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
      print("Files uploaded: ${response.message}");
    } on GrpcError catch (e) {
      print("Error uploading files: ${e.message}");
    }
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
    final executableFile= Platform.resolvedExecutable;

    final String executableDir = path.dirname(executableFile);

    final binaryPath = path.join(executableDir, 'file_upload');
    print(binaryPath);

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