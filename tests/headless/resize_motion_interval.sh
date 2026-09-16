# A separate pointer motion interval for resizing.

echo ""
echo "== Resize motion interval =="

assert_eq "the resize interval defaults to 17" "17" "$($BSPC config pointer_motion_interval_resize 2>/dev/null)"
assert_ok "set the resize interval" $BSPC config pointer_motion_interval_resize 5
assert_eq "the resize interval was set" "5" "$($BSPC config pointer_motion_interval_resize 2>/dev/null)"
assert_eq "the move interval is left alone" "17" "$($BSPC config pointer_motion_interval 2>/dev/null)"
assert_fail "reject a resize interval that is not a number" $BSPC config pointer_motion_interval_resize fast
$BSPC config pointer_motion_interval_resize 17 || true
