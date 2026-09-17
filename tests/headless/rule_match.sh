# Rule conditions: how a rule picks the windows it applies to.

# The state of the window named `$1`, read off `bspc query -T`'s JSON: the
# leaf has exactly one "state" key, on its nested "client" object.
rule_state() {
	$BSPC query -T -n "$1" 2>/dev/null | grep -o '"state":"[a-z_]*"' | head -1 | cut -d'"' -f4
}

# The boolean flag `$2` (e.g. "sticky") of the node named `$1`, read off the
# same JSON, as "true" or "false".
rule_flag() {
	$BSPC query -T -n "$1" 2>/dev/null | grep -o "\"$2\":[a-z]*" | head -1 | cut -d: -f2
}

echo ""
echo "== Rule matching =="

assert_ok "rule match unit tests pass" ./test_rule_match

# The old CLASS:INSTANCE:NAME syntax compiles the name field literally, so a
# value that happens to start with `~` — read as a regex anchor by the new
# syntax — must still be accepted as plain text, invalid regex and all.
assert_ok "old pattern with an invalid regex after ~ still compiles" \
	$BSPC rule -a '*:*:~(pendiente' state=floating
assert_ok "remove old pattern with an invalid regex" $BSPC rule -r '*:*:~(pendiente'

# The new form: conditions with a name, mixed in with the consequences.
# Chromium stays on the list, unremoved, all the way past the reject block
# below: two checks need it still there, and BEFORE needs a real rule to
# count so a refusal is shown to leave it alone, not just an empty list.
assert_ok "add a rule the old way" $BSPC rule -a Chromium state=floating

# ignore_tile_limits is not one of parse_key_value()'s keys — tree.c reads
# it straight out of the effect text instead — but it must still be
# accepted as a consequence, in both forms.
assert_ok "add an old-form rule with ignore_tile_limits" \
	$BSPC rule -a kitty ignore_tile_limits=on
$BSPC rule -r tail || true
assert_ok "add a rule with ignore_tile_limits" \
	$BSPC rule -a class=kitty ignore_tile_limits=on
$BSPC rule -r tail || true

assert_ok "add a rule with conditions" \
	$BSPC rule -a class=Pavucontrol/i state=floating
$BSPC rule -r tail || true
assert_ok "add a rule with a regular expression" \
	$BSPC rule -a 'class~=^(eog|feh)$' state=floating
$BSPC rule -r tail || true
assert_ok "the /i suffix is taken off the value before validating it" \
	$BSPC rule -a type=dialog/i center=on
$BSPC rule -r tail || true

# /i has to come off before the length is judged, or a pattern that
# legitimately fits right up to the edge would be refused for the two
# characters of the suffix that were never really part of it.
P254=$(printf '%0254d' 0 | tr 0 c)
assert_ok "a 254-character pattern followed by /i is accepted" \
	$BSPC rule -a "class=$P254/i" state=floating
$BSPC rule -r tail || true
P255=$(printf '%0255d' 0 | tr 0 c)
assert_ok "a 255-character pattern followed by /i is accepted" \
	$BSPC rule -a "class=$P255/i" state=floating
$BSPC rule -r tail || true

assert_ok "add a rule with two conditions" \
	$BSPC rule -a class=Google-chrome instance~=^crx_ center=on

RULES=$($BSPC rule -l)
assert_eq "the conditions are listed as they were written" "1" \
	"$(printf '%s\n' "$RULES" | grep -c '^class=Google-chrome instance~=\^crx_ =>')"
assert_eq "the old form is still listed the old way" "1" \
	"$(printf '%s\n' "$RULES" | grep -c '^Chromium:\*:\* =>')"
$BSPC rule -r tail || true

assert_ok "add a rule with a window type" $BSPC rule -a type=dialog center=on
$BSPC rule -r tail || true
assert_ok "add a rule with a role" $BSPC rule -a role=pop-up state=floating
$BSPC rule -r tail || true
assert_ok "add a rule for child windows" $BSPC rule -a transient=on state=floating
$BSPC rule -r tail || true

# No condition at all matches everything, listed the same way a fully
# wildcarded old-form pattern would be.
assert_ok "add a rule with no conditions" $BSPC rule -a state=floating sticky=on
RULES2=$($BSPC rule -l)
assert_eq "a rule with no conditions is listed as *:*:*" "1" \
	"$(printf '%s\n' "$RULES2" | grep -c '^\*:\*:\* => state=floating sticky=on$')"
$BSPC rule -r tail || true

# A condition written after the last consequence must not leave a trailing
# space in the effect (nothing else follows it to earn that space).
assert_ok "add a rule with a consequence followed by a condition" \
	$BSPC rule -a state=floating class=kitty
RULES3=$($BSPC rule -l)
assert_eq "no trailing space is left in the effect" "1" \
	"$(printf '%s\n' "$RULES3" | grep -c '^class=kitty => state=floating$')"
