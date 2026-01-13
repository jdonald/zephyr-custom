/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Hello World Application for Custom ARMv7 Board
 *
 * Demonstrates a simple Zephyr RTOS application running on a custom
 * out-of-tree board definition. This sample showcases:
 * - Basic console output
 * - LED blinking using GPIO
 * - Kconfig-based configuration
 * - Device tree integration
 */

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/sys/printk.h>

/* Get LED0 node from device tree - the user LED on our custom board */
#define LED0_NODE DT_ALIAS(led0)

#if !DT_NODE_HAS_STATUS(LED0_NODE, okay)
#error "LED0 device tree node is not available"
#endif

/* LED GPIO specification from device tree */
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

/* Configurable blink interval from Kconfig */
#if defined(CONFIG_HELLO_BLINK_INTERVAL_MS)
#define BLINK_INTERVAL_MS CONFIG_HELLO_BLINK_INTERVAL_MS
#else
#define BLINK_INTERVAL_MS 1000
#endif

/* Application version string from Kconfig */
#if defined(CONFIG_HELLO_APP_VERSION)
#define APP_VERSION CONFIG_HELLO_APP_VERSION
#else
#define APP_VERSION "1.0.0"
#endif

/* Debug logging control from Kconfig */
#if defined(CONFIG_HELLO_ENABLE_DEBUG_LOG)
#define DEBUG_LOG(fmt, ...) printk("[DEBUG] " fmt "\n", ##__VA_ARGS__)
#else
#define DEBUG_LOG(fmt, ...)
#endif

/**
 * @brief Initialize the LED GPIO
 *
 * @return 0 on success, negative error code otherwise
 */
static int led_init(void)
{
	int ret;

	if (!gpio_is_ready_dt(&led)) {
		printk("Error: LED device %s is not ready\n", led.port->name);
		return -ENODEV;
	}

	ret = gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);
	if (ret < 0) {
		printk("Error %d: failed to configure LED pin\n", ret);
		return ret;
	}

	DEBUG_LOG("LED initialized on %s pin %d", led.port->name, led.pin);
	return 0;
}

/**
 * @brief Print system information
 */
static void print_system_info(void)
{
	printk("\n");
	printk("========================================\n");
	printk("   Custom ARMv7 Board - Hello World\n");
	printk("========================================\n");
	printk("\n");
	printk("Application Version: %s\n", APP_VERSION);
	printk("Zephyr Version: %s\n", KERNEL_VERSION_STRING);
	printk("Board: %s\n", CONFIG_BOARD);
	printk("SoC: %s\n", CONFIG_SOC);
	printk("Blink Interval: %d ms\n", BLINK_INTERVAL_MS);
#if defined(CONFIG_HELLO_ENABLE_DEBUG_LOG)
	printk("Debug Logging: Enabled\n");
#else
	printk("Debug Logging: Disabled\n");
#endif
	printk("\n");
}

/**
 * @brief Main application entry point
 */
int main(void)
{
	int ret;
	int led_state = 0;
	uint32_t count = 0;

	/* Print startup banner */
	print_system_info();

	printk("Hello World from Custom ARMv7 Board!\n");
	printk("This firmware demonstrates an out-of-tree Zephyr project.\n\n");

	/* Initialize LED */
	ret = led_init();
	if (ret < 0) {
		printk("Warning: LED initialization failed, continuing without LED\n");
	}

	/* Main loop - blink LED and print status */
	while (1) {
		if (ret == 0) {
			/* Toggle LED state */
			led_state = !led_state;
			gpio_pin_set_dt(&led, led_state);
		}

		count++;
		printk("Loop iteration %u, LED state: %s\n",
		       count, led_state ? "ON" : "OFF");

		DEBUG_LOG("Sleeping for %d ms", BLINK_INTERVAL_MS);
		k_msleep(BLINK_INTERVAL_MS);
	}

	return 0;
}
