# Edge snap preview: color and opacity settings, and a translucent window.

echo ""
echo "== Edge snap preview =="

assert_ok "color_premultiply unit tests pass" ./test_color

assert_eq "preview color defaults to pink" "#E6007A" "$($BSPC config edge_snap_preview_color 2>/dev/null)"
assert_eq "preview opacity defaults to 25" "25" "$($BSPC config edge_snap_preview_opacity 2>/dev/null)"
assert_ok "set the preview color" $BSPC config edge_snap_preview_color '#00ff00'
assert_eq "preview color was set" "#00ff00" "$($BSPC config edge_snap_preview_color 2>/dev/null)"
assert_fail "reject a preview color that is not hex" $BSPC config edge_snap_preview_color pink
assert_ok "accept preview opacity 0" $BSPC config edge_snap_preview_opacity 0
assert_ok "accept preview opacity 100" $BSPC config edge_snap_preview_opacity 100
assert_fail "reject preview opacity above 100" $BSPC config edge_snap_preview_opacity 101
assert_fail "reject a negative preview opacity" $BSPC config edge_snap_preview_opacity -1
assert_ok "set the preview opacity" $BSPC config edge_snap_preview_opacity 50
assert_eq "preview opacity was set" "50" "$($BSPC config edge_snap_preview_opacity 2>/dev/null)"
