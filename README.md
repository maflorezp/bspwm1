<h1 align="center">bspwm-ng</h1>

<p align="center">
The continuation of bspwm: floating windows that <b>stick while you drag them</b>
and move in exact steps, an Aero Snap you can tune, and window rules that match on
more than a class name.
</p>

<p align="center">
<a href="#edge-magnetism">Magnetism</a> ·
<a href="#aero-snap-zones-and-preview">Snap zones</a> ·
<a href="#stepped-drags">Steps</a> ·
<a href="#window-rules-with-properties">Rules</a> ·
<a href="#ported-fixes">Ported fixes</a> ·
<a href="#install">Install</a> ·
<a href="#configuration">Configuration</a> ·
<a href="#lineage">Lineage</a>
</p>

---

bspwm-ng grew out of [rotkonetworks/bspwm1](https://github.com/rotkonetworks/bspwm1), itself a
hardened fork of [baskerville/bspwm](https://github.com/baskerville/bspwm), and goes its own way
from here. Everything bspwm1 does is still in it — its README is [right next door](README.bspwm1.md).
What follows is what bspwm-ng adds.

Every feature below ships with tests: **352 of them**, headless, under `make test`. Each change
lives on its own branch before it is merged into `local`, the branch releases are cut from.

<!-- GIF principal: quítale el comentario cuando lo grabes (guía: docs/maflorezp/2026-09-17-grabar-los-gif.md)
<p align="center"><img src="docs/media/demo.gif" alt="Demo" width="820"></p>
-->

## Edge magnetism

<!-- GIF: magnetism
<p align="center"><img src="docs/media/magnet.gif" alt="A floating window sticking to its neighbours" width="720"></p>
-->

Drag a floating window and its edges **stick** to the work area and to the other windows on the
desktop as they come within reach — edge against edge, or lined up with a neighbour's same edge.
It happens live, inside the drag loop, not when you let go. A window only attracts along one axis
while it sits beside the dragged one on the other axis, so nothing pulls at you from across the
screen. Keep dragging to break free.

Only windows you can see count: hidden ones, and windows on other desktops, never pull.

```sh
bspc config magnet_threshold 30   # pixels; 0 turns it off, and is the default
```

Resizing sticks too — the edge you drag snaps to whatever lines up with it.

X11 only.

## Aero Snap zones and preview

<!-- GIF: snap zones
<p align="center"><img src="docs/media/snap-zones.gif" alt="Snap zones and the drag preview" width="720"></p>
-->

Upstream's snap zones ask for precision: a corner needs the pointer against both edges at once,
the whole top edge maximizes, and the bottom edge does nothing. One setting turns them into zones
you can hit without aiming:

```sh
bspc config edge_snap_zone_ratio 0.2   # 0 to 0.5; 0 keeps the classic behaviour
```

At `0.2`, the outer fifth of every edge belongs to the corner next to it, a centered band on the
top edge maximizes while the rest of that edge takes the top half, the bottom edge takes the
bottom half, and the sides take the left and right halves.

The region you are about to land in is drawn while you drag, in your colour:

```sh
bspc config edge_snap_preview_color '#04dd29'
bspc config edge_snap_preview_opacity 25     # 0-100; a compositor makes it translucent
```

X11 only.

## Stepped drags

Once a drag is under way, hold **Shift** and the window moves or resizes in steps of 10 pixels;
hold **Control** for steps of 50. The steps count from where the window was when you pressed the
key, so an odd size stays odd and only the stride changes. Let go and it follows the pointer
again. The magnet and the snap zones stay out of a stepped drag.

```sh
bspc config pointer_increment              10
bspc config pointer_big_increment          50
bspc config pointer_increment_modifier     shift     # none turns it off
bspc config pointer_big_increment_modifier control
```

Modifiers can be written as `alt`, `ctrl` and `super`, here and in `pointer_modifier`, the same
names sxhkd uses.

X11 only.

## Window rules with properties

Upstream matches a window by `CLASS:INSTANCE:NAME`, compared literally. That means one rule per
application, a rule that silently never fires because the class turned out to be `Pavucontrol`
and you wrote `pavucontrol`, and no way at all to reach a dialog or a Chrome web app.

This fork adds conditions:

```sh
# Case-insensitive: the /i suffix belongs to the value
bspc rule -a class=Pavucontrol/i state=floating

# A POSIX extended regular expression: ~= instead of =
bspc rule -a 'class~=^(eog|feh|ristretto)$' state=floating focus=on

# Every Chrome web app in one rule, instead of one rule per crx_ id
bspc rule -a class=Google-chrome instance~=^crx_ state=floating center=on

# _NET_WM_WINDOW_TYPE: dialogs stop taking over a monocle desktop
bspc rule -a type=dialog state=floating center=on

# WM_WINDOW_ROLE: Chrome's pop-ups never declare themselves as dialogs
bspc rule -a class=Google-chrome role=pop-up state=floating center=on

# Child windows
bspc rule -a transient=on state=floating
```

The properties are `class`, `instance`, `name` (the title), `type`, `role` and `transient`. A rule
matches when every condition holds; a rule with no conditions at all matches every window.
`bspc rule -l` prints a rule exactly as it was written, and `bspc rule -r` takes that same line
back. A key that is neither a property nor an effect, a broken regular expression, or a repeated
condition is refused on the spot, instead of becoming a rule that quietly never fires.

The old `CLASS:INSTANCE:NAME` form keeps working, untouched — including a title with an `=` in it.

> The author's own config went from **95 rules to 29**, and the mismatched-case rule that had not
> fired in years finally did.

## Ported fixes

Four pull requests that have been waiting upstream, rebased onto bspwm1 and given tests:

| Upstream PR | What it fixes |
|---|---|
| [#1541](https://github.com/baskerville/bspwm/pull/1541) | Focusing a desktop or a monitor no longer raises the focused window above the rest |
| [#1284](https://github.com/baskerville/bspwm/pull/1284) | `pointer_motion_interval_resize`, so applications that redraw slowly stop lagging behind a resize |
| [#1035](https://github.com/baskerville/bspwm/pull/1035) | `WM_CHANGE_STATE`: minimize and restore work with taskbars and pagers |
| [#1183](https://github.com/baskerville/bspwm/pull/1183) | `_NET_WM_MOVERESIZE`: clients that draw their own title bar can move and resize themselves |

And three bugs fixed along the way:

- The focus stayed behind when a window was sent to another monitor with `follow=on`.
- The `automatic` node selector matched the wrong way round, so a new window could land on the
  desktop you had just left.
- A window its client had withdrawn — a tray application hiding in the tray, say — came back after
  `bspc wm -r` as an empty frame that took the focus and followed you across desktops.

## Install

### Arch Linux

```sh
yay -S bspwm-ng-git
```

It replaces `bspwm`, `bspwm1` and the package's old name, `bspwm1-maflorezp-git`, and tracks the
`local` branch — every feature above, merged. The binaries are still `bspwm` and `bspc`, so your
`bspwmrc`, sxhkd bindings and scripts keep working as they are.

### From source

```sh
git clone -b local https://github.com/maflorezp/bspwm-ng.git
cd bspwm-ng
make && sudo make install
make test          # 352 headless tests
```

Needs `libxcb`, `xcb-util`, `xcb-util-keysyms`, `xcb-util-wm` and `libxkbcommon`. The wlroots
backend upstream ships is built separately; see [its README](README.bspwm1.md).

## Configuration

Everything this fork adds, in one block, with the values it ships with:

```sh
bspc config magnet_threshold               0         # 30 is a comfortable value
bspc config edge_snap_zone_ratio           0.0       # 0.2 gives generous corners
bspc config edge_snap_preview_color        '#E6007A'
bspc config edge_snap_preview_opacity      25
bspc config pointer_motion_interval_resize 17        # raise it for slow-redrawing apps
bspc config pointer_increment              10
bspc config pointer_big_increment          50
bspc config pointer_increment_modifier     shift
bspc config pointer_big_increment_modifier control
```

`man bspwm` documents each one, with the exact geometry of the snap zones and the full grammar of
the rule conditions.

## Lineage

```
baskerville/bspwm  →  rotkonetworks/bspwm1  →  maflorezp/bspwm-ng
    the original      hardening, wlroots       everything above
```

The hardening, the memory-safety work and the wlroots backend are bspwm1's; bspwm itself is
Bastien Dejean's. The ported pull requests keep their original authors in the commit history.

BSD-2-Clause, like bspwm.
