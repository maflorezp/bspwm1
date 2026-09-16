# Magnetic edges: window edges stick while moving or resizing with the pointer.

echo ""
echo "== Magnetic edges =="

assert_ok "magnet unit tests pass" ./test_magnet

assert_eq "magnet is off by default" "0" "$($BSPC config magnet_threshold 2>/dev/null)"
assert_ok "set the magnet threshold" $BSPC config magnet_threshold 20
assert_eq "magnet threshold was set" "20" "$($BSPC config magnet_threshold 2>/dev/null)"
assert_ok "accept a magnet threshold of 0" $BSPC config magnet_threshold 0
assert_fail "reject a magnet threshold above 100" $BSPC config magnet_threshold 101
assert_fail "reject a negative magnet threshold" $BSPC config magnet_threshold -1

if drag_tools_available; then
	drag_setup
	$BSPC config edge_snap_enabled false
	$BSPC config magnet_threshold 20

	# Work area edge, and pulling free again (border 2: outer box = inner + 4).
	A=$(spawn_floating magnet-area 400x300+300+300)
	drag_begin 1 500 450
	drag_to 208 450
	assert_eq "a moved window sticks to the work area while dragging" "0 300 400 300" "$(win_geom "$A")"
	drag_to 248 450
	assert_eq "dragging on pulls the window free" "48 300 400 300" "$(win_geom "$A")"
	drag_end 1
	$BSPC node "$A" -c
	sleep 0.3

	# Edge against edge.
	B=$(spawn_floating magnet-neighbour 400x300+1000+300)
	A=$(spawn_floating magnet-moved 400x300+300+300)
	drag_begin 1 500 450
	drag_to 790 450
	assert_eq "a moved window touches the one next to it" "596 300 400 300" "$(win_geom "$A")"
	drag_end 1
	$BSPC node "$A" -c
	$BSPC node "$B" -c
	sleep 0.3

	# In line and stacked.
	B=$(spawn_floating magnet-below 400x300+1000+500)
	A=$(spawn_floating magnet-above 400x300+700+180)
	drag_begin 1 900 330
	drag_to 1194 330
	assert_eq "a moved window lines up with and touches the one below" "1000 196 400 300" "$(win_geom "$A")"
	drag_end 1
	$BSPC node "$A" -c
	$BSPC node "$B" -c
	sleep 0.3

	# A window far away on the other axis does not attract.
	B=$(spawn_floating magnet-far 300x200+1000+850)
	A=$(spawn_floating magnet-free 400x300+300+100)
	drag_begin 1 500 250
	drag_to 1194 250
	assert_eq "a window far away on the other axis does not attract" "994 100 400 300" "$(win_geom "$A")"
	drag_end 1
	$BSPC node "$A" -c
	$BSPC node "$B" -c
	sleep 0.3

	# Off means off.
	$BSPC config magnet_threshold 0
	A=$(spawn_floating magnet-off 400x300+300+300)
	drag_begin 1 500 450
	drag_to 208 450
	assert_eq "with magnet_threshold 0 the window follows the pointer" "8 300 400 300" "$(win_geom "$A")"
	drag_end 1
	$BSPC node "$A" -c
	sleep 0.3
	$BSPC config magnet_threshold 20

	# An edge snap zone still wins on release.
	$BSPC config edge_snap_enabled true
	A=$(spawn_floating magnet-zone 400x300+300+300)
	drag_begin 1 500 450
	drag_to 5 450
	drag_end 1
	C=$(spawn_floating magnet-reference 200x200+600+600)
	$BSPC node "$C" -S left
	sleep 0.3
	assert_eq "releasing in a snap zone applies the zone" "$(win_geom "$C")" "$(win_geom "$A")"
	$BSPC node "$A" -c
	$BSPC node "$C" -c
	sleep 0.3
	$BSPC config edge_snap_enabled false

	# Crossing monitors: the window sticks to the monitor it moves onto.
	MON=$($BSPC query -M -m focused)
	$BSPC monitor "$MON" -g 960x1080+0+0
	$BSPC wm -a magnet-right 960x1080+960+0
	A=$(spawn_floating magnet-cross 300x200+300+300)
	drag_begin 1 450 400
	drag_to 1760 400
	assert_eq "a window moved onto another monitor sticks to its edge" "1616 300 300 200" "$(win_geom "$A")"
	drag_end 1
	assert_eq "and ends up on that monitor" "magnet-right" "$($BSPC query -M -n "$A" --names 2>/dev/null)"
	$BSPC node "$A" -c
	sleep 0.3
	$BSPC monitor magnet-right -r
	$BSPC monitor "$MON" -g 1920x1080+0+0

	# Resizing a side: only that edge sticks, and pulls free again.
	$BSPC config magnet_threshold 20
	B=$(spawn_floating resize-neighbour 400x300+1000+300)
	A=$(spawn_floating resize-side 400x300+300+300)
	drag_begin 2 690 450
	drag_to 979 450
	assert_eq "a resized side touches the window next to it" "300 300 696 300" "$(win_geom "$A")"
	drag_to 1029 450
	assert_eq "stretching on pulls the side free" "300 300 739 300" "$(win_geom "$A")"
	drag_end 2
	$BSPC node "$A" -c
	sleep 0.3

	# Resizing a corner: both edges stick, each to its own target.
	A=$(spawn_floating resize-corner 400x300+300+300)
	drag_begin 3 680 580
	drag_to 971 1048
	assert_eq "a resized corner sticks to a window and to the work area" "300 300 696 776" "$(win_geom "$A")"
	drag_end 3
	$BSPC node "$A" -c
	$BSPC node "$B" -c
	sleep 0.3

	# Tiled windows resize exactly as without the magnet.
	./test_window resize-tiled-1 Drag >/dev/null 2>&1 &
	sleep 0.5
	T1=$($BSPC query -N -n focused)
	./test_window resize-tiled-2 Drag >/dev/null 2>&1 &
	sleep 0.5
	BEFORE=$(win_geom "$T1")
	drag_begin 2 900 540
	drag_to 950 540
	drag_end 2
	WITH_MAGNET=$(win_geom "$T1")
	$BSPC node @/ -r 0.5
	sleep 0.3
	$BSPC config magnet_threshold 0
	drag_begin 2 900 540
	drag_to 950 540
	drag_end 2
	WITHOUT_MAGNET=$(win_geom "$T1")
	assert_fail "the tiled resize actually changed the window" [ "$BEFORE" = "$WITH_MAGNET" ]
	assert_eq "a tiled resize is the same with and without the magnet" "$WITHOUT_MAGNET" "$WITH_MAGNET"
	$BSPC node "$T1" -c
	sleep 0.3
	$BSPC node -c
	sleep 0.3

	$BSPC config magnet_threshold 0
	$BSPC config edge_snap_enabled true
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: magnetic moves (needs X11, test_window, xdotool, xwininfo)"
fi
