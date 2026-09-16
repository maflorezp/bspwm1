# Edge snap preview: color and opacity settings, and a translucent window.

echo ""
echo "== Edge snap preview =="

assert_ok "color_premultiply unit tests pass" ./test_color

assert_eq "preview color defaults to pink" "#E6007A" "$($BSPC config edge_snap_preview_color 2>/dev/null)"
assert_eq "preview opacity defaults to 25" "25" "$($BSPC config edge_snap_preview_opacity 2>/dev/null)"
assert_ok "set the preview color" $BSPC config edge_snap_preview_color '#00ff00'
assert_eq "preview color was set" "#00ff00" "$($BSPC config edge_snap_preview_color 2>/dev/null)"
assert_fail "reject a preview color that is not hex" $BSPC config edge_snap_preview_color pink
assert_ok "accept preview opacity 0" $BSPC config edge_snap_preview_opacity 0
assert_ok "accept preview opacity 100" $BSPC config edge_snap_preview_opacity 100
assert_fail "reject preview opacity above 100" $BSPC config edge_snap_preview_opacity 101
assert_fail "reject a negative preview opacity" $BSPC config edge_snap_preview_opacity -1
assert_ok "set the preview opacity" $BSPC config edge_snap_preview_opacity 50
assert_eq "preview opacity was set" "50" "$($BSPC config edge_snap_preview_opacity 2>/dev/null)"

# Id of the preview: the mapped, override-redirect, unnamed InputOutput child
# of the root window.
preview_window() {
	for w in $(xwininfo -root -children | awk '/^ +0x/ && /\(has no name\)/ {print $1}'); do
		info=$(xwininfo -id "$w")
		echo "$info" | grep -q 'Map State: IsViewable' || continue
		echo "$info" | grep -q 'Override Redirect State: yes' || continue
		echo "$info" | grep -q 'Class: InputOutput' || continue
		echo "$w"
		return
	done
}

if drag_tools_available && command -v xwd >/dev/null 2>&1; then
	drag_setup
	$BSPC config edge_snap_enabled true
	W=$(spawn_floating preview 400x300+700+400)

	# Push the pointer against the left edge and keep the button down.
	drag_begin 1 900 550
	drag_to 5 550
	P=$(preview_window)
	assert_not_empty "preview is mapped while dragging into a zone" "$P"
	assert_eq "preview uses a 32-bit visual" "32" \
		"$(xwininfo -id "$P" | awk '/Depth:/ {print $NF}')"
	# Last pixel inside the border, as stored by xwd: B G R A.
	assert_eq "preview fill is #00ff00 at 50%, premultiplied" "007f007f" \
		"$(xwd -id "$P" -silent -nobdrs | tail -c 4 | od -An -tx1 | tr -d ' \n')"
	drag_end 1
	$BSPC node "$W" -c
	sleep 0.3
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: preview rendering (needs X11, test_window, xdotool, xwininfo, xwd)"
fi

$BSPC config edge_snap_preview_color '#E6007A'
$BSPC config edge_snap_preview_opacity 25
