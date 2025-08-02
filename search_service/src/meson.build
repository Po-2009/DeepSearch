
proto_sources = files(
    'ProtoGenerated/AnswerReceive.pb.cc',
    'ProtoGenerated/AnswerReceive.grpc.pb.cc'
)


executable('search_service',
           sources : proto_sources + ['main.cpp'],
           install : true,
           dependencies : [protobuf_dep, grpc_dep],
)