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

# Remove the last rule and prove it is gone: `bspc rule -r` exits 0 whether
# it removed anything or not, so the number of rules left is the only
# evidence that the removal did something.
drop_tail() {
	local desc="$1" before
	before=$($BSPC rule -l | wc -l)
	$BSPC rule -r tail
	assert_eq "$desc" "$((before - 1))" "$($BSPC rule -l | wc -l)"
}

# The same, for a rule removed by its cause instead of by position.
drop_cause() {
	local desc="$1" cause="$2" before
	before=$($BSPC rule -l | wc -l)
	$BSPC rule -r "$cause"
	assert_eq "$desc" "$((before - 1))" "$($BSPC rule -l | wc -l)"
}

echo ""
echo "== Rule matching =="

assert_ok "rule match unit tests pass" ./test_rule_match

# The old CLASS:INSTANCE:NAME syntax compiles the name field literally, so a
# value that happens to start with `~` — read as a regex anchor by the new
# syntax — must still be accepted as plain text, invalid regex and all.
assert_ok "old pattern with an invalid regex after ~ still compiles" \
	$BSPC rule -a '*:*:~(pendiente' state=floating
drop_cause "the old pattern with an invalid regex is removed" '*:*:~(pendiente'

# The old form's last field is the window title, which is free text and may
# well carry an `=` of its own. The form is told apart by the shape of the
# key instead: only lowercase letters and underscores followed by `=` or
# `~=` open the new form, so a title with an `=` in it stays a title.
assert_ok "an old pattern whose title contains = is still the old form" \
	$BSPC rule -a 'st:*:vim = notes' state=floating
RULES_OLD_EQ=$($BSPC rule -l)
assert_eq "and it is listed as it was written" "1" \
	"$(printf '%s\n' "$RULES_OLD_EQ" | grep -c '^st:\*:vim = notes =>')"
drop_tail "the old pattern with an = in its title is removed"

# The other way round: the key wins, and the value keeps whatever `=` it
# has, because only the first one is read.
assert_ok "a condition keeps the = that follows the first one" \
	$BSPC rule -a 'name=vim = notes' state=floating
RULES_NEW_EQ=$($BSPC rule -l)
assert_eq "and it is listed as a condition" "1" \
	"$(printf '%s\n' "$RULES_NEW_EQ" | grep -c '^name=vim = notes =>')"
drop_tail "the condition with an = in its pattern is removed"

# The new form has no positional pattern, so writing the options first is
# the natural thing to do; they have to be read as options and not as the
# pattern of a rule that does not have one.
assert_ok "the one-shot flag may come before the conditions" \
	$BSPC rule -a -o class=kitty state=floating
RULES_OS=$($BSPC rule -l)
assert_eq "and the rule is listed as one-shot" "1" \
	"$(printf '%s\n' "$RULES_OS" | grep -c '^class=kitty -> state=floating$')"
drop_tail "the one-shot rule written flag first is removed"

assert_ok "the long one-shot flag may come before the pattern too" \
	$BSPC rule -a --one-shot kitty state=floating
RULES_OS2=$($BSPC rule -l)
assert_eq "and the old-form rule is listed as one-shot" "1" \
	"$(printf '%s\n' "$RULES_OS2" | grep -c '^kitty:\*:\* -> state=floating$')"
drop_tail "the old-form one-shot rule written flag first is removed"

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
drop_tail "the old-form rule with ignore_tile_limits is removed"
assert_ok "add a rule with ignore_tile_limits" \
	$BSPC rule -a class=kitty ignore_tile_limits=on
drop_tail "the rule with ignore_tile_limits is removed"

# Every key a consequence can take, one rule each. cmd_rule() refuses an
# unknown key outright, so a key parse_key_value() (src/rule.c) reads but
# cmd_rule() does not know would turn a legitimate rule into an error: the
# two have to name the same keys, and this is what says so.
CSQ_BEFORE=$($BSPC rule -l | wc -l)
CSQ_COUNT=0
for CSQ in \
	'monitor=^1' 'desktop=^1' 'node=^1' 'split_dir=north' 'split_ratio=0.3' \
	'state=floating' 'layer=normal' 'honor_size_hints=yes' 'rectangle=100x100+0+0' \
	'hidden=on' 'sticky=on' 'private=on' 'locked=on' 'marked=on' 'center=on' \
	'follow=on' 'manage=on' 'focus=on' 'border=on' 'ignore_tile_limits=on'
do
	assert_ok "the consequence $CSQ is accepted" $BSPC rule -a class=kitty "$CSQ"
	CSQ_COUNT=$((CSQ_COUNT + 1))
done
assert_eq "every consequence key gave a rule" "$((CSQ_BEFORE + CSQ_COUNT))" \
	"$($BSPC rule -l | wc -l)"
while [ "$($BSPC rule -l | wc -l)" -gt "$CSQ_BEFORE" ] ; do
	$BSPC rule -r tail
done
assert_eq "the consequence key rules are removed" "$CSQ_BEFORE" "$($BSPC rule -l | wc -l)"

