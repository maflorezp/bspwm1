# Edge snap zones: quarters near corners, top and bottom halves, and a
# centered band of the top edge that maximizes.

echo ""
echo "== Edge snap zones =="

assert_ok "edge zone unit tests pass" ./test_edge_zone

assert_eq "zone ratio defaults to 0" "0.000000" "$($BSPC config edge_snap_zone_ratio 2>/dev/null)"
assert_ok "set the zone ratio" $BSPC config edge_snap_zone_ratio 0.2
assert_eq "zone ratio was set" "0.200000" "$($BSPC config edge_snap_zone_ratio 2>/dev/null)"
assert_fail "reject a zone ratio above 0.5" $BSPC config edge_snap_zone_ratio 0.6
assert_fail "reject a negative zone ratio" $BSPC config edge_snap_zone_ratio -0.1
assert_fail "reject a zone ratio that is not a number" $BSPC config edge_snap_zone_ratio wide

node_state() {
	$BSPC query -T -n "$1" 2>/dev/null | grep -o '"state":"[a-z_]*"' | head -1 | cut -d'"' -f4
}

# Mapped override-redirect unnamed InputOutput child of the root: the preview.
zone_preview() {
	for w in $(xwininfo -root -children | awk '/^ +0x/ && /\(has no name\)/ {print $1}'); do
		info=$(xwininfo -id "$w")
		echo "$info" | grep -q 'Map State: IsViewable' || continue
		echo "$info" | grep -q 'Override Redirect State: yes' || continue
		echo "$info" | grep -q 'Class: InputOutput' || continue
		echo "$w"
		return
	done
}

# Drag a fresh floating window from the middle of the screen until the pointer
# is at (x, y), release it there, and print its id.
zone_drop() {
	local name="$1" x="$2" y="$3" w
	w=$(spawn_floating "$name" 400x300+760+390)
	drag_begin 1 960 540
	drag_to "$x" "$y"
	drag_end 1
	echo "$w"
}

# Geometry a window gets from `bspc node -S ZONE`.
zone_reference() {
	local zone="$1" c
	c=$(spawn_floating "zone-ref-$zone" 200x200+100+100)
	$BSPC node "$c" -S "$zone"
	sleep 0.3
	win_geom "$c"
	$BSPC node "$c" -c
	sleep 0.3
}

if drag_tools_available; then
	drag_setup
	$BSPC config edge_snap_enabled true
	$BSPC config edge_snap_zone_ratio 0.2 || true

	W=$(zone_drop zone-corner 100 2)
	assert_eq "near a corner the window takes that quarter" "$(zone_reference top_left)" "$(win_geom "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	W=$(zone_drop zone-top 500 2)
	assert_eq "the top edge off center gives the top half" "$(zone_reference top)" "$(win_geom "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	W=$(zone_drop zone-center 960 2)
	assert_eq "the center of the top edge maximizes" "fullscreen" "$(node_state "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	W=$(zone_drop zone-bottom 960 1077)
	assert_eq "the bottom edge gives the bottom half" "$(zone_reference bottom)" "$(win_geom "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	W=$(zone_drop zone-side 2 540)
	assert_eq "a side gives that half" "$(zone_reference left)" "$(win_geom "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	W=$(zone_drop zone-side-corner 2 1000)
	assert_eq "a side near a corner gives that quarter" "$(zone_reference bottom_left)" "$(win_geom "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	# While hovering the top half, the preview shows it.
	W=$(spawn_floating zone-preview 400x300+760+390)
	drag_begin 1 960 540
	drag_to 500 2
	P=$(zone_preview)
	assert_eq "the preview shows the top half" "0 0 1920 540" "$(win_geom "$P")"
	drag_end 1
	$BSPC node "$W" -c
	sleep 0.3

	# Ratio 0: the classic zones.
	$BSPC config edge_snap_zone_ratio 0 || true
	W=$(zone_drop zone-classic-top 500 2)
	assert_eq "classic zones: the whole top edge maximizes" "fullscreen" "$(node_state "$W")"
	$BSPC node "$W" -c
	sleep 0.3
	W=$(zone_drop zone-classic-bottom 960 1077)
	REF=$(zone_reference bottom)
	assert_fail "classic zones: the bottom edge does nothing" [ "$REF" = "$(win_geom "$W")" ]
	$BSPC node "$W" -c
	sleep 0.3
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: edge snap zones (needs X11, test_window, xdotool, xwininfo)"
fi
