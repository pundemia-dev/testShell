# Vendored caelestia C++ QML modules needed by the dashboard:
#   Caelestia.Config     — GlobalConfig / Tokens / Appearance (config C++ system)
#   Caelestia.Internal   — sparkline, visualiser bars, indicator managers, logind
#   Caelestia.Services   — sensors (cpu/gpu/mem/disk), audio/beat/cava, lyrics
#   Caelestia.Components  — lazylistview, wavyline, buttonrow
# Kept as a self-contained subtree with caelestia's own build helpers (its
# qml-module helper installs backing libs to Caelestia/lib/ with rpath so the
# submodules can link to each other — Services → Config + Internal).
#
# Deps: Pipewire, Aubio, libcava, libsensors (see cmake/sensorslib.cmake).

find_package(Qt6 REQUIRED COMPONENTS Core Qml Gui Quick QuickControls2 Concurrent Network DBus)
find_package(PkgConfig REQUIRED)
pkg_check_modules(Pipewire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(Aubio IMPORTED_TARGET aubio REQUIRED)
pkg_check_modules(Cava IMPORTED_TARGET libcava QUIET)
if(NOT Cava_FOUND)
    pkg_check_modules(Cava IMPORTED_TARGET cava REQUIRED)
endif()

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/sensorslib.cmake)

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
qt_standard_project_setup(REQUIRES 6.9)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/pch.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/qml-module.cmake)

# Dependency order: Config + Internal first (Services links against them).
add_subdirectory(src/Caelestia/Config)
add_subdirectory(src/Caelestia/Internal)
add_subdirectory(src/Caelestia/Components)
add_subdirectory(src/Caelestia/Services)
