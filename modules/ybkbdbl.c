// SPDX-License-Identifier: GPL-2.0
/*
 * Minimal keyboard-backlight control for Lenovo Yoga Book YB1-X91F/L.
 *
 * The mainline lenovo-yogabook driver requires both GDIX1001 (touch keyboard)
 * and WCOM0019 (Wacom digitizer) ACPI devices; the X91F has no digitizer, so
 * that driver refuses to probe and never exposes the backlight LED.
 *
 * This module only needs GDIX1001 and drives the backlight through the same
 * ACPI method the vendor driver uses: KBLC(255 - level).
 */
#include <linux/acpi.h>
#include <linux/leds.h>
#include <linux/module.h>

static struct acpi_device *kbd_adev;
static struct led_classdev kbd_bl_led;

static int kbbl_set(struct led_classdev *led, enum led_brightness value)
{
	struct acpi_object_list input;
	union acpi_object param;
	struct acpi_buffer output = { ACPI_ALLOCATE_BUFFER, NULL };
	acpi_status status;

	if (!kbd_adev)
		return -ENODEV;

	param.type = ACPI_TYPE_INTEGER;
	param.integer.value = kbd_bl_led.max_brightness - value;
	input.count = 1;
	input.pointer = &param;

	acpi_device_set_power(kbd_adev, ACPI_STATE_D0);

	status = acpi_evaluate_object(acpi_device_handle(kbd_adev), "KBLC",
				      &input, &output);
	if (ACPI_FAILURE(status)) {
		pr_err("ybkbdbl: KBLC failed: 0x%x\n", status);
		return -EIO;
	}

	kfree(output.pointer);
	return 0;
}

static int __init kbbl_init(void)
{
	int r;

	kbd_adev = acpi_dev_get_first_match_dev("GDIX1001", NULL, -1);
	if (!kbd_adev) {
		pr_err("ybkbdbl: GDIX1001 ACPI device not found\n");
		return -ENODEV;
	}

	kbd_bl_led.name = "ybwmi::kbd_backlight";
	kbd_bl_led.max_brightness = 255;
	kbd_bl_led.brightness_set_blocking = kbbl_set;

	r = led_classdev_register(NULL, &kbd_bl_led);
	if (r) {
		acpi_dev_put(kbd_adev);
		kbd_adev = NULL;
		return r;
	}

	pr_info("ybkbdbl: registered ybwmi::kbd_backlight\n");
	return 0;
}

static void __exit kbbl_exit(void)
{
	led_classdev_unregister(&kbd_bl_led);
	if (kbd_adev)
		acpi_dev_put(kbd_adev);
}

module_init(kbbl_init);
module_exit(kbbl_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Lenovo Yoga Book YB1-X91F keyboard backlight via ACPI KBLC");
