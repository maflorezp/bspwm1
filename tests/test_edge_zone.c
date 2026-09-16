/* Unit tests for edge_zone.c: which snap zone a pointer position falls into. */

#include <stddef.h>
#include <stdio.h>
#include "../src/edge_zone.h"

static int failures;

static const char *zone_name(snap_zone_t z)
{
	switch (z) {
		case SNAP_NONE: return "none";
		case SNAP_LEFT: return "left";
		case SNAP_RIGHT: return "right";
		case SNAP_TOP: return "top";
		case SNAP_BOTTOM: return "bottom";
		case SNAP_TOP_LEFT: return "top_left";
		case SNAP_TOP_RIGHT: return "top_right";
		case SNAP_BOTTOM_LEFT: return "bottom_left";
		case SNAP_BOTTOM_RIGHT: return "bottom_right";
		case SNAP_MAXIMIZE: return "maximize";
	}
	return "?";
}

static void check(const char *desc, snap_zone_t expected, snap_zone_t actual)
{
	if (expected == actual) {
		printf("  PASS: %s\n", desc);
		return;
	}
	printf("  FAIL: %s: expected %s, got %s\n", desc, zone_name(expected), zone_name(actual));
	failures++;
}

int main(void)
{
	const bspwm_rect_t wide = {0, 0, 1920, 1080};
	const bspwm_rect_t tall = {3840, 0, 1440, 2560};

	/* Ratio 0.2 on 1920x1080: corners are the first and last 384 px of a
	 * horizontal edge and 216 px of a vertical one; the maximize band is
	 * [768, 1152). */
	check("top edge near the left corner is the top-left quarter",
	      SNAP_TOP_LEFT, edge_zone_at(100, 2, wide, 20, 0.2));
	check("last pixel of the corner segment",
	      SNAP_TOP_LEFT, edge_zone_at(383, 2, wide, 20, 0.2));
	check("first pixel past the corner segment is the top half",
	      SNAP_TOP, edge_zone_at(384, 2, wide, 20, 0.2));
	check("last pixel before the center band is the top half",
	      SNAP_TOP, edge_zone_at(767, 2, wide, 20, 0.2));
	check("first pixel of the center band maximizes",
	      SNAP_MAXIMIZE, edge_zone_at(768, 2, wide, 20, 0.2));
	check("the middle of the top edge maximizes",
	      SNAP_MAXIMIZE, edge_zone_at(960, 2, wide, 20, 0.2));
	check("last pixel of the center band maximizes",
	      SNAP_MAXIMIZE, edge_zone_at(1151, 2, wide, 20, 0.2));
	check("first pixel past the center band is the top half",
	      SNAP_TOP, edge_zone_at(1152, 2, wide, 20, 0.2));
	check("top edge near the right corner is the top-right quarter",
	      SNAP_TOP_RIGHT, edge_zone_at(1536, 2, wide, 20, 0.2));
	check("the bottom edge is the bottom half",
	      SNAP_BOTTOM, edge_zone_at(960, 1077, wide, 20, 0.2));
	check("bottom edge near the left corner is the bottom-left quarter",
	      SNAP_BOTTOM_LEFT, edge_zone_at(100, 1077, wide, 20, 0.2));
	check("bottom edge near the right corner is the bottom-right quarter",
	      SNAP_BOTTOM_RIGHT, edge_zone_at(1800, 1077, wide, 20, 0.2));
	check("left edge near the top is the top-left quarter",
	      SNAP_TOP_LEFT, edge_zone_at(2, 100, wide, 20, 0.2));
	check("left edge in the middle is the left half",
	      SNAP_LEFT, edge_zone_at(2, 540, wide, 20, 0.2));
	check("left edge near the bottom is the bottom-left quarter",
	      SNAP_BOTTOM_LEFT, edge_zone_at(2, 1000, wide, 20, 0.2));
	check("right edge in the middle is the right half",
	      SNAP_RIGHT, edge_zone_at(1917, 540, wide, 20, 0.2));
	check("right edge near the top is the top-right quarter",
	      SNAP_TOP_RIGHT, edge_zone_at(1917, 100, wide, 20, 0.2));
	check("the threshold is inclusive",
	      SNAP_MAXIMIZE, edge_zone_at(960, 20, wide, 20, 0.2));
	check("a pixel past the threshold is no zone",
	      SNAP_NONE, edge_zone_at(960, 21, wide, 20, 0.2));
	check("the middle of the monitor is no zone",
	      SNAP_NONE, edge_zone_at(960, 540, wide, 20, 0.2));

	/* A portrait monitor to the right of the first one: corners are 288 px
	 * of the top edge and 512 px of a side; the band is [4416, 4704). */
	check("offset monitor: left edge in the middle",
	      SNAP_LEFT, edge_zone_at(3842, 1280, tall, 20, 0.2));
	check("offset monitor: left edge near the top",
	      SNAP_TOP_LEFT, edge_zone_at(3842, 100, tall, 20, 0.2));
	check("offset monitor: center of the top edge",
	      SNAP_MAXIMIZE, edge_zone_at(4560, 2, tall, 20, 0.2));
	check("offset monitor: top edge near the left corner",
	      SNAP_TOP_LEFT, edge_zone_at(3900, 2, tall, 20, 0.2));

	/* Ratio 0 keeps the classic zones. */
	check("classic: the whole top edge maximizes",
	      SNAP_MAXIMIZE, edge_zone_at(500, 2, wide, 20, 0.0));
	check("classic: the bottom edge is no zone",
	      SNAP_NONE, edge_zone_at(960, 1077, wide, 20, 0.0));
	check("classic: left edge near the top is still the left half",
	      SNAP_LEFT, edge_zone_at(2, 100, wide, 20, 0.0));
	check("classic: a corner needs both edges",
	      SNAP_TOP_LEFT, edge_zone_at(2, 2, wide, 20, 0.0));
	check("classic: bottom-right corner",
	      SNAP_BOTTOM_RIGHT, edge_zone_at(1917, 1077, wide, 20, 0.0));

	return failures ? 1 : 0;
}
