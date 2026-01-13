# SPDX-License-Identifier: Apache-2.0

# CMake configuration for custom_armv7_board

# Use the standard ARM Cortex-M runner configuration
board_runner_args(jlink "--device=STM32F407VG" "--speed=4000")
board_runner_args(openocd --target-handle=_CHIPNAME.cpu)
board_runner_args(stm32cubeprogrammer "--port=swd" "--reset-mode=hw")

# Include common STM32 OpenOCD configuration
include(${ZEPHYR_BASE}/boards/common/openocd.board.cmake)
include(${ZEPHYR_BASE}/boards/common/jlink.board.cmake)
include(${ZEPHYR_BASE}/boards/common/stm32cubeprogrammer.board.cmake)
