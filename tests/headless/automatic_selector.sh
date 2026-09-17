# The automatic modifier matches nodes without a manual preselection, and
# !automatic matches the preselected ones. Scripts that send new windows to
# the newest preselection rely on newest.!automatic finding nothing when
# nothing is preselected.

echo ""
echo "== Automatic node selector =="

# Prints the first window that is not in the list given as $1, waiting for
# it to be managed.
automatic_new_window() {
	automatic_tries=0
	while [ "$automatic_tries" -lt 30 ]; do
		automatic_found=$($BSPC query -N -n .window 2>/dev/null | grep -vxF "$1" | head -n 1 || true)
		if [ -n "$automatic_found" ]; then
			echo "$automatic_found"
			return 0
		fi
		automatic_tries=$((automatic_tries + 1))
		sleep 0.1
	done
	return 0
}

if [ "$BACKEND" = "x11" ] && [ -f ./test_window ]; then
	AUTO_HOME=$($BSPC query -D -d focused 2>/dev/null || true)
	$BSPC monitor -a auto-one auto-two || true
	AUTO_ONE=$($BSPC query -D -d auto-one 2>/dev/null || true)
	AUTO_TWO=$($BSPC query -D -d auto-two 2>/dev/null || true)
	$BSPC desktop -f auto-one || true

	AUTO_BEFORE=$($BSPC query -N -n .window 2>/dev/null || true)
	./test_window auto-a Autosel >/dev/null 2>&1 &
	AUTO_W=$(automatic_new_window "$AUTO_BEFORE")

	# Nothing is preselected yet: every window is automatic.
	assert_eq "without a preselection, .!automatic matches no window" \
		"" "$($BSPC query -N -n '.window.!automatic' 2>/dev/null || true)"
	assert_eq "without a preselection, .automatic matches the window" \
		"$AUTO_W" "$($BSPC query -N -d auto-one -n '.window.automatic' 2>/dev/null || true)"

	$BSPC desktop -f auto-two || true
	assert_eq "on an empty desktop, newest.!automatic finds no window elsewhere" \
		"" "$($BSPC query -N -n 'newest.!automatic' 2>/dev/null || true)"

	$BSPC desktop -f auto-one || true
	$BSPC node "$AUTO_W" -p east || true
	assert_eq "a preselected window matches .!automatic" \
		"$AUTO_W" "$($BSPC query -N -n '.window.!automatic' 2>/dev/null || true)"
	assert_eq "a preselected window does not match .automatic" \
		"" "$($BSPC query -N -d auto-one -n '.window.automatic' 2>/dev/null || true)"

	$BSPC desktop -f auto-two || true
	assert_eq "newest.!automatic finds the preselection on another desktop" \
		"$AUTO_W" "$($BSPC query -N -n 'newest.!automatic' 2>/dev/null || true)"

	# End to end: an external rule that sends new windows to the newest
	# preselection must leave a window opened on an empty desktop there.
	$BSPC node "$AUTO_W" -p cancel || true
	AUTO_OLD_ERC=$($BSPC config external_rules_command 2>/dev/null || true)
	AUTO_ERC=$(mktemp)
	cat > "$AUTO_ERC" <<-EOF
		#!/bin/sh
		echo "node=\$('$(cd .. && pwd)/bspc' query -N -n 'newest.!automatic') follow=on"
	EOF
	chmod +x "$AUTO_ERC"
	$BSPC config external_rules_command "$AUTO_ERC" || true
	$BSPC desktop -f auto-two || true
	AUTO_BEFORE=$($BSPC query -N -n .window 2>/dev/null || true)
	./test_window auto-b Autosel >/dev/null 2>&1 &
	AUTO_X=$(automatic_new_window "$AUTO_BEFORE")
	sleep 0.3
	assert_eq "a window opened on an empty desktop stays there" \
		"$AUTO_TWO" "$($BSPC query -D -n "$AUTO_X" 2>/dev/null || true)"
	assert_eq "and the focus stays on that desktop" \
		"$AUTO_TWO" "$($BSPC query -D -d focused 2>/dev/null || true)"
	$BSPC config external_rules_command "$AUTO_OLD_ERC" || true
	command rm -f "$AUTO_ERC"

	for AUTO_NODE in $AUTO_W $AUTO_X; do
		$BSPC node "$AUTO_NODE" -c || true
	done
	sleep 0.5
	$BSPC desktop -f "$AUTO_HOME" || true
	for AUTO_DESK in $AUTO_ONE $AUTO_TWO; do
		$BSPC desktop "$AUTO_DESK" -r || true
	done
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: automatic node selector (needs X11 and test_window)"
fi
