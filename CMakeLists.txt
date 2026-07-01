cmake_minimum_required(VERSION 3.19)

project(pShell VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(GNUInstallDirs)

if(NOT DEFINED INSTALL_QMLDIR)
    set(INSTALL_QMLDIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml" CACHE PATH "QML install dir")
endif()

add_compile_options(
    -Wall -Wextra -Wpedantic -Wshadow
    -Wnull-dereference -Wdouble-promotion
    -Woverloaded-virtual -Wredundant-decls
    -Wswitch -Wunreachable-code
)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wunused-lambda-capture)
endif()

find_package(Qt6 REQUIRED COMPONENTS ShaderTools Core Qml Gui Quick Concurrent)

add_subdirectory(plugin)

# Vendored M3Shapes (github.com/soramanew/m3shapes) — Material 3 rounded-polygon
# shapes used by the dashboard (MaterialShape). Self-contained QML module; its
# CMakeLists installs to ${INSTALL_QMLDIR}/M3Shapes.
add_subdirectory(plugin/m3shapes)

# Vendored caelestia C++ QML modules (Config/Internal/Services/Components) that
# the dashboard binds to. Self-contained subtree with its own build helpers.
add_subdirectory(plugin/caelestia)