assert_ok "add a rule with conditions" \
	$BSPC rule -a class=Pavucontrol/i state=floating
drop_tail "the case insensitive rule is removed"
assert_ok "add a rule with a regular expression" \
	$BSPC rule -a 'class~=^(eog|feh)$' state=floating
drop_tail "the regular expression rule is removed"

# /i has to come off before the length is judged, or a pattern that
# legitimately fits right up to the edge would be refused for the two
# characters of the suffix that were never really part of it.
P254=$(printf '%0254d' 0 | tr 0 c)
assert_ok "a 254-character pattern followed by /i is accepted" \
	$BSPC rule -a "class=$P254/i" state=floating
drop_tail "the 254-character rule is removed"
P255=$(printf '%0255d' 0 | tr 0 c)
assert_ok "a 255-character pattern followed by /i is accepted" \
	$BSPC rule -a "class=$P255/i" state=floating
drop_tail "the 255-character rule is removed"

assert_ok "add a rule with two conditions" \
	$BSPC rule -a class=Google-chrome instance~=^crx_ center=on

RULES=$($BSPC rule -l)
assert_eq "the conditions are listed as they were written" "1" \
	"$(printf '%s\n' "$RULES" | grep -c '^class=Google-chrome instance~=\^crx_ =>')"
assert_eq "the old form is still listed the old way" "1" \
	"$(printf '%s\n' "$RULES" | grep -c '^Chromium:\*:\* =>')"
drop_tail "the two-condition rule is removed"

assert_ok "add a rule with a window type" $BSPC rule -a type=dialog center=on
drop_tail "the window type rule is removed"
assert_ok "add a rule with a role" $BSPC rule -a role=pop-up state=floating
drop_tail "the role rule is removed"
assert_ok "add a rule for child windows" $BSPC rule -a transient=on state=floating
drop_tail "the child window rule is removed"

# No condition at all matches everything, listed the same way a fully
# wildcarded old-form pattern would be.
assert_ok "add a rule with no conditions" $BSPC rule -a state=floating sticky=on
RULES2=$($BSPC rule -l)
assert_eq "a rule with no conditions is listed as *:*:*" "1" \
	"$(printf '%s\n' "$RULES2" | grep -c '^\*:\*:\* => state=floating sticky=on$')"
drop_tail "the rule with no conditions is removed"

# A condition written after the last consequence must not leave a trailing
# space in the effect (nothing else follows it to earn that space).
assert_ok "add a rule with a consequence followed by a condition" \
	$BSPC rule -a state=floating class=kitty
RULES3=$($BSPC rule -l)
assert_eq "no trailing space is left in the effect" "1" \
	"$(printf '%s\n' "$RULES3" | grep -c '^class=kitty => state=floating$')"
drop_tail "the rule written consequence first is removed"

# The consequences are kept in a 255-character effect. One that fits
# right up to the last character is kept whole, in both forms, and so is a
# second one squeezed in after it.
D247=$(printf '%0247d' 0 | tr 0 d)
assert_ok "a consequence exactly as long as the effect allows is accepted" \
	$BSPC rule -a class=kitty "desktop=$D247"
assert_eq "and it is listed whole" "1" \
	"$($BSPC rule -l | grep -c "^class=kitty => desktop=$D247\$")"
drop_tail "the longest consequence is removed"
D237=$(printf '%0237d' 0 | tr 0 d)
assert_ok "two consequences that exactly fill the effect are accepted" \
	$BSPC rule -a kitty "desktop=$D237" sticky=on
assert_eq "and both are listed whole" "1" \
	"$($BSPC rule -l | grep -c "^kitty:\*:\* => desktop=$D237 sticky=on\$")"
drop_tail "the two consequences filling the effect are removed"

# `rule -r` takes back the cause `rule -l` prints, in either form, so that
# listing a rule, copying its cause and removing it works for conditions
# too. The cause is compared whole: a rule with one more condition, or a
# different case marker, is a different rule and stays.
assert_ok "add a rule to remove by its conditions" \
	$BSPC rule -a class=kitty 'instance~=^crx_/i' state=floating
drop_cause "a rule is removed by the conditions rule -l prints for it" \
	'class=kitty instance~=^crx_/i'
assert_ok "add a rule with two conditions to keep" \
	$BSPC rule -a class=kitty instance=term state=floating
RM_BEFORE=$($BSPC rule -l | wc -l)
$BSPC rule -r class=kitty
assert_eq "a cause does not remove a rule with more conditions" "$RM_BEFORE" \
	"$($BSPC rule -l | wc -l)"
$BSPC rule -r class=kitty/i
assert_eq "nor one with a different case marker" "$RM_BEFORE" \
	"$($BSPC rule -l | wc -l)"
drop_cause "the rule with two conditions is removed by its own cause" \
	'class=kitty instance=term'

# The old field-by-field removal reaches rules written as conditions too,
# as the manual says: a pattern compares the class, instance and name
# patterns, whatever operator they were written with.
assert_ok "add a rule with conditions to remove by pattern" \
	$BSPC rule -a class=kitty state=floating
