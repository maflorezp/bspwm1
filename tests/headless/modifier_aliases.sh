# Modifier aliases: alt, ctrl and super, the names sxhkd and bspc keybind use,
# are accepted wherever a pointer setting takes a modifier. Reading the setting
# back gives the canonical name, so scripts that read it keep working.

echo ""
echo "== Modifier aliases =="

ALIAS_POINTER_MODIFIER=$($BSPC config pointer_modifier 2>/dev/null)

# Start from something else, or reading back mod1 would prove nothing.
$BSPC config pointer_modifier mod5
assert_ok "alt is accepted as the drag modifier" $BSPC config pointer_modifier alt
assert_eq "alt reads back as mod1" "mod1" "$($BSPC config pointer_modifier 2>/dev/null)"
assert_ok "super is accepted as the drag modifier" $BSPC config pointer_modifier super
assert_eq "super reads back as mod4" "mod4" "$($BSPC config pointer_modifier 2>/dev/null)"
assert_ok "ctrl is accepted as the drag modifier" $BSPC config pointer_modifier ctrl
assert_eq "ctrl reads back as control" "control" "$($BSPC config pointer_modifier 2>/dev/null)"

assert_ok "alt is accepted as the increment modifier" $BSPC config pointer_increment_modifier alt
assert_eq "the increment modifier reads back as mod1" "mod1" \
	"$($BSPC config pointer_increment_modifier 2>/dev/null)"
assert_ok "super is accepted as the big increment modifier" $BSPC config pointer_big_increment_modifier super
assert_eq "the big increment modifier reads back as mod4" "mod4" \
	"$($BSPC config pointer_big_increment_modifier 2>/dev/null)"

$BSPC config pointer_modifier "$ALIAS_POINTER_MODIFIER"
$BSPC config pointer_increment_modifier shift
$BSPC config pointer_big_increment_modifier control
