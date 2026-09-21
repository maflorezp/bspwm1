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
#include "pointer_increment.h"

/* A modifier counts only when every bit of it is held. */
static bool held(uint16_t state, uint16_t modifier)
{
	return modifier != 0 && (state & modifier) == modifier;
}

int pointer_increment_step(uint16_t state, uint16_t ignored,
                           uint16_t modifier, int increment,
                           uint16_t big_modifier, int big_increment)
{
	/* A lock that is on is not the user asking for anything, and a
	 * modifier that is itself a lock (mod2 is usually Num Lock) would
	 * otherwise be held for as long as the light is on. */
	state &= (uint16_t) ~ignored;
	if (held(state, (uint16_t) (big_modifier & ~ignored)))
		return big_increment;
	if (held(state, (uint16_t) (modifier & ~ignored)))
		return increment;
	return 0;
}

int pointer_increment_snap(int travelled, int step)
{
	if (step <= 0)
		return travelled;
	int half = step / 2;
	if (travelled >= 0)
		return (travelled + half) / step * step;
	return -((-travelled + half) / step * step);
}
