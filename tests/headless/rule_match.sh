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
