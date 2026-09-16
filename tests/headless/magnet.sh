# Magnetic edges: window edges stick while moving or resizing with the pointer.

echo ""
echo "== Magnetic edges =="

assert_ok "magnet unit tests pass" ./test_magnet

assert_eq "magnet is off by default" "0" "$($BSPC config magnet_threshold 2>/dev/null)"
assert_ok "set the magnet threshold" $BSPC config magnet_threshold 20
assert_eq "magnet threshold was set" "20" "$($BSPC config magnet_threshold 2>/dev/null)"
assert_ok "accept a magnet threshold of 0" $BSPC config magnet_threshold 0
assert_fail "reject a magnet threshold above 100" $BSPC config magnet_threshold 101
assert_fail "reject a negative magnet threshold" $BSPC config magnet_threshold -1
