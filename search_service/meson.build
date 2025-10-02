project('search_service', 'cpp',
        version : '1.0.0',
        default_options : ['warning_level=3', 'cpp_std=c++23','default_library=static', 'prefer_static=true']
)

protobuf_dep = dependency('protobuf', method: 'pkg-config',static: true)
grpc_dep = dependency('grpc++', method: 'pkg-config',static: true)
gtest_dep = dependency('gtest',method: 'pkg-config', static: true)

inc_src = include_directories('src')

subdir('src')
subdir('tests')