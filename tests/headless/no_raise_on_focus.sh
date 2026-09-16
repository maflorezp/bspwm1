# Switching back to a desktop focuses its window without restacking it.

echo ""
echo "== Focus without raising =="

if [ "$BACKEND" = "x11" ] && [ -f ./test_window ]; then
	HOME_DESK=$($BSPC query -D -d focused)
	$BSPC monitor -a noraise-other
	$BSPC rule -a "Noraise:*" state=floating
	./test_window noraise-a Noraise >/dev/null 2>&1 &
	sleep 0.5
	A=$($BSPC query -N -n focused)
	./test_window noraise-b Noraise >/dev/null 2>&1 &
	sleep 0.5
	$BSPC node "$A" -f
	sleep 0.3

	STACK_LOG=$(mktemp)
	$BSPC subscribe node_stack > "$STACK_LOG" &
	SUB=$!
	sleep 0.3
	$BSPC desktop -f noraise-other
	$BSPC desktop -f "$HOME_DESK"
	sleep 0.3
	kill "$SUB" 2>/dev/null || true
	assert_eq "switching back to a desktop does not restack its focused window" "0" "$(wc -l < "$STACK_LOG")"
	command rm -f "$STACK_LOG"

	$BSPC node -c
	sleep 0.3
	$BSPC node -c
	sleep 0.3
	$BSPC rule -r "Noraise:*:*"
	$BSPC desktop noraise-other -r
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: focus without raising (needs X11 and test_window)"
fi
