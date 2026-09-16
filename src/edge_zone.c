/* Copyright (c) 2012, Bastien Dejean
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdbool.h>
#include "edge_zone.h"

/* The zones as they were before `ratio`: corners only within the threshold of
 * both edges, the whole top edge maximizes, nothing on the bottom edge. */
static snap_zone_t classic_zone(bool at_left, bool at_right, bool at_top, bool at_bottom)
{
	if (at_left && at_top)
		return SNAP_TOP_LEFT;
	if (at_right && at_top)
		return SNAP_TOP_RIGHT;
	if (at_left && at_bottom)
		return SNAP_BOTTOM_LEFT;
	if (at_right && at_bottom)
		return SNAP_BOTTOM_RIGHT;
	if (at_top)
		return SNAP_MAXIMIZE;
	if (at_left)
		return SNAP_LEFT;
	if (at_right)
		return SNAP_RIGHT;
	return SNAP_NONE;
}

snap_zone_t edge_zone_at(int x, int y, bspwm_rect_t r, int threshold, double ratio)
{
	int x1 = r.x, y1 = r.y;
	int x2 = r.x + r.width, y2 = r.y + r.height;
	bool at_left = x <= x1 + threshold;
	bool at_right = x >= x2 - threshold;
	bool at_top = y <= y1 + threshold;
	bool at_bottom = y >= y2 - threshold;

	if (ratio <= 0)
		return classic_zone(at_left, at_right, at_top, at_bottom);
	if (!at_left && !at_right && !at_top && !at_bottom)
		return SNAP_NONE;

	/* The stretch of each edge that counts as a corner. The classic corner
	 * square still counts, however small the ratio. */
	int corner_w = (int) (ratio * r.width);
	int corner_h = (int) (ratio * r.height);
	bool near_left = at_left || x < x1 + corner_w;
	bool near_right = at_right || x >= x2 - corner_w;
	bool near_top = at_top || y < y1 + corner_h;
	bool near_bottom = at_bottom || y >= y2 - corner_h;

	if ((at_top && near_left) || (at_left && near_top))
		return SNAP_TOP_LEFT;
	if ((at_top && near_right) || (at_right && near_top))
		return SNAP_TOP_RIGHT;
	if ((at_bottom && near_left) || (at_left && near_bottom))
		return SNAP_BOTTOM_LEFT;
	if ((at_bottom && near_right) || (at_right && near_bottom))
		return SNAP_BOTTOM_RIGHT;

	if (at_top) {
		int half_band = (int) (ratio * r.width / 2);
		int center = x1 + r.width / 2;
		if (x >= center - half_band && x < center + half_band)
			return SNAP_MAXIMIZE;
		return SNAP_TOP;
	}
	if (at_bottom)
		return SNAP_BOTTOM;
	if (at_left)
		return SNAP_LEFT;
	return SNAP_RIGHT;
}

bspwm_rect_t edge_zone_rect(bspwm_rect_t area, snap_zone_t zone, unsigned int border)
{
	int x = area.x, y = area.y;
	int w = area.width, h = area.height;
	int first_w = w / 2, first_h = h / 2;

	switch (zone) {
		case SNAP_LEFT:
			w = first_w;
			break;
		case SNAP_RIGHT:
			x += first_w;
			w -= first_w;
			break;
		case SNAP_TOP:
			h = first_h;
			break;
		case SNAP_BOTTOM:
			y += first_h;
			h -= first_h;
			break;
		case SNAP_TOP_LEFT:
			w = first_w;
			h = first_h;
			break;
		case SNAP_TOP_RIGHT:
			x += first_w;
			w -= first_w;
			h = first_h;
			break;
		case SNAP_BOTTOM_LEFT:
			w = first_w;
			y += first_h;
			h -= first_h;
			break;
		case SNAP_BOTTOM_RIGHT:
			x += first_w;
			w -= first_w;
			y += first_h;
			h -= first_h;
			break;
		case SNAP_MAXIMIZE:
			break;
		case SNAP_NONE:
			return (bspwm_rect_t) {0, 0, 0, 0};
	}

	int b = 2 * (int) border;
	return (bspwm_rect_t) {
		.x = (int16_t) x,
		.y = (int16_t) y,
		.width = (uint16_t) (w > b ? w - b : 1),
		.height = (uint16_t) (h > b ? h - b : 1),
	};
}
