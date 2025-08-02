
from conan import ConanFile
from conan.tools.meson import MesonToolchain

class ConanApplication(ConanFile):
    package_type = "application"
    settings = "os", "compiler", "build_type", "arch"
    generators = ["MesonToolchain","CMakeDeps", "CMakeToolchain","PkgConfigDeps",
                  "VirtualBuildEnv",
                  "VirtualRunEnv"] # Используем Meson вместо CMake

    def layout(self):
        self.folders.build = "build"
        self.folders.generators = "build"  # Указываем каталог для генераторов



    def requirements(self):
        requirements = self.conan_data.get('requirements', [])
        for requirement in requirements:
            self.requires(requirement)
