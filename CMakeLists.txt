# SPDX-License-Identifier: Apache-2.0

# CMakeLists.txt - Main build configuration for Custom ARMv7 Hello World
#
# Build options:
#   -DUSE_CCACHE=ON        Enable ccache for faster rebuilds
#   -DUSE_RECLIENT=ON      Enable reclient for distributed builds
#   -DRECLIENT_CFG=<path>  Path to reclient config file

cmake_minimum_required(VERSION 3.20.0)

# =============================================================================
# Pre-project Configuration: ccache and reclient
# =============================================================================

# Option to enable ccache
option(USE_CCACHE "Use ccache for faster compilation" OFF)

# Option to enable reclient (Google's remote execution client)
option(USE_RECLIENT "Use reclient for remote execution" OFF)

# Path to reclient configuration
set(RECLIENT_CFG "" CACHE FILEPATH "Path to reclient configuration file")

# Path to reclient binaries (rewrapper, reproxy, bootstrap)
set(RECLIENT_BIN_DIR "" CACHE PATH "Path to reclient binary directory")

# Include our custom compiler wrapper module
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/compiler_cache.cmake OPTIONAL)

# Configure compiler launcher based on options
if(USE_RECLIENT AND USE_CCACHE)
    message(STATUS "Both reclient and ccache enabled - reclient takes precedence for remote builds")
    message(STATUS "Local cache will still be used via ccache inside reclient wrapper")
endif()

if(USE_RECLIENT)
    if(RECLIENT_BIN_DIR AND EXISTS "${RECLIENT_BIN_DIR}/rewrapper")
        set(REWRAPPER_PATH "${RECLIENT_BIN_DIR}/rewrapper")
    else()
        find_program(REWRAPPER_PATH rewrapper)
    endif()

    if(REWRAPPER_PATH)
        message(STATUS "Found rewrapper: ${REWRAPPER_PATH}")

        # Build the rewrapper command with config if provided
        if(RECLIENT_CFG AND EXISTS "${RECLIENT_CFG}")
            set(RECLIENT_WRAPPER "${REWRAPPER_PATH} --cfg=${RECLIENT_CFG}")
            message(STATUS "Using reclient config: ${RECLIENT_CFG}")
        else()
            set(RECLIENT_WRAPPER "${REWRAPPER_PATH}")
            message(STATUS "Using default reclient config")
        endif()

        # Set launcher rules for C and C++ compilers
        set(CMAKE_C_COMPILER_LAUNCHER_RULE "${RECLIENT_WRAPPER}")
        set(CMAKE_CXX_COMPILER_LAUNCHER_RULE "${RECLIENT_WRAPPER}")

        message(STATUS "Reclient enabled for remote compilation")
    else()
        message(WARNING "USE_RECLIENT enabled but rewrapper not found - falling back to local builds")
        set(USE_RECLIENT OFF)
    endif()
endif()

if(USE_CCACHE AND NOT USE_RECLIENT)
    find_program(CCACHE_PROGRAM ccache)
    if(CCACHE_PROGRAM)
        message(STATUS "Found ccache: ${CCACHE_PROGRAM}")
        set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
        set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
        message(STATUS "ccache enabled for local compilation caching")
    else()
        message(WARNING "USE_CCACHE enabled but ccache not found")
    endif()
endif()

# =============================================================================
# Zephyr Project Configuration
# =============================================================================

# Find the Zephyr package - set ZEPHYR_BASE environment variable or use west
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

# Define the project
project(hello_armv7_custom
    VERSION 1.0.0
    DESCRIPTION "Hello World for Custom ARMv7 Board"
    LANGUAGES C CXX ASM
)

# =============================================================================
# Application Sources
# =============================================================================

# Add application source files
target_sources(app PRIVATE
    src/main.c
)

# Include directories
target_include_directories(app PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# =============================================================================
# Build Information
# =============================================================================

# Print build configuration summary
message(STATUS "")
message(STATUS "=== Build Configuration Summary ===")
message(STATUS "Project: ${PROJECT_NAME} v${PROJECT_VERSION}")
message(STATUS "Board: ${BOARD}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Generator: ${CMAKE_GENERATOR}")
message(STATUS "C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "CXX Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "ccache: ${USE_CCACHE}")
message(STATUS "reclient: ${USE_RECLIENT}")
message(STATUS "===================================")
message(STATUS "")
