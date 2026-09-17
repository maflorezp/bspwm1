# Clients that draw their own title bar ask for a move or a resize with
# _NET_WM_MOVERESIZE.

# Put a floating window back at 400x300+400+400, whatever a failed step left.
moveresize_restore() {
	local win="$1"
	set -- $(win_geom "$win")
	$BSPC node "$win" -v $((400 - $1)) $((400 - $2)) || true
	$BSPC node "$win" -z bottom_right $((400 - $3)) $((300 - $4)) || true
}

# True when the root window advertises _NET_WM_MOVERESIZE.
moveresize_advertised() {
	xprop -root _NET_SUPPORTED | tr -d ' ' | tr ',=' '\n\n' | grep -qx _NET_WM_MOVERESIZE
}

echo ""
echo "== _NET_WM_MOVERESIZE =="

assert_eq "client moves are allowed by default" "true" "$($BSPC config allow_net_wm_moveresize 2>/dev/null)"

if drag_tools_available && [ -x ./send_moveresize ]; then
	drag_setup
	$BSPC config edge_snap_enabled false
	W=$(spawn_floating moveresize 400x300+300+300)

	# Press on the empty root window, ask for a move, then move the pointer.
	xdotool mousemove 100 100
	sleep 0.1
	xdotool mousedown 1
	./send_moveresize "$W" 100 100 8 1
	sleep 0.3
	xdotool mousemove 200 200
	sleep 0.3
	assert_eq "a client-initiated move follows the pointer" "400 400 400 300" "$(win_geom "$W")"
	xdotool mouseup 1
	sleep 0.3

	$BSPC config allow_net_wm_moveresize false || true
	xdotool mousemove 100 100
	sleep 0.1
	xdotool mousedown 1
	./send_moveresize "$W" 100 100 8 1
	sleep 0.3
	xdotool mousemove 300 300
	sleep 0.3
	assert_eq "client moves are ignored when disabled" "400 400 400 300" "$(win_geom "$W")"
	xdotool mouseup 1
	sleep 0.3
	$BSPC config allow_net_wm_moveresize true || true

	# A request with no button held must not leave the pointer grabbed.
	./send_moveresize "$W" 100 100 8 1
	sleep 0.3
	assert_ok "bspc answers after a move request with no button held" timeout 2 $BSPC query -N -n focused
	# Release a grab left behind, so a failure here does not hang the rest.
	xdotool click 1
	sleep 0.3

	# The client names the corner: the pointer is above and to the left of
	# the window, which would pick the top left corner.
	xdotool mousemove 100 100
	sleep 0.1
	xdotool mousedown 1
	./send_moveresize "$W" 100 100 4 1
	sleep 0.3
	xdotool mousemove 300 300
	sleep 0.3
	assert_eq "a client-initiated corner resize follows the pointer" "400 400 600 500" "$(win_geom "$W")"
	xdotool mouseup 1
	sleep 0.3
	moveresize_restore "$W"

	# A side resize only changes the size across that side.
	xdotool mousemove 100 100
	sleep 0.1
	xdotool mousedown 1
	./send_moveresize "$W" 100 100 3 1
	sleep 0.3
	xdotool mousemove 200 200
	sleep 0.3
	assert_eq "a client-initiated side resize follows the pointer" "400 400 500 300" "$(win_geom "$W")"
	xdotool mouseup 1
	sleep 0.3
	moveresize_restore "$W"

	# A cancel request stops the drag while the button is still held.
	xdotool mousemove 100 100
	sleep 0.1
	xdotool mousedown 1
	./send_moveresize "$W" 100 100 8 1
	sleep 0.3
	xdotool mousemove 150 150
	sleep 0.3
	./send_moveresize "$W" 0 0 11 1
	sleep 0.3
	xdotool mousemove 250 250
	sleep 0.3
	assert_eq "a cancel request ends the client-initiated drag" "450 450 400 300" "$(win_geom "$W")"
	assert_ok "bspc answers after a cancel request with the button held" timeout 2 $BSPC query -N -n focused
	xdotool mouseup 1
	sleep 0.3
	moveresize_restore "$W"

	# A hidden window is not shown, so it is not dragged.
	$BSPC node "$W" -g hidden=on || true
	xdotool mousemove 100 100
	sleep 0.1
	xdotool mousedown 1
	./send_moveresize "$W" 100 100 8 1
	sleep 0.3
	xdotool mousemove 200 200
	sleep 0.3
	assert_ok "bspc answers after a move request for a hidden window" timeout 2 $BSPC query -D -d focused
	xdotool mouseup 1
	sleep 0.3
	assert_eq "a hidden window is not dragged" "400 400 400 300" "$(win_geom "$W")"
	$BSPC node "$W" -g hidden=off || true
	moveresize_restore "$W"

	$BSPC node "$W" -c
	sleep 0.3
	$BSPC config edge_snap_enabled true
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: client-initiated moves (needs X11, test_window, xdotool, xwininfo)"
fi

# Toolkits only ask for a drag when the atom is advertised, and do it
# themselves otherwise.
if [ "$BACKEND" = "x11" ] && command -v xprop >/dev/null 2>&1; then
	$BSPC config allow_net_wm_moveresize false || true
	assert_fail "_NET_WM_MOVERESIZE is not advertised when disabled" moveresize_advertised
	$BSPC config allow_net_wm_moveresize true || true
	assert_ok "_NET_WM_MOVERESIZE is advertised when allowed" moveresize_advertised
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: advertised _NET_WM_MOVERESIZE (needs X11, xprop)"
fi
