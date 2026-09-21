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

#ifndef BSPWM_POINTER_INCREMENT_H
#define BSPWM_POINTER_INCREMENT_H

#include <stdint.h>

/* Stepped moves and resizes: while a window is dragged with the pointer,
 * holding a modifier makes it advance in whole steps instead of following
 * the pointer pixel by pixel. The steps count from where the window was
 * when the modifier was pressed, so an odd size stays odd and only the
 * stride is controlled. */

/* The step, in pixels, that the modifiers held in `state` ask for, or 0 when
 * the drag should move freely. The lock modifiers in `ignored` never count.
 * A modifier of 0 is disabled, and when both are held the big step wins. */
int pointer_increment_step(uint16_t state, uint16_t ignored,
                           uint16_t modifier, int increment,
                           uint16_t big_modifier, int big_increment);

/* The distance the pointer has travelled since the anchor, snapped to whole
 * steps, rounding to the nearest one: the window answers once the pointer is
 * half a step away instead of lagging a full step behind. A step of 0 or
 * less leaves the distance as it is. */
int pointer_increment_snap(int travelled, int step);

#endif
