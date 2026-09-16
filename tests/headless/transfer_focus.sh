# A focused window moved to another monitor with --follow keeps the focus and
# stays above the windows it lands on.

echo ""
echo "== Transfer with follow =="

# Print the given node ids in stacking order, bottom first.
stack_order() {
	local id n
	for id in $($BSPC wm -d | grep -o '"stackingList":\[[^]]*\]' | grep -o '[0-9][0-9]*'); do
		for n in "$@"; do
			[ "$id" = "$(printf '%d' "$n")" ] && printf '%s ' "$n"
		done
	done | sed 's/ $//'
}

if [ "$BACKEND" = "x11" ] && [ -f ./test_window ]; then
	MON=$($BSPC query -M -m focused)
	$BSPC monitor "$MON" -g 960x1080+0+0 || true
	$BSPC wm -a follow-right 960x1080+960+0 || true
	$BSPC rule -a "Follow:b" -o monitor=follow-right state=floating rectangle=300x200+1300+300 || true
	./test_window b Follow >/dev/null 2>&1 &
	sleep 0.5
	B=$($BSPC query -N -n 'any.window' -m follow-right | head -1)
	$BSPC monitor -f "$MON" || true
	$BSPC rule -a "Follow:a" -o state=floating rectangle=300x200+100+300 || true
	./test_window a Follow >/dev/null 2>&1 &
	sleep 0.5
	A=$($BSPC query -N -n focused)

	assert_ok "move the focused window to the other monitor" $BSPC node "$A" -m follow-right --follow
	sleep 0.3
	assert_eq "the moved window keeps the focus" "$A" "$($BSPC query -N -n focused 2>/dev/null)"
	assert_eq "and stays above the window that was there" "$B $A" "$(stack_order "$A" "$B")"

	# Without --follow the focus stays on the source monitor.
	$BSPC node "$A" -m "$MON" --follow || true
	sleep 0.3
	assert_ok "send the focused window back without following it" $BSPC node "$A" -m follow-right
	sleep 0.3
	assert_eq "without follow the focus leaves the moved window" "false" \
		"$([ "$($BSPC query -N -n focused 2>/dev/null)" = "$A" ] && echo true || echo false)"

	$BSPC node "$A" -c || true
	$BSPC node "$B" -c || true
	sleep 0.3
	$BSPC monitor follow-right -r || true
	$BSPC monitor "$MON" -g 1920x1080+0+0 || true
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: transfer with follow (needs X11 and test_window)"
fi
