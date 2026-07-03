# pShell's own C++ QML modules (Caelestia / Caelestia.Blobs — the URI is kept
# from the caelestia port so QML imports stay stable).
add_subdirectory(pshell)

# Vendored third-party subtrees (self-contained, built as-is):
#   m3shapes  — github.com/soramanew/m3shapes; Material 3 rounded-polygon shapes
#               used by the dashboard (MaterialShape). Installs to
#               ${INSTALL_QMLDIR}/M3Shapes.
#   caelestia — caelestia C++ QML modules (Caelestia.Config/Internal/Services/
#               Components) that the dashboard binds to; ships its own build
#               helpers (rpath'd backing libs under Caelestia/lib/).
add_subdirectory(vendor/m3shapes)
add_subdirectory(vendor/caelestia)
