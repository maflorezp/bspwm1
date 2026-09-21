# Stepped moves and resizes: holding a modifier during a pointer drag makes the
# window advance in whole steps, counted from where it was when the modifier
# went down, instead of following the pointer pixel by pixel.

echo ""
echo "== Pointer increments =="

assert_ok "pointer increment unit tests pass" ./test_pointer_increment

assert_eq "the increment is 10 px by default" "10" "$($BSPC config pointer_increment 2>/dev/null)"
assert_eq "the big increment is 50 px by default" "50" "$($BSPC config pointer_big_increment 2>/dev/null)"
assert_eq "shift asks for the increment by default" "shift" \
	"$($BSPC config pointer_increment_modifier 2>/dev/null)"
assert_eq "control asks for the big increment by default" "control" \
	"$($BSPC config pointer_big_increment_modifier 2>/dev/null)"

assert_ok "set the increment" $BSPC config pointer_increment 5
assert_eq "the increment was set" "5" "$($BSPC config pointer_increment 2>/dev/null)"
assert_fail "reject an increment of 0" $BSPC config pointer_increment 0
assert_fail "reject a negative increment" $BSPC config pointer_increment -5
assert_fail "reject an increment that is not a number" $BSPC config pointer_increment ten
assert_ok "set the big increment" $BSPC config pointer_big_increment 25
assert_eq "the big increment was set" "25" "$($BSPC config pointer_big_increment 2>/dev/null)"
assert_fail "reject a big increment of 0" $BSPC config pointer_big_increment 0

assert_ok "turn the increment modifier off" $BSPC config pointer_increment_modifier none
assert_eq "an increment modifier that is off reads back as none" "none" \
	"$($BSPC config pointer_increment_modifier 2>/dev/null)"
assert_ok "set the big increment modifier" $BSPC config pointer_big_increment_modifier mod5
assert_eq "the big increment modifier was set" "mod5" \
	"$($BSPC config pointer_big_increment_modifier 2>/dev/null)"
assert_fail "reject an unknown modifier" $BSPC config pointer_increment_modifier hyper
assert_fail "none is still not a valid drag modifier" $BSPC config pointer_modifier none

$BSPC config pointer_increment 10
$BSPC config pointer_big_increment 50
$BSPC config pointer_increment_modifier shift
$BSPC config pointer_big_increment_modifier control

# Where a window is, relative to where it started: "dx dy dwidth dheight".
moved_since() {
	set -- $1 $(win_geom "$2")
	echo "$(($5 - $1)) $(($6 - $2)) $(($7 - $3)) $(($8 - $4))"
}

if drag_tools_available; then
	drag_setup
	$BSPC config edge_snap_enabled false
	$BSPC config magnet_threshold 0

	# Free first, then stepped from wherever the window was: 3 px free, and
	# the steps count from there, so it never lands on a round number.
	A=$(spawn_floating steps-move 400x300+300+300)
	START=$(win_geom "$A")
	drag_begin 1 500 450
	drag_to 503 450
	assert_eq "the window follows the pointer before the modifier" "3 0 0 0" "$(moved_since "$START" "$A")"
	xdotool keydown shift
	drag_to 507 450
	assert_eq "less than half a step after the modifier leaves it in place" "3 0 0 0" "$(moved_since "$START" "$A")"
	drag_to 517 450
	assert_eq "a step and a bit moves it one step" "13 0 0 0" "$(moved_since "$START" "$A")"
	drag_to 521 457
	assert_eq "both axes are stepped" "23 10 0 0" "$(moved_since "$START" "$A")"
	xdotool keyup shift
	drag_to 524 457
	assert_eq "without the modifier it follows the pointer again" "26 10 0 0" "$(moved_since "$START" "$A")"
	drag_end 1
	$BSPC node "$A" -c
	sleep 0.3

	# The big step wins over the small one, and every change of modifier
	# starts counting again from where the pointer is.
	A=$(spawn_floating steps-big 400x300+300+300)
	START=$(win_geom "$A")
	drag_begin 1 500 450
	xdotool keydown shift
	drag_to 510 450
	assert_eq "the increment modifier steps by the increment" "10 0 0 0" "$(moved_since "$START" "$A")"
	xdotool keydown ctrl
	drag_to 540 450
	assert_eq "with both held the big increment wins" "60 0 0 0" "$(moved_since "$START" "$A")"
	drag_to 530 450
	assert_eq "back under half a big step it goes back" "10 0 0 0" "$(moved_since "$START" "$A")"
	xdotool keyup ctrl
	drag_to 545 450
	assert_eq "letting the big one go counts small steps from there" "30 0 0 0" "$(moved_since "$START" "$A")"
	xdotool keyup shift
	drag_end 1
	$BSPC node "$A" -c
	sleep 0.3

	# Resizing by a corner is stepped too.
	A=$(spawn_floating steps-resize 400x300+300+300)
	START=$(win_geom "$A")
	drag_begin 3 680 580
	xdotool keydown shift
	drag_to 694 586
	assert_eq "a corner resize is stepped" "0 0 10 10" "$(moved_since "$START" "$A")"
	xdotool keyup shift
	drag_end 3
	$BSPC node "$A" -c
	sleep 0.3

	# The magnet stays out of a stepped drag and comes back without it.
	$BSPC config magnet_threshold 20
	A=$(spawn_floating steps-magnet 400x300+300+300)
	START=$(win_geom "$A")
	drag_begin 1 500 450
	xdotool keydown shift
	drag_to 208 450
	assert_eq "the magnet does not pull a stepped window" "-290 0 0 0" "$(moved_since "$START" "$A")"
	xdotool keyup shift
	drag_to 207 450
	assert_eq "the magnet is back once the modifier is up" "0 300 400 300" "$(win_geom "$A")"
	drag_end 1
	$BSPC node "$A" -c
	sleep 0.3
	$BSPC config magnet_threshold 0

	# Releasing in an Aero Snap zone with the modifier held does not tile.
	$BSPC config edge_snap_enabled true
	A=$(spawn_floating steps-snap 400x300+300+300)
	START=$(win_geom "$A")
	drag_begin 1 500 450
	xdotool keydown shift
	drag_to 500 2
	drag_end 1
	xdotool keyup shift
	assert_eq "a stepped drag released in a snap zone keeps its size" "400 300" \
		"$(set -- $(win_geom "$A"); echo "$3 $4")"
	$BSPC node "$A" -c
	sleep 0.3
	$BSPC config edge_snap_enabled false

	# With the modifier set to none, holding it changes nothing.
	$BSPC config pointer_increment_modifier none
	A=$(spawn_floating steps-none 400x300+300+300)
	START=$(win_geom "$A")
	drag_begin 1 500 450
	xdotool keydown shift
	drag_to 507 450
	assert_eq "a modifier set to none leaves the drag free" "7 0 0 0" "$(moved_since "$START" "$A")"
	xdotool keyup shift
	drag_end 1
	$BSPC node "$A" -c
	sleep 0.3
	$BSPC config pointer_increment_modifier shift
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: stepped drags (needs X11, test_window, xdotool and xwininfo)"
fi
