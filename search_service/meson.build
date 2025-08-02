project('search_service', 'cpp',
        version : '1.0.0',
        default_options : ['warning_level=3', 'cpp_std=c++20']
)

protobuf_dep = dependency('protobuf')
grpc_dep = dependency('grpc++')
gtest_dep = dependency('gtest')

inc_src = include_directories('src')

subdir('src')
subdir('tests')