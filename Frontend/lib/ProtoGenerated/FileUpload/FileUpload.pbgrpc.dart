//
//  Generated code. Do not modify.
//  source: FileUpload.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'FileUpload.pb.dart' as $0;

export 'FileUpload.pb.dart';

@$pb.GrpcServiceName('FileUpload.FileService')
class FileServiceClient extends $grpc.Client {
  static final _$uploadFile = $grpc.ClientMethod<$0.FileChunk, $0.UploadResponse>(
      '/FileUpload.FileService/UploadFile',
      ($0.FileChunk value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.UploadResponse.fromBuffer(value));
  static final _$sendFilesCount = $grpc.ClientMethod<$0.FilesCount, $0.UploadResponse>(
      '/FileUpload.FileService/SendFilesCount',
      ($0.FilesCount value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.UploadResponse.fromBuffer(value));
  static final _$sendQuery = $grpc.ClientMethod<$0.QueryRequest, $0.QueryResult>(
      '/FileUpload.FileService/SendQuery',
      ($0.QueryRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.QueryResult.fromBuffer(value));

  FileServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.UploadResponse> uploadFile($async.Stream<$0.FileChunk> request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$uploadFile, request, options: options).single;
  }

  $grpc.ResponseFuture<$0.UploadResponse> sendFilesCount($0.FilesCount request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$sendFilesCount, request, options: options);
  }

  $grpc.ResponseStream<$0.QueryResult> sendQuery($async.Stream<$0.QueryRequest> request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$sendQuery, request, options: options);
  }
}

@$pb.GrpcServiceName('FileUpload.FileService')
abstract class FileServiceBase extends $grpc.Service {
  $core.String get $name => 'FileUpload.FileService';

  FileServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.FileChunk, $0.UploadResponse>(
        'UploadFile',
        uploadFile,
        true,
        false,
        ($core.List<$core.int> value) => $0.FileChunk.fromBuffer(value),
        ($0.UploadResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.FilesCount, $0.UploadResponse>(
        'SendFilesCount',
        sendFilesCount_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.FilesCount.fromBuffer(value),
        ($0.UploadResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.QueryRequest, $0.QueryResult>(
        'SendQuery',
        sendQuery,
        true,
        true,
        ($core.List<$core.int> value) => $0.QueryRequest.fromBuffer(value),
        ($0.QueryResult value) => value.writeToBuffer()));
  }

  $async.Future<$0.UploadResponse> sendFilesCount_Pre($grpc.ServiceCall $call, $async.Future<$0.FilesCount> $request) async {
    return sendFilesCount($call, await $request);
  }

  $async.Future<$0.UploadResponse> uploadFile($grpc.ServiceCall call, $async.Stream<$0.FileChunk> request);
  $async.Future<$0.UploadResponse> sendFilesCount($grpc.ServiceCall call, $0.FilesCount request);
  $async.Stream<$0.QueryResult> sendQuery($grpc.ServiceCall call, $async.Stream<$0.QueryRequest> request);
}
