# Rule conditions: how a rule picks the windows it applies to.

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
assert_eq "a refused rule is not added" "$BEFORE" "$($BSPC rule -l | wc -l)"

# Chromium was needed all the way through the block above; drop it now.
$BSPC rule -r tail || true
