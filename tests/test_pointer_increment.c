/* Unit tests for pointer_increment.c: stepped moves and resizes while
 * dragging a window with a modifier held. */

#include <stdio.h>
#include "../src/pointer_increment.h"

/* X modifier masks, as they arrive in the state of a motion event. */
#define SHIFT    (1 << 0)
#define LOCK     (1 << 1)
#define CONTROL  (1 << 2)
#define MOD1     (1 << 3)
#define MOD2     (1 << 4)
#define BUTTON1  (1 << 8)

static int failures;

static void check(const char *desc, int expected, int actual)
{
	if (expected == actual) {
		printf("  PASS: %s\n", desc);
		return;
	}
	printf("  FAIL: %s: expected %d, got %d\n", desc, expected, actual);
	failures++;
}

/* The step asked for with the defaults: shift for 10 px, control for 50. */
static int step(unsigned int state, unsigned int ignored)
{
	return pointer_increment_step(state, ignored, SHIFT, 10, CONTROL, 50);
}

int main(void)
{
	/* Which step the held modifiers ask for. */
	check("no modifier held moves freely", 0, step(0, 0));
	check("the increment modifier asks for the increment", 10, step(SHIFT, 0));
	check("the big increment modifier asks for the big increment", 50, step(CONTROL, 0));
	check("with both held the big increment wins", 50, step(SHIFT | CONTROL, 0));
	check("the drag modifier and the button do not get in the way",
	      10, step(MOD1 | BUTTON1 | SHIFT, 0));
	check("a lock modifier that is on does not get in the way",
	      10, step(SHIFT | MOD2, MOD2 | LOCK));
	check("a modifier set to none never asks for a step",
	      0, pointer_increment_step(SHIFT, 0, 0, 10, 0, 50));
	check("a modifier that is a lock never asks for a step",
	      0, pointer_increment_step(MOD2, MOD2, MOD2, 10, 0, 50));

	/* How far the window goes: whole steps from the anchor, to the nearest. */
	check("no distance, no step", 0, pointer_increment_snap(0, 10));
	check("less than half a step stays put", 0, pointer_increment_snap(4, 10));
	check("half a step takes a whole one", 10, pointer_increment_snap(5, 10));
	check("a step and a bit is one step", 10, pointer_increment_snap(14, 10));
	check("a step and a half is two", 20, pointer_increment_snap(15, 10));
	check("less than half a step back stays put", 0, pointer_increment_snap(-4, 10));
	check("half a step back takes a whole one back", -10, pointer_increment_snap(-5, 10));
	check("a step and a half back is two back", -20, pointer_increment_snap(-15, 10));
	check("a step of 0 leaves the distance as it is", 7, pointer_increment_snap(7, 0));
	check("a negative step leaves the distance as it is", -7, pointer_increment_snap(-7, -10));

	return failures ? 1 : 0;
}
