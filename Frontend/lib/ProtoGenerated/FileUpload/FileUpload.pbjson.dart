//
//  Generated code. Do not modify.
//  source: FileUpload.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use fileChunkDescriptor instead')
const FileChunk$json = {
  '1': 'FileChunk',
  '2': [
    {'1': 'filename', '3': 2, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'content', '3': 3, '4': 1, '5': 12, '10': 'content'},
  ],
};

/// Descriptor for `FileChunk`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileChunkDescriptor = $convert.base64Decode(
    'CglGaWxlQ2h1bmsSGgoIZmlsZW5hbWUYAiABKAlSCGZpbGVuYW1lEhgKB2NvbnRlbnQYAyABKA'
    'xSB2NvbnRlbnQ=');

@$core.Deprecated('Use filesCountDescriptor instead')
const FilesCount$json = {
  '1': 'FilesCount',
  '2': [
    {'1': 'filesCount', '3': 2, '4': 1, '5': 5, '10': 'filesCount'},
  ],
};

/// Descriptor for `FilesCount`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List filesCountDescriptor = $convert.base64Decode(
    'CgpGaWxlc0NvdW50Eh4KCmZpbGVzQ291bnQYAiABKAVSCmZpbGVzQ291bnQ=');

@$core.Deprecated('Use uploadResponseDescriptor instead')
const UploadResponse$json = {
  '1': 'UploadResponse',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `UploadResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadResponseDescriptor = $convert.base64Decode(
    'Cg5VcGxvYWRSZXNwb25zZRIYCgdtZXNzYWdlGAEgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use queryRequestDescriptor instead')
const QueryRequest$json = {
  '1': 'QueryRequest',
  '2': [
    {'1': 'query', '3': 2, '4': 1, '5': 9, '10': 'query'},
  ],
};

/// Descriptor for `QueryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queryRequestDescriptor = $convert.base64Decode(
    'CgxRdWVyeVJlcXVlc3QSFAoFcXVlcnkYAiABKAlSBXF1ZXJ5');

@$core.Deprecated('Use queryResultDescriptor instead')
const QueryResult$json = {
  '1': 'QueryResult',
  '2': [
    {'1': 'query', '3': 1, '4': 1, '5': 9, '10': 'query'},
    {'1': 'matches', '3': 2, '4': 3, '5': 11, '6': '.FileUpload.FileMatch', '10': 'matches'},
  ],
};

/// Descriptor for `QueryResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queryResultDescriptor = $convert.base64Decode(
    'CgtRdWVyeVJlc3VsdBIUCgVxdWVyeRgBIAEoCVIFcXVlcnkSLwoHbWF0Y2hlcxgCIAMoCzIVLk'
    'ZpbGVVcGxvYWQuRmlsZU1hdGNoUgdtYXRjaGVz');

@$core.Deprecated('Use fileMatchDescriptor instead')
const FileMatch$json = {
  '1': 'FileMatch',
  '2': [
    {'1': 'filename', '3': 1, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'rank', '3': 2, '4': 1, '5': 2, '10': 'rank'},
  ],
};

/// Descriptor for `FileMatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileMatchDescriptor = $convert.base64Decode(
    'CglGaWxlTWF0Y2gSGgoIZmlsZW5hbWUYASABKAlSCGZpbGVuYW1lEhIKBHJhbmsYAiABKAJSBH'
    'Jhbms=');

