# Clients that draw their own title bar ask for a move with _NET_WM_MOVERESIZE.

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

	# Only the move direction is handled.
	xdotool mousemove 100 100
	sleep 0.1
	xdotool mousedown 1
	./send_moveresize "$W" 100 100 4 1
	sleep 0.3
	xdotool mousemove 300 300
	sleep 0.3
	assert_eq "a client-initiated resize is ignored" "400 400 400 300" "$(win_geom "$W")"
	xdotool mouseup 1
	sleep 0.3

	$BSPC node "$W" -c
	sleep 0.3
	$BSPC config edge_snap_enabled true
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: client-initiated moves (needs X11, test_window, xdotool, xwininfo)"
fi
