# SPDX-License-Identifier: Apache-2.0

# compiler_cache.cmake - CMake module for ccache and reclient integration
#
# This module provides helper functions and configuration for:
# - ccache (local compilation caching)
# - reclient (Google's remote execution client for distributed builds)

#[=======================================================================[.rst:
CompilerCache
-------------

This module configures compiler caching and remote execution for the build.

Cache Backends:
  * ccache - Local compilation cache (fast incremental rebuilds)
  * reclient - Remote execution via RE API (distributed compilation)

Usage::

  # Enable ccache
  cmake -DUSE_CCACHE=ON ..

  # Enable reclient
  cmake -DUSE_RECLIENT=ON -DRECLIENT_CFG=/path/to/config ..

  # Both (reclient for remote, ccache as local fallback)
  cmake -DUSE_CCACHE=ON -DUSE_RECLIENT=ON ..

#]=======================================================================]

# Function to configure ccache with optimal settings
function(configure_ccache)
    find_program(CCACHE_PROGRAM ccache)
    if(NOT CCACHE_PROGRAM)
        message(WARNING "ccache not found in PATH")
        return()
    endif()

    # Get ccache version for compatibility
    execute_process(
        COMMAND ${CCACHE_PROGRAM} --version
        OUTPUT_VARIABLE CCACHE_VERSION_OUTPUT
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    string(REGEX MATCH "[0-9]+\\.[0-9]+\\.?[0-9]*" CCACHE_VERSION "${CCACHE_VERSION_OUTPUT}")
    message(STATUS "ccache version: ${CCACHE_VERSION}")

    # Set ccache configuration via environment
    set(ENV{CCACHE_SLOPPINESS} "pch_defines,time_macros,include_file_mtime,include_file_ctime")
    set(ENV{CCACHE_MAXSIZE} "5G")
    set(ENV{CCACHE_COMPRESS} "true")
    set(ENV{CCACHE_COMPRESSLEVEL} "6")

    # For Zephyr, we need to handle the compiler wrapper properly
    set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}" PARENT_SCOPE)
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}" PARENT_SCOPE)
endfunction()

# Function to configure reclient
function(configure_reclient)
    set(options "")
    set(oneValueArgs CONFIG_PATH BIN_DIR)
    set(multiValueArgs "")
    cmake_parse_arguments(RECLIENT "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Find rewrapper binary
    if(RECLIENT_BIN_DIR)
        set(REWRAPPER_SEARCH_PATH "${RECLIENT_BIN_DIR}")
    else()
        set(REWRAPPER_SEARCH_PATH "$ENV{RECLIENT_BIN_DIR}" "$ENV{HOME}/reclient")
    endif()

    find_program(REWRAPPER_PROGRAM rewrapper
        HINTS ${REWRAPPER_SEARCH_PATH}
        PATH_SUFFIXES bin
    )

    if(NOT REWRAPPER_PROGRAM)
        message(WARNING "rewrapper not found - reclient disabled")
        return()
    endif()

    message(STATUS "Found rewrapper: ${REWRAPPER_PROGRAM}")

    # Verify reproxy and bootstrap are also available
    get_filename_component(RECLIENT_DIR "${REWRAPPER_PROGRAM}" DIRECTORY)

    find_program(REPROXY_PROGRAM reproxy HINTS "${RECLIENT_DIR}")
    find_program(BOOTSTRAP_PROGRAM bootstrap HINTS "${RECLIENT_DIR}")

    if(REPROXY_PROGRAM)
        message(STATUS "Found reproxy: ${REPROXY_PROGRAM}")
    else()
        message(WARNING "reproxy not found - remote execution may not work")
    endif()

    if(BOOTSTRAP_PROGRAM)
        message(STATUS "Found bootstrap: ${BOOTSTRAP_PROGRAM}")
    else()
        message(WARNING "bootstrap not found - credentials may not work")
    endif()

    # Configure the rewrapper command
    set(REWRAPPER_CMD "${REWRAPPER_PROGRAM}")

    if(RECLIENT_CONFIG_PATH AND EXISTS "${RECLIENT_CONFIG_PATH}")
        set(REWRAPPER_CMD "${REWRAPPER_CMD} --cfg=${RECLIENT_CONFIG_PATH}")
    endif()

    # Set as compiler launcher
    set(CMAKE_C_COMPILER_LAUNCHER "${REWRAPPER_CMD}" PARENT_SCOPE)
    set(CMAKE_CXX_COMPILER_LAUNCHER "${REWRAPPER_CMD}" PARENT_SCOPE)
endfunction()

# Function to print cache status
function(print_cache_status)
    message(STATUS "")
    message(STATUS "=== Compiler Cache Status ===")

    if(CMAKE_C_COMPILER_LAUNCHER)
        message(STATUS "C Compiler Launcher: ${CMAKE_C_COMPILER_LAUNCHER}")
    else()
        message(STATUS "C Compiler Launcher: (none)")
    endif()

    if(CMAKE_CXX_COMPILER_LAUNCHER)
        message(STATUS "CXX Compiler Launcher: ${CMAKE_CXX_COMPILER_LAUNCHER}")
    else()
        message(STATUS "CXX Compiler Launcher: (none)")
    endif()

    message(STATUS "=============================")
    message(STATUS "")
endfunction()
