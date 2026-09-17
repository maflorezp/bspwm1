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
assert_ok "add a rule the old way" $BSPC rule -a Chromium state=floating

assert_ok "add a rule with conditions" \
	$BSPC rule -a class=Pavucontrol/i state=floating
$BSPC rule -r tail || true
assert_ok "add a rule with a regular expression" \
	$BSPC rule -a 'class~=^(eog|feh)$' state=floating
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

# The old form's rule was checked already; drop it before the next block.
$BSPC rule -r tail || true

# Everything that must be refused, with the rule never added.
BEFORE=$($BSPC rule -l | wc -l)
assert_fail "reject a broken regular expression" $BSPC rule -a 'class~=^(eog' state=floating
assert_fail "reject an unknown window type" $BSPC rule -a type=popup state=floating
assert_fail "reject an unknown key" $BSPC rule -a clas=kitty state=floating
assert_fail "reject a repeated condition" $BSPC rule -a class=a class=b state=floating
assert_fail "reject an unknown consequence" $BSPC rule -a class=kitty staet=floating
assert_fail "reject an unknown consequence in the old form" $BSPC rule -a kitty staet=floating
assert_eq "a refused rule is not added" "$BEFORE" "$($BSPC rule -l | wc -l)"
