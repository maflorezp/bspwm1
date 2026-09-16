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

#ifndef BSPWM_EDGE_ZONE_H
#define BSPWM_EDGE_ZONE_H

/* types.h uses size_t without including <stddef.h>. */
#include <stddef.h>
#include "types.h"

/* Snap zone for a pointer at (x, y) on a monitor with rectangle `r`, when the
 * pointer is within `threshold` pixels of one of its edges.
 *
 * With `ratio` 0 the zones are the classic ones: a corner needs the pointer
 * at both edges, the whole top edge maximizes and the bottom edge is no zone.
 *
 * With `ratio` above 0, the part of an edge within `ratio` of its length from
 * a corner gives that quarter. On the top edge a centered band `ratio` of the
 * width wide maximizes and the rest gives the top half; the bottom edge gives
 * the bottom half and the sides the left and right halves.
 *
 * Pure geometry, so the unit tests drive it without a display. */
snap_zone_t edge_zone_at(int x, int y, bspwm_rect_t r, int threshold, double ratio);

/* Rectangle for a window snapped to `zone` in the work area `area`: the
 * position of its outer corner and its inner size, so that with a border of
 * `border` pixels the whole window fills the zone and stays inside the area.
 * Of two halves of an odd length, the second one gets the extra pixel.
 * SNAP_MAXIMIZE fills the area and SNAP_NONE gives an empty rectangle. */
bspwm_rect_t edge_zone_rect(bspwm_rect_t area, snap_zone_t zone, unsigned int border);

#endif
