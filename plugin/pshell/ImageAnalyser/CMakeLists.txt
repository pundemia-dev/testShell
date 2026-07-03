qml_module(caelestia-imageanalyser
    URI Caelestia
    SOURCES
        imageanalyser.cpp
        cutils.hpp cutils.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
)