$BSPC rule -r tail || true

# Everything that must be refused, with the rule never added. Chromium is
# still the only rule on the list, so a real BEFORE also proves a refusal
# does not disturb what was already there.
BEFORE=$($BSPC rule -l | wc -l)
assert_fail "reject a broken regular expression" $BSPC rule -a 'class~=^(eog' state=floating
assert_fail "reject an unknown window type" $BSPC rule -a type=popup state=floating
assert_fail "reject an unknown key" $BSPC rule -a clas=kitty state=floating
assert_fail "reject a repeated condition" $BSPC rule -a class=a class=b state=floating
assert_fail "reject an unknown consequence" $BSPC rule -a class=kitty staet=floating
assert_fail "reject an unknown consequence in the old form" $BSPC rule -a kitty staet=floating
assert_fail "an unknown key written with an operator still blames the key" \
	$BSPC rule -a clas~=kitty state=floating
assert_fail "reject a consequence written with an operator" \
	$BSPC rule -a class=kitty state~=floating
assert_fail "reject a consequence written with a case marker" \
	$BSPC rule -a class=kitty state=floating/i
assert_fail "the old form refuses a consequence with a case marker" \
	$BSPC rule -a kitty state=floating/i

LONG=$(printf '%0300d' 0 | tr 0 a)
assert_fail "reject a value longer than the pattern buffer" \
	$BSPC rule -a "class=$LONG" state=floating
assert_fail "a value too long is refused even when it ends in /i" \
	$BSPC rule -a "class=$LONG/i" state=floating

P250=$(printf '%0250d' 0 | tr 0 b)
assert_fail "reject a rule whose conditions do not fit the listing" \
	$BSPC rule -a "class=$P250" "instance=$P250" "name=$P250" state=floating

assert_eq "a refused rule is not added" "$BEFORE" "$($BSPC rule -l | wc -l)"

# Chromium was needed all the way through the block above; drop it now.
$BSPC rule -r tail || true

# End-to-end: real windows, declaring class, role, type and parent, matched
# against real rules. Needs test_window built with --role/--type/--transient
# and only runs against X11 — the wlroots test client has no such options.
if [ "$BACKEND" = "x11" ] && [ -f ./test_window ]; then
	# Case: the rule says Pavucontrol, the window says pavucontrol.
	assert_ok "add the case insensitive rule" \
		$BSPC rule -a class=Pavucontrol/i state=floating
	./test_window rm-case pavucontrol >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "a rule with /i matches whatever the case" "floating" "$(rule_state "$W")"
	$BSPC node "$W" -c || true
	sleep 0.3
	$BSPC rule -r tail || true

	# A regular expression on the instance: the web app, not the browser.
	# test_window's first positional argument is the instance name, ICCCM's
	# WM_CLASS order (verified against a real window's className/
	# instanceName): crx_abcdef has to come first, or it lands in the class
	# field instead and the rule never sees it.
	assert_ok "add the web app rule" \
		$BSPC rule -a 'instance~=^crx_' state=floating
	./test_window crx_abcdef rm-app >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "the web app matches the regular expression" "floating" "$(rule_state "$W")"
	$BSPC node "$W" -c || true
	sleep 0.3
	./test_window rm-browser google-chrome >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "the plain browser window does not" "tiled" "$(rule_state "$W")"
	$BSPC node "$W" -c || true
	sleep 0.3
	$BSPC rule -r tail || true

	# The role.
	assert_ok "add the role rule" $BSPC rule -a role=pop-up sticky=on
	./test_window rm-role RmRole --role pop-up >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "a window with that role is sticky" "true" "$(rule_flag "$W" sticky)"
	$BSPC node "$W" -c || true
	sleep 0.3
	$BSPC rule -r tail || true

	# The window type. type=dialog is not tested against bspwm's own
	# floating-by-default behaviour for dialogs — it would not tell the rule
	# apart from that default. sticky=on is a consequence bspwm never gives
	# a dialog on its own, so it does tell them apart.
	assert_ok "add the dialog rule" $BSPC rule -a type=dialog sticky=on
	./test_window rm-dialog RmDialog --type dialog >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "a dialog is sticky" "true" "$(rule_flag "$W" sticky)"
	$BSPC node "$W" -c || true
	sleep 0.3
	$BSPC rule -r tail || true

	# A child window.
	assert_ok "add the child window rule" $BSPC rule -a transient=on sticky=on
	./test_window rm-child RmChild --transient >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "a child window is sticky" "true" "$(rule_flag "$W" sticky)"
	$BSPC node "$W" -c || true
	sleep 0.3
	./test_window rm-plain RmChild >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "a window with no parent is not" "false" "$(rule_flag "$W" sticky)"
	$BSPC node "$W" -c || true
	sleep 0.3
	$BSPC rule -r tail || true
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: rule conditions against real windows (needs X11 and test_window)"
fi
