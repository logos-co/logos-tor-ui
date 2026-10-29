cmake_minimum_required(VERSION 3.14)
project(TorUiPlugin LANGUAGES CXX)

if(DEFINED ENV{LOGOS_MODULE_BUILDER_ROOT})
    include($ENV{LOGOS_MODULE_BUILDER_ROOT}/cmake/LogosModule.cmake)
else()
    message(FATAL_ERROR "LogosModule.cmake not found. Set LOGOS_MODULE_BUILDER_ROOT.")
endif()

logos_module(
    NAME tor_ui
    REP_FILE src/TorBackend.rep
    SOURCES
        src/TorBackend.h
        src/TorBackend.cpp
    INCLUDE_DIRS
        src
)
