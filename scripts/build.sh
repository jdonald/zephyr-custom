#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

# build.sh - Build script for Custom ARMv7 Hello World
#
# Usage:
#   ./scripts/build.sh [options]
#
# Options:
#   --ccache         Enable ccache for local caching
#   --reclient       Enable reclient for remote builds
#   --reclient-cfg   Path to reclient config file
#   --clean          Clean build directory before building
#   --verbose        Enable verbose output
#   --pristine       Pristine build (removes entire build directory)
#   --help           Show this help message

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Default values
BUILD_DIR="${PROJECT_DIR}/build"
BOARD="custom_armv7_board"
USE_CCACHE="OFF"
USE_RECLIENT="OFF"
RECLIENT_CFG=""
CLEAN_BUILD=false
PRISTINE_BUILD=false
VERBOSE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ccache)
            USE_CCACHE="ON"
            shift
            ;;
        --reclient)
            USE_RECLIENT="ON"
            shift
            ;;
        --reclient-cfg)
            RECLIENT_CFG="$2"
            shift 2
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --pristine)
            PRISTINE_BUILD=true
            shift
            ;;
        --verbose|-v)
            VERBOSE="--verbose"
            shift
            ;;
        --help|-h)
            head -25 "$0" | tail -20
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Print configuration
echo "========================================"
echo "  Custom ARMv7 Board Build Script"
echo "========================================"
echo ""
echo "Project directory: ${PROJECT_DIR}"
echo "Build directory:   ${BUILD_DIR}"
echo "Board:             ${BOARD}"
echo "ccache:            ${USE_CCACHE}"
echo "reclient:          ${USE_RECLIENT}"
if [[ -n "${RECLIENT_CFG}" ]]; then
    echo "reclient config:   ${RECLIENT_CFG}"
fi
echo ""

# Check for Zephyr environment
if [[ -z "${ZEPHYR_BASE}" ]]; then
    echo "Error: ZEPHYR_BASE environment variable not set"
    echo "Please source the Zephyr environment:"
    echo "  source <zephyr-workspace>/zephyr/zephyr-env.sh"
    exit 1
fi

echo "ZEPHYR_BASE: ${ZEPHYR_BASE}"
echo ""

# Handle clean/pristine builds
if [[ "${PRISTINE_BUILD}" == true ]]; then
    echo "Removing build directory..."
    rm -rf "${BUILD_DIR}"
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

# Prepare CMake arguments
CMAKE_ARGS=(
    "-GNinja"
    "-DBOARD=${BOARD}"
    "-DBOARD_ROOT=${PROJECT_DIR}"
    "-DUSE_CCACHE=${USE_CCACHE}"
    "-DUSE_RECLIENT=${USE_RECLIENT}"
)

if [[ -n "${RECLIENT_CFG}" ]]; then
    CMAKE_ARGS+=("-DRECLIENT_CFG=${RECLIENT_CFG}")
fi

# Configure
echo "Configuring build..."
cd "${BUILD_DIR}"
cmake "${CMAKE_ARGS[@]}" "${PROJECT_DIR}"

# Build
echo ""
echo "Building..."
if [[ "${CLEAN_BUILD}" == true ]]; then
    ninja clean
fi

ninja ${VERBOSE}

# Print build results
echo ""
echo "========================================"
echo "  Build Complete!"
echo "========================================"
echo ""
echo "Firmware binary: ${BUILD_DIR}/zephyr/zephyr.bin"
echo "ELF file:        ${BUILD_DIR}/zephyr/zephyr.elf"
echo "HEX file:        ${BUILD_DIR}/zephyr/zephyr.hex"
echo ""

# Print firmware size
if command -v arm-zephyr-eabi-size &> /dev/null; then
    echo "Firmware size:"
    arm-zephyr-eabi-size "${BUILD_DIR}/zephyr/zephyr.elf"
elif command -v arm-none-eabi-size &> /dev/null; then
    echo "Firmware size:"
    arm-none-eabi-size "${BUILD_DIR}/zephyr/zephyr.elf"
fi
