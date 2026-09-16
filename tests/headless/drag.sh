# Pointer drag helpers for the headless X11 suite.
#
# Geometry is read from X, not from bspc: bspwm serves no IPC while it holds a
# pointer grab, so a bspc query in the middle of a drag would block until the
# button is released.

# True when the tools the drag tests need are available.
drag_tools_available() {
	[ "$BACKEND" = "x11" ] && [ -f ./test_window ] &&
		command -v xdotool >/dev/null 2>&1 &&
		command -v xwininfo >/dev/null 2>&1
}

# Print "x y width height" of a window: outer corner, inner size.
win_geom() {
	xwininfo -id "$1" | awk '
		/Absolute upper-left X/ { x = $NF }
		/Absolute upper-left Y/ { y = $NF }
		/Width:/ { w = $NF }
		/Height:/ { h = $NF }
		END { print x, y, w, h }'
}

# Map a floating test window with the given rectangle and print its id.
spawn_floating() {
	local name="$1" rect="$2"
	$BSPC rule -a "Drag:$name" -o state=floating rectangle="$rect"
	./test_window "$name" Drag >/dev/null 2>&1 &
	sleep 0.5
	$BSPC query -N -n focused
}

# Pointer bindings the drag tests rely on.
drag_setup() {
	$BSPC config pointer_modifier mod1
	$BSPC config pointer_action1 move
	$BSPC config pointer_action2 resize_side
	$BSPC config pointer_action3 resize_corner
	$BSPC config border_width 2
}

# Hold the modifier and press a button at (x, y).
drag_begin() {
	xdotool mousemove "$2" "$3"
	sleep 0.1
	xdotool keydown alt
	xdotool mousedown "$1"
	sleep 0.2
}

# Move the pointer while the button is held.
drag_to() {
	xdotool mousemove "$1" "$2"
	sleep 0.2
}

# Release the button and the modifier.
drag_end() {
	xdotool mouseup "$1"
	xdotool keyup alt
	sleep 0.3
}