drop_cause "an old-form pattern removes a rule written as conditions" 'kitty:*:*'

# Everything that must be refused, with the rule never added. Chromium is
# still the only rule on the list, so a real BEFORE also proves a refusal
# does not disturb what was already there.
BEFORE=$($BSPC rule -l | wc -l)
assert_fail "reject a broken regular expression" $BSPC rule -a 'class~=^(eog' state=floating
assert_fail "a lone * is not a regular expression" $BSPC rule -a 'class~=*' state=floating
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
# type and transient are compared as written: a case marker on them would
# do nothing and could not be listed back, so it is refused like `~=` is.
assert_fail "reject a case marker on the type" $BSPC rule -a type=dialog/i center=on
assert_fail "reject a case marker on transient" $BSPC rule -a transient=on/i center=on

LONG=$(printf '%0300d' 0 | tr 0 a)
assert_fail "reject a value longer than the pattern buffer" \
	$BSPC rule -a "class=$LONG" state=floating
assert_fail "a value too long is refused even when it ends in /i" \
	$BSPC rule -a "class=$LONG/i" state=floating

# One character past the effect, or a consequence left with no room at all,
# is refused rather than cut short in silence: the rule would otherwise be
# added, exit 0, and do less than it was asked to.
D248=$(printf '%0248d' 0 | tr 0 d)
assert_fail "reject a consequence one character longer than the effect" \
	$BSPC rule -a class=kitty "desktop=$D248"
assert_fail "the old form refuses it too" \
	$BSPC rule -a kitty "desktop=$D248"
C60=$(printf '%060d' 0 | tr 0 d)
assert_fail "reject consequences that do not fit the effect together" \
	$BSPC rule -a class=kitty "desktop=$C60" "monitor=$C60" "node=$C60" \
	"rectangle=$C60" sticky=on
assert_fail "the old form refuses them together too" \
	$BSPC rule -a kitty "desktop=$C60" "monitor=$C60" "node=$C60" \
	"rectangle=$C60" sticky=on

P250=$(printf '%0250d' 0 | tr 0 b)
assert_fail "reject a rule whose conditions do not fit the listing" \
	$BSPC rule -a "class=$P250" "instance=$P250" "name=$P250" state=floating

assert_eq "a refused rule is not added" "$BEFORE" "$($BSPC rule -l | wc -l)"

# Chromium was needed all the way through the block above; drop it now.
drop_tail "the old-form Chromium rule is removed"

# The old catch-all still removes every rule, whatever form it was written in.
assert_ok "add a rule with conditions to sweep" $BSPC rule -a class=kitty state=floating
assert_ok "add an old-form rule to sweep" $BSPC rule -a kitty state=floating
$BSPC rule -r '*:*:*'
assert_eq "*:*:* removes the rules of both forms" "0" "$($BSPC rule -l | wc -l)"

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
	drop_tail "the case insensitive rule is removed after the window test"

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
	drop_tail "the web app rule is removed after the window test"

	# Criterion 3 of the design: class AND instance together, the real-world
	# case. class=Google-chrome alone would also match the plain browser
	# window below; only the pair of conditions tells the PWA apart from it.
	assert_ok "add the two-condition Chrome PWA rule" \
		$BSPC rule -a class=Google-chrome 'instance~=^crx_' state=floating
	./test_window crx_abcdef Google-chrome >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "the PWA matches both conditions" "floating" "$(rule_state "$W")"
	$BSPC node "$W" -c || true
	sleep 0.3
	./test_window google-chrome Google-chrome >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "the plain browser window, same class, does not" "tiled" "$(rule_state "$W")"
	$BSPC node "$W" -c || true
	sleep 0.3
	drop_tail "the two-condition PWA rule is removed after the window test"

	# The role. WM_WINDOW_ROLE is only read when some rule asks for it, so
	# the role rule goes behind one that does not: the role has to be read
	# because of a rule anywhere on the list, not just the first one.
	assert_ok "add a rule that does not look at the role" \
		$BSPC rule -a class=RmOther sticky=on
	assert_ok "add the role rule" $BSPC rule -a role=pop-up sticky=on
	./test_window rm-role RmRole --role pop-up >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "a window with that role is sticky" "true" "$(rule_flag "$W" sticky)"
	$BSPC node "$W" -c || true
	sleep 0.3
	drop_tail "the role rule is removed after the window test"
	# With no rule asking for it, the role is not read, and the window is
	# left alone.
	./test_window rm-role RmRole --role pop-up >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "with no role rule left, the same window is not sticky" "false" \
		"$(rule_flag "$W" sticky)"
	$BSPC node "$W" -c || true
	sleep 0.3
	drop_tail "the rule that does not look at the role is removed"

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
	drop_tail "the dialog rule is removed after the window test"

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
	drop_tail "the child window rule is removed after the window test"
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: rule conditions against real windows (needs X11 and test_window)"
fi
