# Clients and task bars can iconify a window, and activating it restores it.

echo ""
echo "== Iconify =="

node_hidden() {
	$BSPC query -T -n "$1" 2>/dev/null | grep -o '"hidden":[a-z]*' | head -1 | cut -d: -f2
}

if [ "$BACKEND" = "x11" ] && [ -f ./test_window ] && command -v xdotool >/dev/null 2>&1; then
	./test_window iconify-a Iconify >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	# XIconifyWindow(): a WM_CHANGE_STATE client message with IconicState.
	xdotool windowminimize "$W"
	sleep 0.3
	assert_eq "a client can iconify its window" "true" "$(node_hidden "$W")"
	# What a task bar sends to bring a window back: _NET_ACTIVE_WINDOW.
	xdotool windowactivate "$W" >/dev/null 2>&1 || true
	sleep 0.3
	assert_eq "activating an iconified window shows it" "false" "$(node_hidden "$W")"
	assert_eq "and focuses it" "$W" "$($BSPC query -N -n focused 2>/dev/null)"
	$BSPC node "$W" -c
	sleep 0.3
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: iconify (needs X11, test_window, xdotool)"
fi
