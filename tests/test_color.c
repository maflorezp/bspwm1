/* Unit tests for color.c: premultiplied ARGB for translucent windows. */

#include <inttypes.h>
#include <stdio.h>
#include "../src/color.h"

static int failures;

static void check(const char *desc, uint32_t expected, uint32_t actual)
{
	if (expected == actual) {
		printf("  PASS: %s\n", desc);
		return;
	}
	printf("  FAIL: %s: expected 0x%08" PRIX32 ", got 0x%08" PRIX32 "\n",
	       desc, expected, actual);
	failures++;
}

int main(void)
{
	check("full opacity keeps the color and sets alpha",
	      0xFFE6007A, color_premultiply(0xE6007A, 100));
	check("zero opacity is transparent black",
	      0x00000000, color_premultiply(0xE6007A, 0));
	check("25% opacity scales every channel",
	      0x3F38001E, color_premultiply(0xE6007A, 25));
	check("50% green",
	      0x7F007F00, color_premultiply(0x00FF00, 50));
	check("opacity above 100 counts as 100",
	      0xFFE6007A, color_premultiply(0xE6007A, 250));
	check("the high byte of the input is ignored",
	      0x7F007F00, color_premultiply(0xFF00FF00, 50));
	return failures ? 1 : 0;
}
