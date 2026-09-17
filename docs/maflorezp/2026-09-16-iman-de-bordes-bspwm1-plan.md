# Imán de bordes, vista previa y PRs de bspwm original sobre bspwm1 — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un fork público de bspwm1 con imán de bordes en vivo, vista previa del Aero Snap
configurable y translúcida, zonas del Aero Snap con cuartos y mitades superior e inferior, y
cuatro PRs de bspwm original portados, instalado en la sesión de
Mauricio como el paquete `bspwm1-maflorezp-git`.

**Architecture:** Cada cambio vive en su propia rama, sacada de `upstream/master`, lista para
proponerse más adelante. La rama `local` las funde todas, es la rama por defecto del fork y es
la que compila el paquete. El cálculo del imán y del color premultiplicado va en módulos puros
de C (`magnet.c`, `color.c`, `edge_zone.c`) con pruebas unitarias. `pointer.c` solo los conecta con X. Las
pruebas de comportamiento corren en el ejecutor de bspwm1 (`make test` → `tests/run_headless`),
sobre Xvfb, con arrastres de `xdotool` y consultando a X con el botón todavía pulsado.

**Tech Stack:** C23 (gcc), xcb, bspwm1 v1.6.2 (rotkonetworks), Xvfb, xdotool, xwininfo, xwd,
asciidoc (`a2x`), makepkg, bash/sh, gh.

**Spec:** `docs/maflorezp/2026-09-16-iman-de-bordes-bspwm1-diseno.md`

## Cómo se prueba esto

- **En el fork**, cada tarea empieza escribiendo una prueba que falla, dentro del ejecutor de
  bspwm1. Las unitarias son programas C en `tests/`, que `tests/Makefile` compila y los ficheros
  de `tests/headless/` ejecutan. Las de comportamiento son esos mismos ficheros `.sh`, que
  `tests/run_headless` carga con `.`. `make test` en la raíz compila todo, arranca Xvfb y un
  bspwm aislado, y sale con código distinto de cero si algo falla. El resumen está en sus
  últimas líneas: `ALL GREEN: N/N tests passed (x11)` o `RED: …`.
- **En la sesión real** solo se toca algo en las tareas 17 a 19, y cada acción que mueva el
  ratón o reinicie bspwm se pide antes a Mauricio. Van marcadas **[SESIÓN]**.
- **La salida esperada** de cada comando está escrita en su paso. Si una prueba que debía
  fallar pasa (o al revés), **para y avisa**: no se debilita la prueba para que cuadre.

## Global Constraints

- **Ubicación:** el fork `maflorezp/bspwm1` (público) se clona en `/websites/personal/bspwm`.
  Remotos: `origin` (el fork), `upstream` (`https://github.com/rotkonetworks/bspwm1.git`) y
  `baskerville` (`https://github.com/baskerville/bspwm.git`).
- **Ramas** (nombres exactos): `edge-snap-preview-color`, `magnet-edges`, `edge-snap-zones`,
  `upstream-1541-no-raise-on-focus`, `upstream-1284-resize-motion-interval`,
  `upstream-1035-iconify`, `upstream-1183-net-wm-moveresize`, y `local`, que las funde y es la
  rama por defecto del fork. Todas salen de `upstream/master`.
- **Todo lo que va al fork sigue las convenciones de bspwm1:**
  - En inglés: identificadores, **comentarios** y mensajes de commit.
  - Comentarios solo `/* */`, tabuladores, C23.
  - Sin avisos nuevos con los `CFLAGS` del `Makefile`.
  - Conventional Commits (`feat:`, `fix:`, `test:`, `docs:`, `ci:`, `refactor:`). Las pruebas
    van en commits separados del código.
  - **No se tocan `doc/CHANGELOG.md` ni `VERSION`.**
  - **Nunca** se añade un trailer de Claude (`Co-Authored-By`).
- **Excepción de idioma:** solo los commits de la tarea 20, que son documentación propia en la
  rama `local`, van en español.
- **Identidad de los commits en el fork:**
  `Mauricio Alexander Flórez <maflorezp@gmail.com>`, configurada solo
  en ese repositorio. Los ports de bspwm original conservan como autor a su autor original.
- **Ajustes nuevos** (valores exactos):
  - `magnet_threshold`: entero 0–100, por defecto `0`;
  - `edge_snap_preview_color`: `#RRGGBB`, por defecto `#E6007A`;
  - `edge_snap_preview_opacity`: entero 0–100, por defecto `25`;
  - `pointer_motion_interval_resize`: entero sin signo, por defecto `17`;
  - `allow_net_wm_moveresize`: booleano, por defecto `true`;
  - `edge_snap_zone_ratio`: decimal 0–0.5, por defecto `0` (zonas clásicas).
- **Paquete:** `bspwm1-maflorezp-git`, con `provides=('bspwm' 'bspwm1')` y
  `conflicts=('bspwm' 'bspwm1')`. Vive en `~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/` y
  compila la rama `local` del fork.
- **Configuración propia:** `magnet_threshold 20`, `edge_snap_preview_color '#04dd29'`,
  `edge_snap_preview_opacity 25` y `edge_snap_zone_ratio 0.2`.
- **Las pruebas de `run_headless` corren con `set -e`:** una orden suelta que falle aborta la
  suite entera. Toda orden que pueda fallar en la fase roja va dentro de un `assert_*` o
  termina en `|| true`.
- **Lo propio va en español:** PKGBUILD, `build.sh`, `.gitignore` y dotfiles.
- **Los PRs no se abren en este plan.** Los abre Mauricio tras unas semanas de uso.
- **En la shell de Mauricio `rm` es `rm -i`:** en comandos no interactivos se usa `command rm`.
- **`sudo` lo ejecuta Mauricio**, nunca el agente.

## Mapa de ficheros

En `/websites/personal/bspwm` (fork):

| Fichero | Qué hace | Tarea |
|---|---|---|
| `src/color.c`, `src/color.h` (nuevos) | `color_premultiply()`: píxel ARGB premultiplicado | 2 |
| `tests/test_color.c` (nuevo) | Pruebas unitarias de `color.c` | 2 |
| `src/settings.h`, `src/settings.c`, `src/messages.c` | Declarar, inicializar, leer y escribir los ajustes nuevos | 3, 6, 11, 13, 15 |
| `doc/bspwm.1.asciidoc`, `doc/bspwm.1` | Manual de cada ajuste nuevo | 3, 6, 11, 13, 15 |
| `contrib/{bash,fish,zsh}_completion` | Autocompletado de cada ajuste nuevo | 3, 6, 11, 13, 15 |
| `src/pointer.c`, `src/pointer.h` | Vista previa ARGB (4), imán (7, 8), intervalo de resize (11), inicio de arrastre compartido y `pointer_move_node()` (13), vista previa de las mitades superior e inferior (15) | 4, 7, 8, 11, 13, 15 |
| `src/magnet.c`, `src/magnet.h` (nuevos) | Cálculo puro del imán | 5 |
| `tests/test_magnet.c` (nuevo) | Pruebas unitarias de `magnet.c` | 5 |
| `src/edge_zone.c`, `src/edge_zone.h` (nuevos) | Qué zona del Aero Snap corresponde a una posición del puntero | 14 |
| `tests/test_edge_zone.c` (nuevo) | Pruebas unitarias de `edge_zone.c` | 14 |
| `src/snap.c` | `get_snap_zone` delega en `edge_zone_at` | 15 |
| `src/events.c` | #1541 (10), #1035 (12), `_NET_WM_MOVERESIZE` (13) | 10, 12, 13 |
| `src/backend_x11.c`, `src/backend_x11.h` | Átomo `WM_CHANGE_STATE` (12), `_NET_WM_MOVERESIZE` soportado (13) | 12, 13 |
| `tests/send_moveresize.c` (nuevo) | Cliente de prueba que pide un arrastre por `_NET_WM_MOVERESIZE` | 13 |
| `tests/headless/drag.sh` (nuevo) | Ayudantes de arrastre para las pruebas (idéntico en las ramas que lo usan) | 4, 7, 13, 15 |
| `tests/headless/*.sh` (nuevos) | Una sección de pruebas por cambio | 2–15 |
| `tests/run_headless` | Carga `drag.sh` y las secciones nuevas | 2–15 |
| `tests/Makefile`, `.gitignore` | Compilan e ignoran los binarios de prueba nuevos | 2, 5, 13, 14 |
| `Makefile` | `color.c`, `magnet.c` y `edge_zone.c` en `CORE_SRC` | 2, 5, 14 |
| `.github/workflows/release.yaml` | Instala `xdotool xorg-xwininfo xorg-xwd` para las pruebas de arrastre | 4, 7, 13, 15 |
| `docs/maflorezp/` (nuevo, solo en `local`) | Especificación y plan | 20 |

En `~/.dotFiles`:

| Fichero | Qué hace | Tarea |
|---|---|---|
| `pkgbuilds/bspwm1-maflorezp-git/PKGBUILD` (nuevo) | Paquete que compila la rama `local` | 17 |
| `pkgbuilds/bspwm1-maflorezp-git/build.sh` (nuevo) | Llama a makepkg con los directorios de trabajo en `~/.cache/pkgbuilds` | 17 |
| `pkgbuilds/bspwm1-maflorezp-git/.gitignore` (nuevo) | Red de seguridad contra artefactos de makepkg | 17 |
| `.config/bspwm/bspwm_config.sh` | Los cuatro ajustes propios | 18 |
| `.config/bspwm/bspwm_subscribers.sh` | Quitar el imán de bash | 19 |
| `.config/bspwm/bspwm_snap.sh`, `.config/bspwm/bspwm_snap-tests/` | Se borran | 19 |
| `docs/superpowers/{specs,plans}/2026-09-16-iman-de-bordes-bspwm1*` | Se mudan al fork | 20 |

**Conflictos esperados al fundir en `local` (tarea 16).** Varias ramas insertan líneas en los
mismos sitios: listas de ajustes, autocompletados, manual, `tests/Makefile`, `.gitignore`,
`tests/run_headless` y `pointer.c`. La regla es **conservar todas las inserciones**, en el orden
en que se funden las ramas. Los cambios idénticos (`tests/headless/drag.sh`, la línea
`. ./headless/drag.sh` y la línea de dependencias de CI) se funden solos.

---

### Task 1: Fork, clon y línea base

**Files:**
- Create: `/websites/personal/bspwm` (clon)

**Interfaces:**
- Produces: el clon con los remotos `origin`, `upstream` y `baskerville`, y `make test` en
  verde sobre `upstream/master`.

- [ ] **Step 1: Pedir a Mauricio las dependencias de desarrollo**

Díselo tal cual y espera a que confirme:

```bash
sudo pacman -S --needed asciidoc
# Opcional, solo para compilar el backend Wayland antes de abrir PRs:
sudo pacman -S --needed wlroots0.20 wlr-protocols
```

Después comprueba:

```bash
command -v a2x xdotool xwininfo xwd Xvfb
```

Expected: cinco rutas.

- [ ] **Step 2: Confirmar la identidad de los commits**

Pregunta a Mauricio si los commits del fork deben usar
`maflorezp@gmail.com` (su correo global de git es el de la empresa y
quedaría público). No sigas hasta tener respuesta.

- [ ] **Step 3: Crear el fork y clonarlo**

```bash
gh repo fork rotkonetworks/bspwm1 --clone=false
gh repo view maflorezp/bspwm1 --json visibility,parent \
  --jq '"\(.visibility) \(.parent.owner.login)/\(.parent.name)"'
```

Expected: `PUBLIC rotkonetworks/bspwm1`

```bash
git clone https://github.com/maflorezp/bspwm1.git /websites/personal/bspwm
cd /websites/personal/bspwm
git remote add upstream https://github.com/rotkonetworks/bspwm1.git
git remote add baskerville https://github.com/baskerville/bspwm.git
git fetch upstream --tags
git fetch baskerville master
git config user.name "Mauricio Alexander Flórez"
git config user.email "maflorezp@gmail.com"   # o la que diga Mauricio
git log -1 --format='%h %s' upstream/master
```

Expected: `4cc03f1 chore: bump version to 1.6.2`, o un commit posterior. Si es posterior, apunta
el hash: todas las ramas salen de ahí.

- [ ] **Step 4: Línea base**

```bash
cd /websites/personal/bspwm
make 2>&1 | grep -iE "warning|error" ; echo "avisos: $?"
make test 2>&1 | tail -n 3
```

Expected: `avisos: 1` (grep no encuentra nada) y `ALL GREEN: N/N tests passed (x11)`. Apunta N:
es la base de comparación del resto del plan.

---

### Task 2: `color_premultiply` (rama `edge-snap-preview-color`)

**Files:**
- Create: `src/color.h`, `src/color.c`, `tests/test_color.c`, `tests/headless/edge_snap_preview.sh`
- Modify: `Makefile` (`CORE_SRC`), `tests/Makefile`, `tests/run_headless`, `.gitignore`

**Interfaces:**
- Produces: `uint32_t color_premultiply(uint32_t rgb, unsigned int opacity);` en `color.h`.
  Devuelve `0xAARRGGBB` con los canales premultiplicados. Ignora el byte alto de `rgb` y trata
  `opacity > 100` como 100.

- [ ] **Step 1: Crear la rama**

```bash
cd /websites/personal/bspwm
git switch -c edge-snap-preview-color upstream/master
```

- [ ] **Step 2: Escribir la prueba unitaria**

`tests/test_color.c`:

```c
/* Unit tests for color.c: premultiplied ARGB for translucent windows. */

#include <inttypes.h>
#include <stdio.h>
#include "../src/color.h"

static int failures;

static void check(const char *desc, uint32_t expected, uint32_t actual)
{
	if (expected == actual) {
		printf("  PASS: %s\n", desc);
		return;
	}
	printf("  FAIL: %s: expected 0x%08" PRIX32 ", got 0x%08" PRIX32 "\n",
	       desc, expected, actual);
	failures++;
}

int main(void)
{
	check("full opacity keeps the color and sets alpha",
	      0xFFE6007A, color_premultiply(0xE6007A, 100));
	check("zero opacity is transparent black",
	      0x00000000, color_premultiply(0xE6007A, 0));
	check("25% opacity scales every channel",
	      0x3F38001E, color_premultiply(0xE6007A, 25));
	check("50% green",
	      0x7F007F00, color_premultiply(0x00FF00, 50));
	check("opacity above 100 counts as 100",
	      0xFFE6007A, color_premultiply(0xE6007A, 250));
	check("the high byte of the input is ignored",
	      0x7F007F00, color_premultiply(0xFF00FF00, 50));
	return failures ? 1 : 0;
}
```

Añade a `tests/Makefile`, justo después de la línea `all: test_window test_window_wl`:

```make
all: test_color
```

y después de la regla de `test_window_wl` (antes de `clean:`):

```make
test_color: test_color.c ../src/color.c ../src/color.h
	$(CC) $(CFLAGS) -std=c23 -o $@ test_color.c ../src/color.c
```

En la regla `clean:`, cambia `$(RM) test_window test_window_wl *.o` por:

```make
	$(RM) test_window test_window_wl test_color test_magnet send_moveresize test_edge_zone *.o
```

(La misma línea exacta en las cuatro ramas que añaden binarios, para que se fundan sin
conflicto.)

En `.gitignore`, después de `tests/test_stress`, añade `tests/test_color`.

Crea `tests/headless/edge_snap_preview.sh`:

```sh
# Edge snap preview: color and opacity settings, and a translucent window.

echo ""
echo "== Edge snap preview =="

assert_ok "color_premultiply unit tests pass" ./test_color
```

En `tests/run_headless`, justo antes de la línea `# ---- Quit ----`, añade:

```sh
. ./headless/edge_snap_preview.sh
```

- [ ] **Step 3: Ver que falla**

```bash
cd /websites/personal/bspwm/tests && make test_color 2>&1 | tail -n 2
```

Expected: error de compilación, `../src/color.h: No such file or directory`.

Crea `src/color.h` con la cabecera BSD que llevan todos los ficheros de `src/` (cópiala de
`src/snap.h`, líneas 1–23) y después:

```c
#ifndef BSPWM_COLOR_H
#define BSPWM_COLOR_H

#include <stdint.h>

/* Pixel for a 32-bit ARGB window: `rgb` (0xRRGGBB, any high byte ignored) at
 * `opacity` percent, with the color channels premultiplied by alpha as
 * compositors expect. An opacity above 100 counts as 100. */
uint32_t color_premultiply(uint32_t rgb, unsigned int opacity);

#endif
```

Crea `src/color.c` con la misma cabecera BSD y un esqueleto que compile:

```c
#include "color.h"

uint32_t color_premultiply(uint32_t rgb, unsigned int opacity)
{
	(void) rgb;
	(void) opacity;
	return 0;
}
```

```bash
cd /websites/personal/bspwm/tests && make test_color >/dev/null && ./test_color; echo "salida: $?"
```

Expected: `FAIL` en todos los casos salvo «zero opacity is transparent black», y `salida: 1`.

- [ ] **Step 4: Implementar**

Sustituye el cuerpo en `src/color.c`:

```c
uint32_t color_premultiply(uint32_t rgb, unsigned int opacity)
{
	if (opacity > 100)
		opacity = 100;
	uint32_t a = opacity * 255 / 100;
	uint32_t r = ((rgb >> 16) & 0xFF) * a / 255;
	uint32_t g = ((rgb >> 8) & 0xFF) * a / 255;
	uint32_t b = (rgb & 0xFF) * a / 255;
	return a << 24 | r << 16 | g << 8 | b;
}
```

En el `Makefile` raíz, añade `color.c` al final de `CORE_SRC` (después de `snap.c`).

- [ ] **Step 5: Ver que pasa**

```bash
cd /websites/personal/bspwm/tests && make test_color >/dev/null && ./test_color; echo "salida: $?"
cd .. && make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "unit tests|ALL GREEN|RED:"
```

Expected: seis `PASS`, `salida: 0`, ningún aviso, `PASS: color_premultiply unit tests pass` y
`ALL GREEN`.

- [ ] **Step 6: Commits**

```bash
git add src/color.c src/color.h Makefile
git commit -m "feat: add color_premultiply for translucent ARGB windows"
git add tests/test_color.c tests/Makefile tests/headless/edge_snap_preview.sh tests/run_headless .gitignore
git commit -m "test: unit-test color_premultiply"
```

---

### Task 3: Ajustes `edge_snap_preview_color` y `edge_snap_preview_opacity` (rama `edge-snap-preview-color`)

**Files:**
- Modify: `src/settings.h`, `src/settings.c`, `src/messages.c`, `doc/bspwm.1.asciidoc`,
  `doc/bspwm.1`, `contrib/bash_completion`, `contrib/fish_completion`,
  `contrib/zsh_completion`, `tests/headless/edge_snap_preview.sh`

**Interfaces:**
- Produces: `extern char edge_snap_preview_color[MAXLEN];` y
  `extern int edge_snap_preview_opacity;` en `settings.h`, que usará la tarea 4.

- [ ] **Step 1: Escribir las pruebas**

Añade al final de `tests/headless/edge_snap_preview.sh`:

```sh
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
```

- [ ] **Step 2: Ver que falla**

```bash
cd /websites/personal/bspwm && make test 2>&1 | grep -E "preview (color|opacity)|RED:|ALL GREEN"
```

Expected: `FAIL` en los `assert_eq` y en los `assert_ok` de los ajustes, y `RED:` al final.

- [ ] **Step 3: Implementar**

`src/settings.h`: después de `#define EDGE_SNAP_THRESHOLD         20`:

```c
#define EDGE_SNAP_PREVIEW_COLOR     "#E6007A"
#define EDGE_SNAP_PREVIEW_OPACITY   25
```

y después de `extern int edge_snap_threshold;`:

```c
extern char edge_snap_preview_color[MAXLEN];
extern int edge_snap_preview_opacity;
```

`src/settings.c`: después de `int edge_snap_threshold;`:

```c
char edge_snap_preview_color[MAXLEN];
int edge_snap_preview_opacity;
```

y después de `edge_snap_threshold = EDGE_SNAP_THRESHOLD;`:

```c
	snprintf(edge_snap_preview_color, sizeof(edge_snap_preview_color), "%s", EDGE_SNAP_PREVIEW_COLOR);
	edge_snap_preview_opacity = EDGE_SNAP_PREVIEW_OPACITY;
```

`src/messages.c`, en `set_setting`:
- después de `	SET_COLOR(presel_feedback_color)` añade `	SET_COLOR(edge_snap_preview_color)`;
- después de la línea `		edge_snap_threshold = t;` añade:

```c
	} else if (streq("edge_snap_preview_opacity", name)) {
		int o;
		if (sscanf(value, "%i", &o) != 1 || o < 0 || o > 100) {
			fail(rsp, "config: %s: Invalid value: '%s' (must be 0-100).\n", name, value);
			return;
		}
		edge_snap_preview_opacity = o;
```

`src/messages.c`, en `get_setting`:
- después de `	GET_COLOR(presel_feedback_color)` añade `	GET_COLOR(edge_snap_preview_color)`;
- después de la línea `		fprintf(rsp, "%i", edge_snap_threshold);` añade:

```c
	} else if (streq("edge_snap_preview_opacity", name)) {
		fprintf(rsp, "%i", edge_snap_preview_opacity);
```

`doc/bspwm.1.asciidoc`: después de la entrada `'edge_snap_threshold'::` (y su línea en blanco):

```
'edge_snap_preview_color'::
	Color of the region shown while a drag is in a snap zone. X11 only. Defaults to *#E6007A*.

'edge_snap_preview_opacity'::
	Opacity of that region, from *0* to *100*. It only shows through with a compositor running; without one the region is drawn opaque. X11 only. Defaults to *25*.

```

Autocompletado:
- `contrib/bash_completion` y `contrib/fish_completion`: en la lista de ajustes, cambia
  `edge_snap_threshold cascade_offset` por
  `edge_snap_threshold edge_snap_preview_color edge_snap_preview_opacity cascade_offset`.
- `contrib/zsh_completion`: en el array `look=(...)`, añade al final
  `edge_snap_preview_color edge_snap_preview_opacity`.

Regenera el manual:

```bash
cd /websites/personal/bspwm && make doc VERCMD=false && git diff --stat doc/bspwm.1
```

Expected: solo cambia `doc/bspwm.1`, con unas pocas líneas añadidas. Si `a2x` reescribe mucho
más (otra versión de docbook), deshaz con `git checkout doc/bspwm.1` y añade las dos entradas a
mano, copiando el formato roff de la entrada `edge_snap_threshold` que ya hay en `doc/bspwm.1`.

- [ ] **Step 4: Ver que pasa**

```bash
cd /websites/personal/bspwm && make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "preview (color|opacity)|RED:|ALL GREEN"
```

Expected: ningún aviso, todos `PASS` y `ALL GREEN`.

- [ ] **Step 5: Commits**

```bash
git add src/settings.h src/settings.c src/messages.c doc/bspwm.1.asciidoc doc/bspwm.1 contrib/
git commit -m "feat: add edge_snap_preview_color and edge_snap_preview_opacity"
git add tests/headless/edge_snap_preview.sh
git commit -m "test: cover the edge snap preview settings"
```

---

### Task 4: Vista previa translúcida en un visual de 32 bits (rama `edge-snap-preview-color`)

**Files:**
- Create: `tests/headless/drag.sh`
- Modify: `src/pointer.c` (`show_snap_preview`, `destroy_snap_preview`, variables de la vista
  previa), `tests/headless/edge_snap_preview.sh`, `tests/run_headless`,
  `.github/workflows/release.yaml`

**Interfaces:**
- Consumes: `color_premultiply()` (tarea 2), `edge_snap_preview_color` y
  `edge_snap_preview_opacity` (tarea 3), `backend_get_color_pixel(const char *)` (de
  `backend.h`, devuelve `0xFFRRGGBB`), `screen` (de `backend_x11.h`).
- Produces: `tests/headless/drag.sh` con `drag_tools_available`, `win_geom ID`,
  `spawn_floating NAME WxH+X+Y`, `drag_setup`, `drag_begin BUTTON X Y`, `drag_to X Y` y
  `drag_end BUTTON`. Las tareas 7, 8, 13 y 15 lo usan **idéntico**.

- [ ] **Step 1: Ayudantes de arrastre**

Crea `tests/headless/drag.sh` (este contenido exacto, también en las tareas 7, 13 y 15):

```sh
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
```

En `tests/run_headless`, justo antes de la línea `# ---- TESTS ----`, añade:

```sh
. ./headless/drag.sh
```

En `.github/workflows/release.yaml`, en la orden `pacman -Syu --noconfirm …` del paso
`Install dependencies`, cambia `xorg-server-xvfb xorg-fonts-misc` por
`xorg-server-xvfb xorg-fonts-misc xdotool xorg-xwininfo xorg-xwd` (la misma edición exacta en
las tareas 7, 13 y 15).

- [ ] **Step 2: Escribir la prueba**

Añade al final de `tests/headless/edge_snap_preview.sh`:

```sh
# Id of the preview: the mapped, override-redirect, unnamed InputOutput child
# of the root window.
preview_window() {
	for w in $(xwininfo -root -children | awk '/^ +0x/ && /\(has no name\)/ {print $1}'); do
		info=$(xwininfo -id "$w")
		echo "$info" | grep -q 'Map State: IsViewable' || continue
		echo "$info" | grep -q 'Override Redirect State: yes' || continue
		echo "$info" | grep -q 'Class: InputOutput' || continue
		echo "$w"
		return
	done
}

if drag_tools_available && command -v xwd >/dev/null 2>&1; then
	drag_setup
	$BSPC config edge_snap_enabled true
	W=$(spawn_floating preview 400x300+700+400)

	# Push the pointer against the left edge and keep the button down.
	drag_begin 1 900 550
	drag_to 5 550
	P=$(preview_window)
	assert_not_empty "preview is mapped while dragging into a zone" "$P"
	assert_eq "preview uses a 32-bit visual" "32" \
		"$(xwininfo -id "$P" | awk '/Depth:/ {print $NF}')"
	# Last pixel inside the border, as stored by xwd: B G R A.
	assert_eq "preview fill is #00ff00 at 50%, premultiplied" "007f007f" \
		"$(xwd -id "$P" -silent -nobdrs | tail -c 4 | od -An -tx1 | tr -d ' \n')"
	drag_end 1
	$BSPC node "$W" -c
	sleep 0.3
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: preview rendering (needs X11, test_window, xdotool, xwininfo, xwd)"
fi

$BSPC config edge_snap_preview_color '#E6007A'
$BSPC config edge_snap_preview_opacity 25
```

(Cuando se ejecuta este bloque, la tarea 3 ya dejó el color en `#00ff00` y la opacidad en
`50`.)

- [ ] **Step 3: Ver que falla**

```bash
cd /websites/personal/bspwm && make test 2>&1 | grep -E "preview (is mapped|uses|fill)|RED:|ALL GREEN"
```

Expected: `PASS: preview is mapped…`, `FAIL: preview uses a 32-bit visual` (actual `24`), `FAIL:
preview fill…` y `RED:`.

- [ ] **Step 4: Implementar**

`src/pointer.c`:
- añade `#include "color.h"` junto a los demás `#include "…"`;
- después de `static bspwm_wid_t snap_preview_win = BSPWM_WID_NONE;` añade
  `static xcb_colormap_t snap_preview_cmap = XCB_NONE;`;
- antes de `void show_snap_preview(`, añade:

```c
/* A 32-bit TrueColor visual, so a compositor can blend the preview, or NULL
 * when the screen has none. */
static xcb_visualtype_t *find_argb_visual(void)
{
	xcb_depth_iterator_t di = xcb_screen_allowed_depths_iterator(screen);
	for (; di.rem; xcb_depth_next(&di)) {
		if (di.data->depth != 32)
			continue;
		xcb_visualtype_iterator_t vi = xcb_depth_visuals_iterator(di.data);
		for (; vi.rem; xcb_visualtype_next(&vi))
			if (vi.data->_class == XCB_VISUAL_CLASS_TRUE_COLOR)
				return vi.data;
	}
	return NULL;
}
```

En `show_snap_preview`, sustituye el bloque `if (snap_preview_win == BSPWM_WID_NONE) { … }`
(el que contiene `/* Semi-transparent pink */`) por:

```c
	if (snap_preview_win == BSPWM_WID_NONE) {
		snap_preview_win = xcb_generate_id(dpy);
		uint32_t rgb = backend_get_color_pixel(edge_snap_preview_color) & 0xFFFFFF;
		xcb_visualtype_t *argb = find_argb_visual();
		if (argb != NULL) {
			/* A window on a depth other than its parent's needs its own
			 * colormap and an explicit border pixel. */
			snap_preview_cmap = xcb_generate_id(dpy);
			xcb_create_colormap(dpy, XCB_COLORMAP_ALLOC_NONE, snap_preview_cmap,
			                    root, argb->visual_id);
			uint32_t mask = XCB_CW_BACK_PIXEL | XCB_CW_BORDER_PIXEL |
			                XCB_CW_OVERRIDE_REDIRECT | XCB_CW_COLORMAP;
			uint32_t values[] = {
				color_premultiply(rgb, (unsigned int) edge_snap_preview_opacity),
				0xFF000000 | rgb, 1, snap_preview_cmap
			};
			xcb_create_window(dpy, 32, snap_preview_win, root,
			                  preview.x, preview.y, preview.width, preview.height,
			                  2, XCB_WINDOW_CLASS_INPUT_OUTPUT,
			                  argb->visual_id, mask, values);
		} else {
			uint32_t mask = XCB_CW_BACK_PIXEL | XCB_CW_BORDER_PIXEL | XCB_CW_OVERRIDE_REDIRECT;
			uint32_t values[] = {rgb, rgb, 1};
			xcb_create_window(dpy, XCB_COPY_FROM_PARENT, snap_preview_win, root,
			                  preview.x, preview.y, preview.width, preview.height,
			                  2, XCB_WINDOW_CLASS_INPUT_OUTPUT,
			                  XCB_COPY_FROM_PARENT, mask, values);
		}
	}
```

Sustituye `destroy_snap_preview` entera por:

```c
void destroy_snap_preview(void)
{
	if (snap_preview_win != BSPWM_WID_NONE) {
		xcb_destroy_window(dpy, snap_preview_win);
		snap_preview_win = BSPWM_WID_NONE;
	}
	if (snap_preview_cmap != XCB_NONE) {
		xcb_free_colormap(dpy, snap_preview_cmap);
		snap_preview_cmap = XCB_NONE;
	}
	xcb_flush(dpy);
	current_snap_zone = SNAP_NONE;
	snap_target_monitor = NULL;
}
```

- [ ] **Step 5: Ver que pasa**

```bash
cd /websites/personal/bspwm && make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "preview|RED:|ALL GREEN"
```

Expected: ningún aviso, todos los `preview` en `PASS` y `ALL GREEN`.

- [ ] **Step 6: Commits**

```bash
git add src/pointer.c
git commit -m "fix: draw the edge snap preview translucent on a 32-bit visual" \
  -m "The preview was created with the parent's depth, so the alpha in its pixel was dropped and it came out opaque. Use a 32-bit TrueColor visual when the screen has one, with the color and opacity from the new settings."
git add tests/headless/drag.sh tests/headless/edge_snap_preview.sh tests/run_headless
git commit -m "test: check the edge snap preview is translucent"
git add .github/workflows/release.yaml
git commit -m "ci: install the X tools the drag tests use"
git push -u origin edge-snap-preview-color
```

---

### Task 5: Módulo puro `magnet` (rama `magnet-edges`)

**Files:**
- Create: `src/magnet.h`, `src/magnet.c`, `tests/test_magnet.c`, `tests/headless/magnet.sh`
- Modify: `Makefile` (`CORE_SRC`), `tests/Makefile`, `tests/run_headless`, `.gitignore`

**Interfaces:**
- Produces (en `magnet.h`):
  - `MAGNET_LEFT = 0b0001`, `MAGNET_TOP = 0b0010`, `MAGNET_RIGHT = 0b0100`,
    `MAGNET_BOTTOM = 0b1000` y `MAGNET_ALL = 0b1111`. Los valores coinciden con
    `resize_handle_t`.
  - `typedef struct { int x1, y1, x2, y2; } magnet_box_t;`: caja exterior; `x2`/`y2` están un
    píxel más allá del último.
  - `typedef struct { … } magnet_t;`
  - `void magnet_begin(magnet_t *mg, magnet_box_t free, unsigned int edges, magnet_box_t area, int threshold);`
  - `void magnet_consider(magnet_t *mg, magnet_box_t other);`
  - `magnet_box_t magnet_result(const magnet_t *mg);`

- [ ] **Step 1: Crear la rama**

```bash
cd /websites/personal/bspwm
git switch -c magnet-edges upstream/master
```

- [ ] **Step 2: Escribir la prueba unitaria**

`tests/test_magnet.c`:

```c
/* Unit tests for magnet.c: magnetic edges while dragging a window. */

#include <stddef.h>
#include <stdio.h>
#include "../src/magnet.h"

static int failures;

/* The work area of every case: a 1920x1080 monitor without padding. */
static const magnet_box_t area = {0, 0, 1920, 1080};

/* A full magnet pass over `count` other windows. */
static magnet_box_t snap(magnet_box_t free, unsigned int edges,
                         const magnet_box_t *others, size_t count, int threshold)
{
	magnet_t mg;
	magnet_begin(&mg, free, edges, area, threshold);
	for (size_t i = 0; i < count; i++)
		magnet_consider(&mg, others[i]);
	return magnet_result(&mg);
}

static void check(const char *desc, magnet_box_t expected, magnet_box_t actual)
{
	if (expected.x1 == actual.x1 && expected.y1 == actual.y1 &&
	    expected.x2 == actual.x2 && expected.y2 == actual.y2) {
		printf("  PASS: %s\n", desc);
		return;
	}
	printf("  FAIL: %s: expected {%d, %d, %d, %d}, got {%d, %d, %d, %d}\n", desc,
	       expected.x1, expected.y1, expected.x2, expected.y2,
	       actual.x1, actual.y1, actual.x2, actual.y2);
	failures++;
}

int main(void)
{
	/* Moving against the work area. */
	check("a left edge 8 px from the area sticks to it",
	      (magnet_box_t) {0, 300, 404, 604},
	      snap((magnet_box_t) {8, 300, 412, 604}, MAGNET_ALL, NULL, 0, 20));
	check("an edge exactly at the threshold sticks",
	      (magnet_box_t) {0, 300, 404, 604},
	      snap((magnet_box_t) {20, 300, 424, 604}, MAGNET_ALL, NULL, 0, 20));
	check("an edge one pixel past the threshold stays free",
	      (magnet_box_t) {21, 300, 425, 604},
	      snap((magnet_box_t) {21, 300, 425, 604}, MAGNET_ALL, NULL, 0, 20));
	check("a threshold of 0 never sticks",
	      (magnet_box_t) {1, 300, 405, 604},
	      snap((magnet_box_t) {1, 300, 405, 604}, MAGNET_ALL, NULL, 0, 0));
	check("a right edge near the area sticks to it",
	      (magnet_box_t) {1516, 300, 1920, 604},
	      snap((magnet_box_t) {1510, 300, 1914, 604}, MAGNET_ALL, NULL, 0, 20));

	magnet_t mg;
	magnet_begin(&mg, (magnet_box_t) {2, 300, 498, 604}, MAGNET_ALL,
	             (magnet_box_t) {0, 0, 500, 1080}, 20);
	check("on a tie between both edges the left one wins",
	      (magnet_box_t) {0, 300, 496, 604}, magnet_result(&mg));

	/* Moving next to other windows. */
	const magnet_box_t right_of = {1000, 300, 1404, 604};
	check("a window moved next to another touches it",
	      (magnet_box_t) {596, 300, 1000, 604},
	      snap((magnet_box_t) {590, 300, 994, 604}, MAGNET_ALL, &right_of, 1, 20));

	const magnet_box_t below = {1000, 500, 1404, 804};
	check("a window above another lines up with it and touches it",
	      (magnet_box_t) {1000, 196, 1404, 500},
	      snap((magnet_box_t) {994, 180, 1398, 484}, MAGNET_ALL, &below, 1, 20));

	const magnet_box_t far_below = {1000, 850, 1304, 1054};
	check("a window far away on the other axis does not attract",
	      (magnet_box_t) {994, 100, 1398, 404},
	      snap((magnet_box_t) {994, 100, 1398, 404}, MAGNET_ALL, &far_below, 1, 20));

	const magnet_box_t close_right = {409, 300, 813, 604};
	check("an edge already in place holds against a farther candidate",
	      (magnet_box_t) {0, 300, 404, 604},
	      snap((magnet_box_t) {0, 300, 404, 604}, MAGNET_ALL, &close_right, 1, 20));

	/* Resizing. */
	check("a resized right edge touches the window next to it",
	      (magnet_box_t) {300, 300, 1000, 604},
	      snap((magnet_box_t) {300, 300, 993, 604}, MAGNET_RIGHT, &right_of, 1, 20));
	check("a resize leaves alone the edges it does not drag",
	      (magnet_box_t) {5, 300, 1000, 604},
	      snap((magnet_box_t) {5, 300, 993, 604}, MAGNET_RIGHT, &right_of, 1, 20));
	check("a corner resize sticks both of its edges",
	      (magnet_box_t) {300, 300, 1000, 1080},
	      snap((magnet_box_t) {300, 300, 995, 1072}, MAGNET_RIGHT | MAGNET_BOTTOM,
	           &right_of, 1, 20));
	const magnet_box_t above = {300, 300, 704, 604};
	check("a resized top edge touches the window above it",
	      (magnet_box_t) {300, 604, 704, 900},
	      snap((magnet_box_t) {300, 610, 704, 900}, MAGNET_TOP, &above, 1, 20));
	check("a resized edge pulled past the threshold is free again",
	      (magnet_box_t) {300, 300, 1043, 604},
	      snap((magnet_box_t) {300, 300, 1043, 604}, MAGNET_RIGHT, &right_of, 1, 20));

	return failures ? 1 : 0;
}
```

`tests/Makefile`: después de `all: test_window test_window_wl`, añade `all: test_magnet`.
Después de la regla de `test_window_wl`, añade:

```make
test_magnet: test_magnet.c ../src/magnet.c ../src/magnet.h
	$(CC) $(CFLAGS) -std=c23 -o $@ test_magnet.c ../src/magnet.c
```

En `clean:`, deja la misma línea exacta que en la tarea 2:

```make
	$(RM) test_window test_window_wl test_color test_magnet send_moveresize test_edge_zone *.o
```

En `.gitignore`, después de `tests/test_stress`, añade `tests/test_magnet`.

Crea `tests/headless/magnet.sh`:

```sh
# Magnetic edges: window edges stick while moving or resizing with the pointer.

echo ""
echo "== Magnetic edges =="

assert_ok "magnet unit tests pass" ./test_magnet
```

En `tests/run_headless`, justo antes de `# ---- Quit ----`, añade `. ./headless/magnet.sh`.

- [ ] **Step 3: Ver que falla**

```bash
cd /websites/personal/bspwm/tests && make test_magnet 2>&1 | tail -n 2
```

Expected: `../src/magnet.h: No such file or directory`.

Crea `src/magnet.h` con la cabecera BSD de `src/snap.h` (líneas 1–23) y después:

```c
#ifndef BSPWM_MAGNET_H
#define BSPWM_MAGNET_H

#include <stdbool.h>

/* Magnetic edges: while a floating window is dragged, its edges stick to the
 * edges of the work area and of the other windows that come within
 * `magnet_threshold` pixels.
 *
 * Pure geometry with no backend: the pointer-drag path feeds it boxes and
 * applies the result, and the unit tests drive it directly. */

/* Edges of a box, as a bit mask. The values match resize_handle_t, so a
 * resize handle converts with a plain cast. */
enum {
	MAGNET_LEFT = 0b0001,
	MAGNET_TOP = 0b0010,
	MAGNET_RIGHT = 0b0100,
	MAGNET_BOTTOM = 0b1000,
	MAGNET_ALL = 0b1111,
};

/* A window's outer box (border included) as edge coordinates. `x2` and `y2`
 * are one past the last pixel, so two boxes touch when one's x2 equals the
 * other's x1. */
typedef struct {
	int x1, y1, x2, y2;
} magnet_box_t;

/* Nearest candidate found so far for each edge. Start with magnet_begin(),
 * feed every other window to magnet_consider(), then read the result. */
typedef struct {
	magnet_box_t free;
	unsigned int edges;
	int threshold;
	int offset[4];
	bool found[4];
} magnet_t;

/* `free` is where the pointer alone would put the window, `edges` the edges
 * being dragged (MAGNET_ALL for a move) and `area` the work area. */
void magnet_begin(magnet_t *mg, magnet_box_t free, unsigned int edges,
                  magnet_box_t area, int threshold);
void magnet_consider(magnet_t *mg, magnet_box_t other);
magnet_box_t magnet_result(const magnet_t *mg);

#endif
```

Crea `src/magnet.c` con la cabecera BSD y un esqueleto:

```c
#include "magnet.h"

void magnet_begin(magnet_t *mg, magnet_box_t free, unsigned int edges,
                  magnet_box_t area, int threshold)
{
	(void) area;
	*mg = (magnet_t) {.free = free, .edges = edges, .threshold = threshold};
}

void magnet_consider(magnet_t *mg, magnet_box_t other)
{
	(void) mg;
	(void) other;
}

magnet_box_t magnet_result(const magnet_t *mg)
{
	return mg->free;
}
```

```bash
cd /websites/personal/bspwm/tests && make test_magnet >/dev/null && ./test_magnet; echo "salida: $?"
```

Expected: `FAIL` en todos los casos que esperan un pegado, `PASS` en los que esperan la caja sin
cambios, y `salida: 1`.

- [ ] **Step 4: Implementar**

Sustituye el cuerpo de `src/magnet.c` (bajo la cabecera BSD) por:

```c
#include <stdlib.h>
#include "magnet.h"

/* Slots of magnet_t.offset and magnet_t.found. */
enum {
	SLOT_LEFT,
	SLOT_RIGHT,
	SLOT_TOP,
	SLOT_BOTTOM,
};

/* Keep `candidate` for the edge in `slot` when it is the closest one so far
 * within the threshold. An offset of 0 counts too: an edge already in place
 * holds there instead of drifting to a farther candidate. */
static void offer(magnet_t *mg, int slot, int edge, int candidate)
{
	int offset = candidate - edge;
	if (abs(offset) > mg->threshold)
		return;
	if (mg->found[slot] && abs(offset) >= abs(mg->offset[slot]))
		return;
	mg->offset[slot] = offset;
	mg->found[slot] = true;
}

/* Whether the spans [a1, a2) and [b1, b2) overlap or lie within `gap` of each
 * other. A window only attracts along one axis when it is next to the dragged
 * one on the other axis; otherwise an edge would catch on the coordinates of
 * windows across the screen. */
static bool spans_near(int a1, int a2, int b1, int b2, int gap)
{
	return b1 <= a2 + gap && a1 <= b2 + gap;
}

void magnet_begin(magnet_t *mg, magnet_box_t free, unsigned int edges,
                  magnet_box_t area, int threshold)
{
	*mg = (magnet_t) {.free = free, .edges = edges, .threshold = threshold};
	offer(mg, SLOT_LEFT, free.x1, area.x1);
	offer(mg, SLOT_RIGHT, free.x2, area.x2);
	offer(mg, SLOT_TOP, free.y1, area.y1);
	offer(mg, SLOT_BOTTOM, free.y2, area.y2);
}

void magnet_consider(magnet_t *mg, magnet_box_t o)
{
	magnet_box_t f = mg->free;
	if (spans_near(f.y1, f.y2, o.y1, o.y2, mg->threshold)) {
		/* The same edge in line, or the opposite edges touching. */
		offer(mg, SLOT_LEFT, f.x1, o.x1);
		offer(mg, SLOT_LEFT, f.x1, o.x2);
		offer(mg, SLOT_RIGHT, f.x2, o.x2);
		offer(mg, SLOT_RIGHT, f.x2, o.x1);
	}
	if (spans_near(f.x1, f.x2, o.x1, o.x2, mg->threshold)) {
		offer(mg, SLOT_TOP, f.y1, o.y1);
		offer(mg, SLOT_TOP, f.y1, o.y2);
		offer(mg, SLOT_BOTTOM, f.y2, o.y2);
		offer(mg, SLOT_BOTTOM, f.y2, o.y1);
	}
}

/* For a move, the closer of the two edges of an axis wins; the first one on a
 * tie. */
static int pick(const magnet_t *mg, int lo, int hi)
{
	if (mg->found[lo] && mg->found[hi])
		return abs(mg->offset[hi]) < abs(mg->offset[lo]) ? mg->offset[hi] : mg->offset[lo];
	if (mg->found[lo])
		return mg->offset[lo];
	if (mg->found[hi])
		return mg->offset[hi];
	return 0;
}

magnet_box_t magnet_result(const magnet_t *mg)
{
	magnet_box_t b = mg->free;
	if (mg->threshold <= 0)
		return b;

	if ((mg->edges & MAGNET_ALL) == MAGNET_ALL) {
		int dx = pick(mg, SLOT_LEFT, SLOT_RIGHT);
		int dy = pick(mg, SLOT_TOP, SLOT_BOTTOM);
		return (magnet_box_t) {b.x1 + dx, b.y1 + dy, b.x2 + dx, b.y2 + dy};
	}

	if ((mg->edges & MAGNET_LEFT) && mg->found[SLOT_LEFT])
		b.x1 += mg->offset[SLOT_LEFT];
	if ((mg->edges & MAGNET_RIGHT) && mg->found[SLOT_RIGHT])
		b.x2 += mg->offset[SLOT_RIGHT];
	if ((mg->edges & MAGNET_TOP) && mg->found[SLOT_TOP])
		b.y1 += mg->offset[SLOT_TOP];
	if ((mg->edges & MAGNET_BOTTOM) && mg->found[SLOT_BOTTOM])
		b.y2 += mg->offset[SLOT_BOTTOM];
	return b;
}
```

En el `Makefile` raíz, añade `magnet.c` al final de `CORE_SRC`.

- [ ] **Step 5: Ver que pasa**

```bash
cd /websites/personal/bspwm/tests && make test_magnet >/dev/null && ./test_magnet; echo "salida: $?"
cd .. && make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "magnet unit|ALL GREEN|RED:"
```

Expected: 15 `PASS`, `salida: 0`, ningún aviso, `PASS: magnet unit tests pass` y `ALL GREEN`.

- [ ] **Step 6: Commits**

```bash
git add src/magnet.c src/magnet.h Makefile
git commit -m "feat: add a backend-free magnet module for window edges"
git add tests/test_magnet.c tests/Makefile tests/headless/magnet.sh tests/run_headless .gitignore
git commit -m "test: unit-test the magnet module"
```

---

### Task 6: Ajuste `magnet_threshold` (rama `magnet-edges`)

**Files:**
- Modify: `src/settings.h`, `src/settings.c`, `src/messages.c`, `doc/bspwm.1.asciidoc`,
  `doc/bspwm.1`, `contrib/*_completion`, `tests/headless/magnet.sh`

**Interfaces:**
- Produces: `extern int magnet_threshold;` en `settings.h`, con valor 0–100 y 0 por defecto.

- [ ] **Step 1: Escribir las pruebas**

Añade al final de `tests/headless/magnet.sh`:

```sh
assert_eq "magnet is off by default" "0" "$($BSPC config magnet_threshold 2>/dev/null)"
assert_ok "set the magnet threshold" $BSPC config magnet_threshold 20
assert_eq "magnet threshold was set" "20" "$($BSPC config magnet_threshold 2>/dev/null)"
assert_ok "accept a magnet threshold of 0" $BSPC config magnet_threshold 0
assert_fail "reject a magnet threshold above 100" $BSPC config magnet_threshold 101
assert_fail "reject a negative magnet threshold" $BSPC config magnet_threshold -1
```

- [ ] **Step 2: Ver que falla**

```bash
cd /websites/personal/bspwm && make test 2>&1 | grep -E "magnet (is|threshold)|RED:|ALL GREEN"
```

Expected: `FAIL` en `magnet is off by default`, `set the magnet threshold`, `magnet threshold
was set` y `accept a magnet threshold of 0`, y `RED:`.

- [ ] **Step 3: Implementar**

`src/settings.h`: después de `#define EDGE_SNAP_THRESHOLD         20` añade
`#define MAGNET_THRESHOLD            0`, y después de `extern int edge_snap_threshold;` añade
`extern int magnet_threshold;`.

`src/settings.c`: después de `int edge_snap_threshold;` añade `int magnet_threshold;`, y
después de `edge_snap_threshold = EDGE_SNAP_THRESHOLD;` añade
`	magnet_threshold = MAGNET_THRESHOLD;`.

`src/messages.c`, en `set_setting`, después de `		edge_snap_threshold = t;`:

```c
	} else if (streq("magnet_threshold", name)) {
		int t;
		if (sscanf(value, "%i", &t) != 1 || t < 0 || t > 100) {
			fail(rsp, "config: %s: Invalid value: '%s' (must be 0-100).\n", name, value);
			return;
		}
		magnet_threshold = t;
```

`src/messages.c`, en `get_setting`, después de `		fprintf(rsp, "%i", edge_snap_threshold);`:

```c
	} else if (streq("magnet_threshold", name)) {
		fprintf(rsp, "%i", magnet_threshold);
```

`doc/bspwm.1.asciidoc`, después de la entrada `'edge_snap_threshold'::` y su línea en blanco:

```
'magnet_threshold'::
	While a floating window is moved or resized with the pointer, its edges stick to the edges of the work area and of the other windows on the desktop that come within this many pixels: edge against edge, or in line with the same edge of a neighbour. A window only attracts along one axis when it is next to the dragged one on the other axis. Keep dragging to pull free. *0* disables it. X11 only. Defaults to *0*.

```

Autocompletado:
- `contrib/bash_completion` y `contrib/fish_completion`: cambia
  `edge_snap_threshold cascade_offset` por `edge_snap_threshold magnet_threshold cascade_offset`.
- `contrib/zsh_completion`: en el array `input=(...)`, después de `edge_snap_threshold` añade
  `magnet_threshold`.

```bash
cd /websites/personal/bspwm && make doc VERCMD=false && git diff --stat doc/bspwm.1
```

Expected: solo unas pocas líneas nuevas en `doc/bspwm.1`. Si no es así, se aplica el mismo
criterio que en la tarea 3.

- [ ] **Step 4: Ver que pasa**

```bash
cd /websites/personal/bspwm && make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "magnet|RED:|ALL GREEN"
```

Expected: ningún aviso, todos los `magnet` en `PASS` y `ALL GREEN`.

- [ ] **Step 5: Commits**

```bash
git add src/settings.h src/settings.c src/messages.c doc/ contrib/
git commit -m "feat: add the magnet_threshold setting"
git add tests/headless/magnet.sh
git commit -m "test: cover the magnet_threshold setting"
```

---

### Task 7: Imán al mover, también al cruzar de monitor (rama `magnet-edges`)

**Files:**
- Create: `tests/headless/drag.sh` (idéntico al de la tarea 4)
- Modify: `src/pointer.c`, `tests/headless/magnet.sh`, `tests/run_headless`,
  `.github/workflows/release.yaml`

**Interfaces:**
- Consumes: `magnet_begin`, `magnet_consider`, `magnet_result`, `MAGNET_*` y
  `magnet_box_t` (tarea 5); `magnet_threshold` (tarea 6); `get_rectangle`, `first_extrema`,
  `next_leaf` (`tree.h`); `monitor_from_point` (`monitor.h`); `move_client` (`window.h`);
  `IS_FLOATING` (`helpers.h`).
- Produces (static en `pointer.c`): `magnet_box_of(node_t *)`,
  `magnet_area_of(monitor_t *, desktop_t *)` y
  `magnet_snap_node(coordinates_t *, magnet_box_t, unsigned int)`, más la variable
  `magnet_free` y el flag `magnet_on` en `track_pointer`. La tarea 8 los usa.

- [ ] **Step 1: Ayudantes, CI y pruebas**

Crea `tests/headless/drag.sh` con el contenido exacto del paso 1 de la tarea 4. Añade
`. ./headless/drag.sh` antes de `# ---- TESTS ----` en `tests/run_headless`, y haz la misma
edición en `release.yaml` que en la tarea 4.

Añade al final de `tests/headless/magnet.sh`:

```sh
if drag_tools_available; then
	drag_setup
	$BSPC config edge_snap_enabled false
	$BSPC config magnet_threshold 20

	# Work area edge, and pulling free again (border 2: outer box = inner + 4).
	A=$(spawn_floating magnet-area 400x300+300+300)
	drag_begin 1 500 450
	drag_to 208 450
	assert_eq "a moved window sticks to the work area while dragging" "0 300 400 300" "$(win_geom "$A")"
	drag_to 248 450
	assert_eq "dragging on pulls the window free" "48 300 400 300" "$(win_geom "$A")"
	drag_end 1
	$BSPC node "$A" -c
	sleep 0.3

	# Edge against edge.
	B=$(spawn_floating magnet-neighbour 400x300+1000+300)
	A=$(spawn_floating magnet-moved 400x300+300+300)
	drag_begin 1 500 450
	drag_to 790 450
	assert_eq "a moved window touches the one next to it" "596 300 400 300" "$(win_geom "$A")"
	drag_end 1
	$BSPC node "$A" -c
	$BSPC node "$B" -c
	sleep 0.3

	# In line and stacked.
	B=$(spawn_floating magnet-below 400x300+1000+500)
	A=$(spawn_floating magnet-above 400x300+700+180)
	drag_begin 1 900 330
	drag_to 1194 330
	assert_eq "a moved window lines up with and touches the one below" "1000 196 400 300" "$(win_geom "$A")"
	drag_end 1
	$BSPC node "$A" -c
	$BSPC node "$B" -c
	sleep 0.3

	# A window far away on the other axis does not attract.
	B=$(spawn_floating magnet-far 300x200+1000+850)
	A=$(spawn_floating magnet-free 400x300+300+100)
	drag_begin 1 500 250
	drag_to 1194 250
	assert_eq "a window far away on the other axis does not attract" "994 100 400 300" "$(win_geom "$A")"
	drag_end 1
	$BSPC node "$A" -c
	$BSPC node "$B" -c
	sleep 0.3

	# Off means off.
	$BSPC config magnet_threshold 0
	A=$(spawn_floating magnet-off 400x300+300+300)
	drag_begin 1 500 450
	drag_to 208 450
	assert_eq "with magnet_threshold 0 the window follows the pointer" "8 300 400 300" "$(win_geom "$A")"
	drag_end 1
	$BSPC node "$A" -c
	sleep 0.3
	$BSPC config magnet_threshold 20

	# An edge snap zone still wins on release.
	$BSPC config edge_snap_enabled true
	A=$(spawn_floating magnet-zone 400x300+300+300)
	drag_begin 1 500 450
	drag_to 5 450
	drag_end 1
	C=$(spawn_floating magnet-reference 200x200+600+600)
	$BSPC node "$C" -S left
	sleep 0.3
	assert_eq "releasing in a snap zone applies the zone" "$(win_geom "$C")" "$(win_geom "$A")"
	$BSPC node "$A" -c
	$BSPC node "$C" -c
	sleep 0.3
	$BSPC config edge_snap_enabled false

	# Crossing monitors: the window sticks to the monitor it moves onto.
	MON=$($BSPC query -M -m focused)
	$BSPC monitor "$MON" -g 960x1080+0+0
	$BSPC wm -a magnet-right 960x1080+960+0
	A=$(spawn_floating magnet-cross 300x200+300+300)
	drag_begin 1 450 400
	drag_to 1760 400
	assert_eq "a window moved onto another monitor sticks to its edge" "1616 300 300 200" "$(win_geom "$A")"
	drag_end 1
	assert_eq "and ends up on that monitor" "magnet-right" "$($BSPC query -M -n "$A" --names 2>/dev/null)"
	$BSPC node "$A" -c
	sleep 0.3
	$BSPC monitor magnet-right -r
	$BSPC monitor "$MON" -g 1920x1080+0+0

	$BSPC config magnet_threshold 0
	$BSPC config edge_snap_enabled true
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: magnetic moves (needs X11, test_window, xdotool, xwininfo)"
fi
```

- [ ] **Step 2: Ver que falla**

```bash
cd /websites/personal/bspwm && make test 2>&1 | grep -E "moved window|pulls|far away|magnet_threshold 0|snap zone|monitor|RED:|ALL GREEN"
```

Expected: `FAIL` en «sticks to the work area», «touches the one next to it», «lines up…» y
«sticks to its edge»; `PASS` en «pulls the window free», «far away», «magnet_threshold 0»,
«applies the zone» y «ends up on that monitor»; y `RED:`.

- [ ] **Step 3: Implementar**

En `src/pointer.c`, añade `#include "magnet.h"` junto a los demás `#include "…"`, y antes de
`void track_pointer(`:

```c
static_assert(MAGNET_LEFT == HANDLE_LEFT && MAGNET_TOP == HANDLE_TOP &&
              MAGNET_RIGHT == HANDLE_RIGHT && MAGNET_BOTTOM == HANDLE_BOTTOM,
              "magnet edges must match resize handles");

/* Outer box of a node's window: its rectangle plus the border on both sides. */
static magnet_box_t magnet_box_of(node_t *n)
{
	bspwm_rect_t r = get_rectangle(NULL, NULL, n);
	int b = 2 * (int) n->client->border_width;
	return (magnet_box_t) {r.x, r.y, r.x + r.width + b, r.y + r.height + b};
}

/* Work area of a desktop, computed the way arrange() does. */
static magnet_box_t magnet_area_of(monitor_t *m, desktop_t *d)
{
	bspwm_rect_t r = m->rectangle;
	padding_t p = m->padding;
	if (d != NULL) {
		p.top += d->padding.top;
		p.right += d->padding.right;
		p.bottom += d->padding.bottom;
		p.left += d->padding.left;
	}
	return (magnet_box_t) {r.x + p.left, r.y + p.top,
	                       r.x + r.width - p.right, r.y + r.height - p.bottom};
}

/* Where the dragged window goes when the pointer alone would put it at `free`:
 * a magnet pass against the work area and the other visible windows. A move
 * is checked against the monitor the window is about to land on, so it
 * sticks to the new monitor in the same step. */
static magnet_box_t magnet_snap_node(coordinates_t *loc, magnet_box_t free, unsigned int edges)
{
	monitor_t *m = loc->monitor;
	desktop_t *d = loc->desktop;
	if (edges == MAGNET_ALL) {
		bspwm_point_t center = {(int16_t) ((free.x1 + free.x2) / 2),
		                        (int16_t) ((free.y1 + free.y2) / 2)};
		monitor_t *target = monitor_from_point(center);
		if (target != NULL && target != m) {
			m = target;
			d = target->desk;
		}
	}

	magnet_t mg;
	magnet_begin(&mg, free, edges, magnet_area_of(m, d), magnet_threshold);
	if (d != NULL) {
		for (node_t *f = first_extrema(d->root); f != NULL; f = next_leaf(f, d->root)) {
			if (f == loc->node || f->client == NULL || f->hidden)
				continue;
			magnet_consider(&mg, magnet_box_of(f));
		}
	}
	return magnet_result(&mg);
}
```

En `track_pointer`, justo después de `snap_target_monitor = NULL;` y antes de `do {`:

```c
	/* Magnetic edges: the box the pointer alone would give the window, which
	 * the magnet then adjusts on every motion. */
	bool magnet_on = magnet_threshold > 0 && IS_FLOATING(n->client);
	magnet_box_t magnet_free = magnet_on ? magnet_box_of(n) : (magnet_box_t) {0};
```

En la rama de movimiento, sustituye:

```c
			if (pac == ACTION_MOVE) {
				move_client(&loc, dx, dy);
```

por:

```c
			if (pac == ACTION_MOVE) {
				if (magnet_on) {
					magnet_free.x1 += dx;
					magnet_free.x2 += dx;
					magnet_free.y1 += dy;
					magnet_free.y2 += dy;
					magnet_box_t want = magnet_snap_node(&loc, magnet_free, MAGNET_ALL);
					magnet_box_t cur = magnet_box_of(n);
					move_client(&loc, want.x1 - cur.x1, want.y1 - cur.y1);
				} else {
					move_client(&loc, dx, dy);
				}
```

(El resto de esa rama, con el Aero Snap, no cambia.)

- [ ] **Step 4: Ver que pasa**

```bash
cd /websites/personal/bspwm && make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "moved window|pulls|far away|magnet_threshold 0|snap zone|monitor|RED:|ALL GREEN"
```

Expected: ningún aviso, todo `PASS` y `ALL GREEN`. Si «a moved window sticks…» falla por uno o
dos píxeles, imprime `win_geom` y `bspc query -T -n` de la ventana **después** de soltar y
revisa el cálculo del borde antes de tocar la prueba: los valores esperados salen de la
especificación.

- [ ] **Step 5: Commits**

```bash
git add src/pointer.c
git commit -m "feat: stick window edges while moving with the pointer"
git add tests/headless/drag.sh tests/headless/magnet.sh tests/run_headless
git commit -m "test: check magnetic edges while moving"
git add .github/workflows/release.yaml
git commit -m "ci: install the X tools the drag tests use"
```

---

### Task 8: Imán al redimensionar (rama `magnet-edges`)

**Files:**
- Modify: `src/pointer.c`, `tests/headless/magnet.sh`

**Interfaces:**
- Consumes: `magnet_on`, `magnet_free`, `magnet_box_of` y `magnet_snap_node` (tarea 7);
  `resize_client(coordinates_t *, resize_handle_t, int dx, int dy, bool relative)`. En modo
  relativo `dx`/`dy` es lo que se mueve el borde; en modo absoluto es la coordenada del puntero:
  para `HANDLE_LEFT`/`TOP` el borde exterior queda en ella, y para `RIGHT`/`BOTTOM` es el borde
  interior.
- Produces: `static void magnet_resize(...)` en `pointer.c`.

- [ ] **Step 1: Escribir las pruebas**

En `tests/headless/magnet.sh`, justo antes de la línea `	$BSPC config magnet_threshold 0`
que cierra el bloque `if drag_tools_available` (la penúltima antes de `else`), añade:

```sh
	# Resizing a side: only that edge sticks, and pulls free again.
	$BSPC config magnet_threshold 20
	B=$(spawn_floating resize-neighbour 400x300+1000+300)
	A=$(spawn_floating resize-side 400x300+300+300)
	drag_begin 2 690 450
	drag_to 979 450
	assert_eq "a resized side touches the window next to it" "300 300 696 300" "$(win_geom "$A")"
	drag_to 1029 450
	assert_eq "stretching on pulls the side free" "300 300 739 300" "$(win_geom "$A")"
	drag_end 2
	$BSPC node "$A" -c
	sleep 0.3

	# Resizing a corner: both edges stick, each to its own target.
	A=$(spawn_floating resize-corner 400x300+300+300)
	drag_begin 3 680 580
	drag_to 971 1048
	assert_eq "a resized corner sticks to a window and to the work area" "300 300 696 776" "$(win_geom "$A")"
	drag_end 3
	$BSPC node "$A" -c
	$BSPC node "$B" -c
	sleep 0.3

	# Tiled windows resize exactly as without the magnet.
	./test_window resize-tiled-1 Drag >/dev/null 2>&1 &
	sleep 0.5
	T1=$($BSPC query -N -n focused)
	./test_window resize-tiled-2 Drag >/dev/null 2>&1 &
	sleep 0.5
	BEFORE=$(win_geom "$T1")
	drag_begin 2 900 540
	drag_to 950 540
	drag_end 2
	WITH_MAGNET=$(win_geom "$T1")
	$BSPC node @/ -r 0.5
	sleep 0.3
	$BSPC config magnet_threshold 0
	drag_begin 2 900 540
	drag_to 950 540
	drag_end 2
	WITHOUT_MAGNET=$(win_geom "$T1")
	assert_fail "the tiled resize actually changed the window" [ "$BEFORE" = "$WITH_MAGNET" ]
	assert_eq "a tiled resize is the same with and without the magnet" "$WITHOUT_MAGNET" "$WITH_MAGNET"
	$BSPC node "$T1" -c
	sleep 0.3
	$BSPC node -c
	sleep 0.3
```

- [ ] **Step 2: Ver que falla**

```bash
cd /websites/personal/bspwm && make test 2>&1 | grep -E "resized|stretching|tiled resize|RED:|ALL GREEN"
```

Expected: `FAIL` en «a resized side touches…» y en «a resized corner sticks…»; `PASS` en
«stretching on pulls the side free» y en las dos de tiled; y `RED:`.

- [ ] **Step 3: Implementar**

En `src/pointer.c`, después de `magnet_snap_node`:

```c
/* One resize step with magnetic edges. `free` holds where the dragged edges
 * would be without the magnet and is advanced by this motion first. */
static void magnet_resize(coordinates_t *loc, resize_handle_t rh, magnet_box_t *free,
                          int root_x, int root_y, int dx, int dy, bool absolute)
{
	int b = 2 * (int) loc->node->client->border_width;
	if (absolute) {
		/* resize_client puts the outer left/top edge and the inner
		 * right/bottom edge at the pointer. */
		if (rh & HANDLE_LEFT)
			free->x1 = root_x;
		if (rh & HANDLE_RIGHT)
			free->x2 = root_x + b;
		if (rh & HANDLE_TOP)
			free->y1 = root_y;
		if (rh & HANDLE_BOTTOM)
			free->y2 = root_y + b;
	} else {
		if (rh & HANDLE_LEFT)
			free->x1 += dx;
		if (rh & HANDLE_RIGHT)
			free->x2 += dx;
		if (rh & HANDLE_TOP)
			free->y1 += dy;
		if (rh & HANDLE_BOTTOM)
			free->y2 += dy;
	}

	magnet_box_t want = magnet_snap_node(loc, *free, (unsigned int) rh);

	if (absolute) {
		int ax = (rh & HANDLE_LEFT) ? want.x1 : want.x2 - b;
		int ay = (rh & HANDLE_TOP) ? want.y1 : want.y2 - b;
		resize_client(loc, rh, ax, ay, false);
		return;
	}

	magnet_box_t cur = magnet_box_of(loc->node);
	int ddx = 0, ddy = 0;
	if (rh & HANDLE_LEFT)
		ddx = want.x1 - cur.x1;
	else if (rh & HANDLE_RIGHT)
		ddx = want.x2 - cur.x2;
	if (rh & HANDLE_TOP)
		ddy = want.y1 - cur.y1;
	else if (rh & HANDLE_BOTTOM)
		ddy = want.y2 - cur.y2;
	resize_client(loc, rh, ddx, ddy, true);
}
```

En `track_pointer`, sustituye:

```c
			} else if (n && n->client) {
				client_t *c = n->client;
				if (SHOULD_HONOR_SIZE_HINTS(c->honor_size_hints, c->state)) {
					resize_client(&loc, rh, e->root_x, e->root_y, false);
				} else {
					resize_client(&loc, rh, dx, dy, true);
				}
			}
```

por:

```c
			} else if (n && n->client) {
				client_t *c = n->client;
				bool absolute = SHOULD_HONOR_SIZE_HINTS(c->honor_size_hints, c->state);
				if (magnet_on) {
					magnet_resize(&loc, rh, &magnet_free, e->root_x, e->root_y,
					              dx, dy, absolute);
				} else if (absolute) {
					resize_client(&loc, rh, e->root_x, e->root_y, false);
				} else {
					resize_client(&loc, rh, dx, dy, true);
				}
			}
```

- [ ] **Step 4: Ver que pasa**

```bash
cd /websites/personal/bspwm && make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "magnet|moved|resized|stretching|tiled|RED:|ALL GREEN"
```

Expected: ningún aviso, todo `PASS` y `ALL GREEN`.

- [ ] **Step 5: Commits**

```bash
git add src/pointer.c
git commit -m "feat: stick window edges while resizing with the pointer"
git add tests/headless/magnet.sh
git commit -m "test: check magnetic edges while resizing"
git push -u origin magnet-edges
```

---

### Task 9: Traer las ramas de los PRs de bspwm original

**Files:** ninguno. Solo refs de git.

**Interfaces:**
- Produces: las ramas locales `baskerville-pr-1541`, `baskerville-pr-1284`,
  `baskerville-pr-1035` y `baskerville-pr-1183`, con los commits originales.

- [ ] **Step 1: Traerlas**

```bash
cd /websites/personal/bspwm
for n in 1541 1284 1035 1183; do git fetch baskerville "pull/$n/head:baskerville-pr-$n"; done
for n in 1541 1284 1035 1183; do echo "#$n"; git log --format='  %h %an <%ae> %s' "baskerville/master..baskerville-pr-$n"; done
```

Expected: los mismos commits y autores de la especificación:
- #1541: `bfa15f6`, Sean C. Farley;
- #1284: `f42fd34` y `04dd82a`, Loic Coyle;
- #1035: `d7e5555`, nwwdles;
- #1183: `760465d`, `ab7947c` y `d7a31ad`, Jeffrey McAteer.

Si `baskerville/master` no es un ancestro y la lista sale vacía, usa
`git log -3 --format='  %h %an <%ae> %s' baskerville-pr-$n`.

---

### Task 10: #1541 — no subir la ventana enfocada (rama `upstream-1541-no-raise-on-focus`)

**Files:**
- Create: `tests/headless/no_raise_on_focus.sh`
- Modify: `src/events.c`, `src/messages.c`, `tests/run_headless`

**Interfaces:**
- Consumes: `auto_raise` (`bspwm.h`), que `stack()` ya respeta con las flotantes
  (`src/stack.c`).

- [ ] **Step 1: Rama y prueba**

```bash
cd /websites/personal/bspwm
git switch -c upstream-1541-no-raise-on-focus upstream/master
```

Crea `tests/headless/no_raise_on_focus.sh`:

```sh
# Switching back to a desktop focuses its window without restacking it.

echo ""
echo "== Focus without raising =="

if [ "$BACKEND" = "x11" ] && [ -f ./test_window ]; then
	HOME_DESK=$($BSPC query -D -d focused)
	$BSPC monitor -a noraise-other
	$BSPC rule -a "Noraise:*" state=floating
	./test_window noraise-a Noraise >/dev/null 2>&1 &
	sleep 0.5
	A=$($BSPC query -N -n focused)
	./test_window noraise-b Noraise >/dev/null 2>&1 &
	sleep 0.5
	$BSPC node "$A" -f
	sleep 0.3

	STACK_LOG=$(mktemp)
	$BSPC subscribe node_stack > "$STACK_LOG" &
	SUB=$!
	sleep 0.3
	$BSPC desktop -f noraise-other
	$BSPC desktop -f "$HOME_DESK"
	sleep 0.3
	kill "$SUB" 2>/dev/null || true
	assert_eq "switching back to a desktop does not restack its focused window" "0" "$(wc -l < "$STACK_LOG")"
	command rm -f "$STACK_LOG"

	$BSPC node -c
	sleep 0.3
	$BSPC node -c
	sleep 0.3
	$BSPC rule -r "Noraise:*:*"
	$BSPC desktop noraise-other -r
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: focus without raising (needs X11 and test_window)"
fi
```

En `tests/run_headless`, antes de `# ---- Quit ----`, añade `. ./headless/no_raise_on_focus.sh`.

- [ ] **Step 2: Ver que falla**

```bash
make test 2>&1 | grep -E "does not restack|RED:|ALL GREEN"
```

Expected: `FAIL: switching back to a desktop does not restack its focused window` (con
`actual` 1 o más) y `RED:`. **Si pasa**, `stack()` no emitió `node_stack` en este escenario y la
prueba no demuestra nada: para y avisa, no sigas con el port.

- [ ] **Step 3: Portar el PR**

```bash
git cherry-pick -x bfa15f6
```

Si hay conflicto, el cambio completo es este:
- en `src/events.c`, alrededor de la única llamada
  `focus_node(mon, mon->desk, mon->desk->focus);` que está entre
  `pointer_follows_focus = false;` y `pointer_follows_focus = pff;`, poner `auto_raise = false;`
  antes y `auto_raise = true;` después;
- en `src/messages.c`, lo mismo alrededor de `focus_node(dst.monitor, dst.desktop, NULL);`, en
  la rama `-f`/`--focus` de `cmd_desktop`.

Después:

```bash
git add src/events.c src/messages.c && git cherry-pick --continue
```

Deja el mensaje con el formato del proyecto, conservando el autor:

```bash
git commit --amend -m "fix: do not raise the focused window on desktop and monitor focus" \
  -m "When the pointer moves to another monitor or a desktop is focused, the focused window was raised although the layout should stay the same, which reordered overlapping floating windows." \
  -m "Ported from baskerville/bspwm#1541 (cherry picked from commit bfa15f6)."
git log -1 --format='%an <%ae>'
```

Expected: `Sean C. Farley <sean+dev@farley.org>`

- [ ] **Step 4: Ver que pasa**

```bash
make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "does not restack|RED:|ALL GREEN"
```

Expected: ningún aviso, `PASS` y `ALL GREEN`.

- [ ] **Step 5: Commit de la prueba**

```bash
git add tests/headless/no_raise_on_focus.sh tests/run_headless
git commit -m "test: check desktop focus does not restack the focused window"
git push -u origin upstream-1541-no-raise-on-focus
```

---

### Task 11: #1284 — intervalo de movimiento al redimensionar (rama `upstream-1284-resize-motion-interval`)

**Files:**
- Create: `tests/headless/resize_motion_interval.sh`
- Modify: `src/settings.h`, `src/settings.c`, `src/messages.c`, `src/pointer.c`,
  `doc/bspwm.1.asciidoc`, `doc/bspwm.1`, `contrib/*_completion`, `tests/run_headless`

**Interfaces:**
- Produces: `extern uint32_t pointer_motion_interval_resize;` (por defecto
  `POINTER_MOTION_INTERVAL`, que vale 17).

- [ ] **Step 1: Rama y prueba**

```bash
cd /websites/personal/bspwm
git switch -c upstream-1284-resize-motion-interval upstream/master
```

Crea `tests/headless/resize_motion_interval.sh`:

```sh
# A separate pointer motion interval for resizing.

echo ""
echo "== Resize motion interval =="

assert_eq "the resize interval defaults to 17" "17" "$($BSPC config pointer_motion_interval_resize 2>/dev/null)"
assert_ok "set the resize interval" $BSPC config pointer_motion_interval_resize 5
assert_eq "the resize interval was set" "5" "$($BSPC config pointer_motion_interval_resize 2>/dev/null)"
assert_eq "the move interval is left alone" "17" "$($BSPC config pointer_motion_interval 2>/dev/null)"
assert_fail "reject a resize interval that is not a number" $BSPC config pointer_motion_interval_resize fast
$BSPC config pointer_motion_interval_resize 17 || true
```

En `tests/run_headless`, antes de `# ---- Quit ----`, añade
`. ./headless/resize_motion_interval.sh`.

- [ ] **Step 2: Ver que falla**

```bash
make test 2>&1 | grep -E "interval|RED:|ALL GREEN"
```

Expected: `FAIL` en «defaults to 17», «set the resize interval» y «was set», y `RED:`.

- [ ] **Step 3: Portar el PR**

El diff original no entra en bspwm1, así que el port se hace a mano sobre sus mismas piezas:

`src/settings.h`: después de `#define POINTER_MOTION_INTERVAL  17` añade
`#define POINTER_MOTION_INTERVAL_RESIZE  POINTER_MOTION_INTERVAL`, y después de
`extern uint32_t pointer_motion_interval;` añade
`extern uint32_t pointer_motion_interval_resize;`.

`src/settings.c`: después de `uint32_t pointer_motion_interval;` añade
`uint32_t pointer_motion_interval_resize;`, y después de
`	pointer_motion_interval = POINTER_MOTION_INTERVAL;` añade
`	pointer_motion_interval_resize = POINTER_MOTION_INTERVAL_RESIZE;`.

`src/messages.c`, en `set_setting`, después del bloque de `pointer_motion_interval` (el que
termina en el `}` antes de `} else if (streq("pointer_action1", name) ||`):

```c
	} else if (streq("pointer_motion_interval_resize", name)) {
		if (sscanf(value, "%u", &pointer_motion_interval_resize) != 1) {
			fail(rsp, "config: %s: Invalid value: '%s'.\n", name, value);
			return;
		}
```

`src/messages.c`, en `get_setting`, después de `		fprintf(rsp, "%u", pointer_motion_interval);`:

```c
	} else if (streq("pointer_motion_interval_resize", name)) {
		fprintf(rsp, "%u", pointer_motion_interval_resize);
```

`src/pointer.c`, en `track_pointer`, sustituye:

```c
			if (dtime < pointer_motion_interval)
				continue;
```

por:

```c
			uint32_t interval = pac == ACTION_MOVE ? pointer_motion_interval
			                                       : pointer_motion_interval_resize;
			if (dtime < interval)
				continue;
```

`doc/bspwm.1.asciidoc`, después de la entrada `'pointer_motion_interval'::` y su línea en blanco:

```
'pointer_motion_interval_resize'::
	The minimum interval, in milliseconds, between two motion notify events while resizing a window. Lower it for applications that redraw slowly while being resized, without making moves jumpy. Defaults to *17*.

```

Autocompletado:
- `contrib/bash_completion` y `contrib/fish_completion`: cambia
  `pointer_motion_interval pointer_modifier` por
  `pointer_motion_interval pointer_motion_interval_resize pointer_modifier`.
- `contrib/zsh_completion`: en `input=(...)`, después de `pointer_motion_interval` añade
  `pointer_motion_interval_resize`.

```bash
make doc VERCMD=false && git diff --stat doc/bspwm.1
```

Expected: solo unas pocas líneas nuevas (mismo criterio que en la tarea 3).

Commit con el autor original:

```bash
git add src/ doc/ contrib/
git commit --author="Loic Coyle <loic.coyle@hotmail.fr>" \
  -m "feat: add pointer_motion_interval_resize" \
  -m "Resizing applications that redraw slowly (OpenGL terminals, for instance) needs a lower motion interval than moving does, and lowering pointer_motion_interval made moves feel jumpy. Resizes now use their own interval." \
  -m "Ported from baskerville/bspwm#1284 (commits f42fd34 and 04dd82a)."
```

- [ ] **Step 4: Ver que pasa**

```bash
make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "interval|RED:|ALL GREEN"
```

Expected: ningún aviso, todo `PASS` y `ALL GREEN`.

- [ ] **Step 5: Commit de la prueba**

```bash
git add tests/headless/resize_motion_interval.sh tests/run_headless
git commit -m "test: cover pointer_motion_interval_resize"
git push -u origin upstream-1284-resize-motion-interval
```

---

### Task 12: #1035 — minimizar y restaurar (rama `upstream-1035-iconify`)

**Files:**
- Create: `tests/headless/iconify.sh`
- Modify: `src/backend_x11.c`, `src/backend_x11.h`, `src/events.c`, `tests/run_headless`

**Interfaces:**
- Consumes: `set_hidden(monitor_t *, desktop_t *, node_t *, bool)` y
  `arrange(monitor_t *, desktop_t *)` (`tree.h`); `get_atom(const char *, xcb_atom_t *)`
  (`backend_x11.c`); `XCB_ICCCM_WM_STATE_ICONIC` y `XCB_ICCCM_WM_STATE_WITHDRAWN`
  (`xcb_icccm.h`, ya incluido desde `backend_x11.h`).
- Produces: `extern xcb_atom_t WM_CHANGE_STATE;` en `backend_x11.h`.

- [ ] **Step 1: Rama y prueba**

```bash
cd /websites/personal/bspwm
git switch -c upstream-1035-iconify upstream/master
```

Crea `tests/headless/iconify.sh`:

```sh
# Clients and task bars can iconify a window, and activating it restores it.

echo ""
echo "== Iconify =="

node_hidden() {
	$BSPC query -T -n "$1" 2>/dev/null | grep -o '"hidden":[a-z]*' | head -1 | cut -d: -f2
}

if [ "$BACKEND" = "x11" ] && [ -f ./test_window ] && command -v xdotool >/dev/null 2>&1; then
	./test_window iconify-a Iconify >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	# XIconifyWindow(): a WM_CHANGE_STATE client message with IconicState.
	xdotool windowminimize "$W"
	sleep 0.3
	assert_eq "a client can iconify its window" "true" "$(node_hidden "$W")"
	# What a task bar sends to bring a window back: _NET_ACTIVE_WINDOW.
	xdotool windowactivate "$W" >/dev/null 2>&1 || true
	sleep 0.3
	assert_eq "activating an iconified window shows it" "false" "$(node_hidden "$W")"
	assert_eq "and focuses it" "$W" "$($BSPC query -N -n focused 2>/dev/null)"
	$BSPC node "$W" -c
	sleep 0.3
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: iconify (needs X11, test_window, xdotool)"
fi
```

En `tests/run_headless`, antes de `# ---- Quit ----`, añade `. ./headless/iconify.sh`.

- [ ] **Step 2: Ver que falla**

```bash
make test 2>&1 | grep -E "iconif|shows it|focuses it|RED:|ALL GREEN"
```

Expected: `FAIL: a client can iconify its window` (actual `false`) y `RED:`. Las otras dos
pueden pasar o fallar: sin el cambio la ventana nunca llegó a ocultarse.

- [ ] **Step 3: Portar el PR**

`src/backend_x11.c`:
- después de `xcb_atom_t WM_DELETE_WINDOW;` añade `xcb_atom_t WM_CHANGE_STATE;`;
- en `x11_setup_atoms`, después de `	get_atom("WM_TAKE_FOCUS", &WM_TAKE_FOCUS);` añade
  `	get_atom("WM_CHANGE_STATE", &WM_CHANGE_STATE);`.

`src/backend_x11.h`: después de `extern xcb_atom_t WM_DELETE_WINDOW;` añade
`extern xcb_atom_t WM_CHANGE_STATE;`.

`src/events.c`, en `client_message`:
- en la rama `_NET_ACTIVE_WINDOW`, inmediatamente antes de
  `		focus_node(loc.monitor, loc.desktop, loc.node);` añade:

```c
		set_hidden(loc.monitor, loc.desktop, loc.node, false);
		arrange(loc.monitor, loc.desktop);
```

- sustituye

```c
	} else if (e->type == ewmh->_NET_CLOSE_WINDOW) {
		close_node(loc.node);
	}
```

por:

```c
	} else if (e->type == ewmh->_NET_CLOSE_WINDOW) {
		close_node(loc.node);
	} else if (e->type == WM_CHANGE_STATE) {
		/* XIconifyWindow() from the client, or a task bar minimizing it. */
		bool iconic = e->data.data32[0] == XCB_ICCCM_WM_STATE_ICONIC ||
		              e->data.data32[0] == XCB_ICCCM_WM_STATE_WITHDRAWN;
		set_hidden(loc.monitor, loc.desktop, loc.node, iconic);
		arrange(loc.monitor, loc.desktop);
	}
```

Commit con el autor original:

```bash
git add src/backend_x11.c src/backend_x11.h src/events.c
git commit --author="nwwdles <nwwdles@gmail.com>" \
  -m "feat: handle WM_CHANGE_STATE and show windows on activation" \
  -m "Task bars and clients minimize windows with XIconifyWindow(), which sends WM_CHANGE_STATE; it was ignored. A _NET_ACTIVE_WINDOW request for a hidden window now shows it before focusing it, so clicking a minimized task brings it back." \
  -m "Ported from baskerville/bspwm#1035 (commit d7e5555)."
```

- [ ] **Step 4: Ver que pasa**

```bash
make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "iconif|shows it|focuses it|RED:|ALL GREEN"
```

Expected: ningún aviso, tres `PASS` y `ALL GREEN`.

- [ ] **Step 5: Commit de la prueba**

```bash
git add tests/headless/iconify.sh tests/run_headless
git commit -m "test: check iconifying and restoring a window"
git push -u origin upstream-1035-iconify
```

---

### Task 13: #1183 — `_NET_WM_MOVERESIZE` para mover (rama `upstream-1183-net-wm-moveresize`)

**Files:**
- Create: `tests/send_moveresize.c`, `tests/headless/drag.sh` (idéntico al de la tarea 4),
  `tests/headless/net_wm_moveresize.sh`
- Modify: `src/pointer.c`, `src/pointer.h`, `src/events.c`, `src/backend_x11.c`,
  `src/settings.h`, `src/settings.c`, `src/messages.c`, `doc/bspwm.1.asciidoc`, `doc/bspwm.1`,
  `contrib/*_completion`, `tests/Makefile`, `tests/run_headless`, `.gitignore`,
  `.github/workflows/release.yaml`

**Interfaces:**
- Produces:
  - `void pointer_move_node(coordinates_t loc);` en `pointer.h`: agarra el puntero y mueve
    `loc.node` hasta que se suelta el botón;
  - `extern bool allow_net_wm_moveresize;` en `settings.h`, por defecto `true`;
  - `tests/send_moveresize WINDOW X Y DIRECTION BUTTON`.

- [ ] **Step 1: Rama, ayudantes, cliente de prueba y prueba**

```bash
cd /websites/personal/bspwm
git switch -c upstream-1183-net-wm-moveresize upstream/master
```

Crea `tests/headless/drag.sh` con el contenido exacto de la tarea 4, añade
`. ./headless/drag.sh` antes de `# ---- TESTS ----` en `tests/run_headless`, y haz la misma
edición en `release.yaml`.

`tests/send_moveresize.c`:

```c
/* Send a _NET_WM_MOVERESIZE client message for a window, as a client that
 * draws its own title bar does to ask the window manager for a drag.
 * Usage: send_moveresize WINDOW X Y DIRECTION BUTTON */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xcb/xcb.h>

int main(int argc, char **argv)
{
	if (argc != 6) {
		fprintf(stderr, "usage: %s WINDOW X Y DIRECTION BUTTON\n", argv[0]);
		return 2;
	}
	xcb_connection_t *dpy = xcb_connect(NULL, NULL);
	if (xcb_connection_has_error(dpy))
		return 1;
	xcb_screen_t *screen = xcb_setup_roots_iterator(xcb_get_setup(dpy)).data;
	const char *name = "_NET_WM_MOVERESIZE";
	xcb_intern_atom_reply_t *atom = xcb_intern_atom_reply(dpy,
		xcb_intern_atom(dpy, 0, strlen(name), name), NULL);
	if (atom == NULL)
		return 1;

	xcb_client_message_event_t ev;
	memset(&ev, 0, sizeof(ev));
	ev.response_type = XCB_CLIENT_MESSAGE;
	ev.format = 32;
	ev.window = strtoul(argv[1], NULL, 0);
	ev.type = atom->atom;
	ev.data.data32[0] = strtoul(argv[2], NULL, 0);
	ev.data.data32[1] = strtoul(argv[3], NULL, 0);
	ev.data.data32[2] = strtoul(argv[4], NULL, 0);
	ev.data.data32[3] = strtoul(argv[5], NULL, 0);
	ev.data.data32[4] = 1; /* source: a normal application */
	free(atom);

	xcb_send_event(dpy, 0, screen->root,
		XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY,
		(const char *) &ev);
	xcb_flush(dpy);
	xcb_disconnect(dpy);
	return 0;
}
```

`tests/Makefile`: después de `all: test_window test_window_wl` añade `all: send_moveresize`;
después de la regla de `test_window_wl` añade:

```make
send_moveresize: send_moveresize.c
	$(CC) $(CFLAGS) -o $@ $< -lxcb
```

y deja `clean:` con la misma línea exacta que en las tareas 2, 5 y 14. En `.gitignore`, después de
`tests/test_stress`, añade `tests/send_moveresize`.

`tests/headless/net_wm_moveresize.sh`:

```sh
# Clients that draw their own title bar ask for a move with _NET_WM_MOVERESIZE.

echo ""
echo "== _NET_WM_MOVERESIZE =="

assert_eq "client moves are allowed by default" "true" "$($BSPC config allow_net_wm_moveresize 2>/dev/null)"

if drag_tools_available && [ -x ./send_moveresize ]; then
	drag_setup
	$BSPC config edge_snap_enabled false
	W=$(spawn_floating moveresize 400x300+300+300)

	# Press on the empty root window, ask for a move, then move the pointer.
	xdotool mousemove 100 100
	sleep 0.1
	xdotool mousedown 1
	./send_moveresize "$W" 100 100 8 1
	sleep 0.3
	xdotool mousemove 200 200
	sleep 0.3
	assert_eq "a client-initiated move follows the pointer" "400 400 400 300" "$(win_geom "$W")"
	xdotool mouseup 1
	sleep 0.3

	$BSPC config allow_net_wm_moveresize false || true
	xdotool mousemove 100 100
	sleep 0.1
	xdotool mousedown 1
	./send_moveresize "$W" 100 100 8 1
	sleep 0.3
	xdotool mousemove 300 300
	sleep 0.3
	assert_eq "client moves are ignored when disabled" "400 400 400 300" "$(win_geom "$W")"
	xdotool mouseup 1
	sleep 0.3
	$BSPC config allow_net_wm_moveresize true || true

	$BSPC node "$W" -c
	sleep 0.3
	$BSPC config edge_snap_enabled true
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: client-initiated moves (needs X11, test_window, xdotool, xwininfo)"
fi
```

En `tests/run_headless`, antes de `# ---- Quit ----`, añade `. ./headless/net_wm_moveresize.sh`.

- [ ] **Step 2: Ver que falla**

```bash
make test 2>&1 | grep -E "client|RED:|ALL GREEN"
```

Expected: `FAIL` en «client moves are allowed by default» y en «a client-initiated move follows
the pointer» (la ventana sigue en `300 300 …`), y `RED:`.

- [ ] **Step 3: Refactorizar el inicio del arrastre (commit propio)**

En `src/pointer.c`, justo antes de `bool grab_pointer(pointer_action_t pac)`, añade:

```c
/* Grab the pointer and run a move or resize of `loc.node` until the button is
 * released. Shared by the pointer bindings and by clients that ask to be
 * moved through _NET_WM_MOVERESIZE. */
static void drag_node(coordinates_t loc, pointer_action_t pac, bspwm_point_t pos)
{
	if (loc.node->client->state == STATE_FULLSCREEN)
		return;

	xcb_grab_pointer_reply_t *reply = xcb_grab_pointer_reply(dpy,
		xcb_grab_pointer(dpy, 0, root,
		                 XCB_EVENT_MASK_BUTTON_RELEASE | XCB_EVENT_MASK_BUTTON_MOTION,
		                 XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC,
		                 BSPWM_WID_NONE, BSPWM_WID_NONE, XCB_CURRENT_TIME), NULL);

	if (!reply || reply->status != XCB_GRAB_STATUS_SUCCESS) {
		free(reply);
		return;
	}
	free(reply);

	/* Windows-like behavior: drag/resize raises the window to the top.
	 * Route through bspwm's own focus/stack machinery so the internal
	 * stacking list stays in sync with the X stack. */
	if (loc.node != mon->desk->focus) {
		focus_node(loc.monitor, loc.desktop, loc.node);
	} else {
		stack(loc.desktop, loc.node, true);
	}

	if (pac == ACTION_MOVE) {
		put_status(SBSC_MASK_POINTER_ACTION, "pointer_action 0x%08X 0x%08X 0x%08X move begin\n",
		          loc.monitor->id, loc.desktop->id, loc.node->id);
	} else if (pac == ACTION_RESIZE_CORNER) {
		put_status(SBSC_MASK_POINTER_ACTION, "pointer_action 0x%08X 0x%08X 0x%08X resize_corner begin\n",
		          loc.monitor->id, loc.desktop->id, loc.node->id);
	} else if (pac == ACTION_RESIZE_SIDE) {
		put_status(SBSC_MASK_POINTER_ACTION, "pointer_action 0x%08X 0x%08X 0x%08X resize_side begin\n",
		          loc.monitor->id, loc.desktop->id, loc.node->id);
	}

	track_pointer(loc, pac, pos);
}
```

En `grab_pointer`, sustituye todo desde
`	if (loc.node->client->state == STATE_FULLSCREEN)` hasta el cierre de la función por:

```c
	drag_node(loc, pac, pos);
	return true;
}
```

(El cuerpo de `drag_node` es ese mismo bloque movido: compara con `git diff` que solo cambia
de sitio y que `return true;` pasa a `return;`.)

```bash
make 2>&1 | grep -iE "warning|error"; make test 2>&1 | tail -n 2
git add src/pointer.c
git commit -m "refactor: share the start of a pointer drag"
```

Expected: ningún aviso y el mismo resultado que en el paso 2 (solo fallan las dos pruebas
nuevas).

- [ ] **Step 4: Portar el PR**

`src/pointer.c`, después de `grab_pointer`:

```c
void pointer_move_node(coordinates_t loc)
{
	if (loc.node == NULL || loc.node->client == NULL)
		return;
	bspwm_point_t pos;
	query_pointer(NULL, &pos);
	drag_node(loc, ACTION_MOVE, pos);
}
```

`src/pointer.h`: después de la declaración de `track_pointer`, añade
`void pointer_move_node(coordinates_t loc);`.

`src/settings.h`: con los demás `#define` de valores por defecto (por ejemplo, después de
`#define EDGE_SNAP_THRESHOLD         20`), añade `#define ALLOW_NET_WM_MOVERESIZE     true`, y
después de `extern int edge_snap_threshold;` añade `extern bool allow_net_wm_moveresize;`.

`src/settings.c`: después de `int edge_snap_threshold;` añade `bool allow_net_wm_moveresize;`,
y después de `edge_snap_threshold = EDGE_SNAP_THRESHOLD;` añade
`	allow_net_wm_moveresize = ALLOW_NET_WM_MOVERESIZE;`.

`src/messages.c`: justo antes de `#undef SET_BOOL` añade
`		SET_BOOL(allow_net_wm_moveresize)`, y justo antes de `#undef GET_BOOL` añade
`	GET_BOOL(allow_net_wm_moveresize)`.

`src/backend_x11.c`, en `x11_setup_ewmh_supported`, después de `		ewmh->_NET_WM_DESKTOP,`
añade `		ewmh->_NET_WM_MOVERESIZE,`.

`src/events.c`, en `client_message`, antes de
`	} else if (e->type == ewmh->_NET_CLOSE_WINDOW) {` añade:

```c
	} else if (e->type == ewmh->_NET_WM_MOVERESIZE) {
		/* Clients that draw their own title bar ask the window manager to
		 * drag them. Only moving is handled. */
		if (allow_net_wm_moveresize && e->data.data32[2] == XCB_EWMH_WM_MOVERESIZE_MOVE)
			pointer_move_node(loc);
```

`doc/bspwm.1.asciidoc`, después de la entrada `'ignore_ewmh_struts'::` y su línea en blanco:

```
'allow_net_wm_moveresize'::
	Let clients start a move of their own window with *_NET_WM_MOVERESIZE*, as applications that draw their own title bar do. Only moving is handled. Defaults to *true*.

```

Autocompletado:
- `contrib/bash_completion` y `contrib/fish_completion`: cambia
  `ignore_ewmh_struts center_pseudo_tiled` por
  `ignore_ewmh_struts allow_net_wm_moveresize center_pseudo_tiled`.
- `contrib/zsh_completion`: añade `allow_net_wm_moveresize` al final de `behaviour_bool=(...)`.

```bash
make doc VERCMD=false && git diff --stat doc/bspwm.1
```

Commit con el autor original:

```bash
git add src/ doc/ contrib/
git commit --author="Jeffrey McAteer <jeffrey.p.mcateer@gmail.com>" \
  -m "feat: handle _NET_WM_MOVERESIZE move requests" \
  -m "Applications that draw their own title bar (mpv, client-side decorated toolkits) ask the window manager to move them with _NET_WM_MOVERESIZE. The move case now starts the same pointer drag as the move binding; allow_net_wm_moveresize turns it off. Resizing from client-drawn edges is not handled." \
  -m "Ported from baskerville/bspwm#1183 (commits 760465d, ab7947c and d7a31ad)."
```

- [ ] **Step 5: Ver que pasa**

```bash
make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "client|RED:|ALL GREEN"
```

Expected: ningún aviso, tres `PASS` y `ALL GREEN`.

- [ ] **Step 6: Commits de pruebas y CI**

```bash
git add tests/send_moveresize.c tests/Makefile tests/headless/drag.sh tests/headless/net_wm_moveresize.sh tests/run_headless .gitignore
git commit -m "test: check client-initiated moves"
git add .github/workflows/release.yaml
git commit -m "ci: install the X tools the drag tests use"
git push -u origin upstream-1183-net-wm-moveresize
```

---

### Task 14: Módulo puro `edge_zone` (rama `edge-snap-zones`)

**Files:**
- Create: `src/edge_zone.h`, `src/edge_zone.c`, `tests/test_edge_zone.c`, `tests/headless/edge_snap_zones.sh`
- Modify: `Makefile` (`CORE_SRC`), `tests/Makefile`, `tests/run_headless`, `.gitignore`

**Interfaces:**
- Consumes: `snap_zone_t` (`SNAP_NONE`, `SNAP_LEFT`, `SNAP_RIGHT`, `SNAP_TOP`, `SNAP_BOTTOM`,
  `SNAP_TOP_LEFT`, `SNAP_TOP_RIGHT`, `SNAP_BOTTOM_LEFT`, `SNAP_BOTTOM_RIGHT`,
  `SNAP_MAXIMIZE`) y `bspwm_rect_t` (`int16_t x, y; uint16_t width, height`), ambos de
  `types.h`, que exige `<stddef.h>` antes.
- Produces: `snap_zone_t edge_zone_at(int x, int y, bspwm_rect_t r, int threshold, double ratio);`

- [ ] **Step 1: Crear la rama**

```bash
cd /websites/personal/bspwm
git switch -c edge-snap-zones upstream/master
```

- [ ] **Step 2: Escribir la prueba unitaria**

`tests/test_edge_zone.c`:

```c
/* Unit tests for edge_zone.c: which snap zone a pointer position falls into. */

#include <stddef.h>
#include <stdio.h>
#include "../src/edge_zone.h"

static int failures;

static const char *zone_name(snap_zone_t z)
{
	switch (z) {
		case SNAP_NONE: return "none";
		case SNAP_LEFT: return "left";
		case SNAP_RIGHT: return "right";
		case SNAP_TOP: return "top";
		case SNAP_BOTTOM: return "bottom";
		case SNAP_TOP_LEFT: return "top_left";
		case SNAP_TOP_RIGHT: return "top_right";
		case SNAP_BOTTOM_LEFT: return "bottom_left";
		case SNAP_BOTTOM_RIGHT: return "bottom_right";
		case SNAP_MAXIMIZE: return "maximize";
	}
	return "?";
}

static void check(const char *desc, snap_zone_t expected, snap_zone_t actual)
{
	if (expected == actual) {
		printf("  PASS: %s\n", desc);
		return;
	}
	printf("  FAIL: %s: expected %s, got %s\n", desc, zone_name(expected), zone_name(actual));
	failures++;
}

int main(void)
{
	const bspwm_rect_t wide = {0, 0, 1920, 1080};
	const bspwm_rect_t tall = {3840, 0, 1440, 2560};

	/* Ratio 0.2 on 1920x1080: corners are the first and last 384 px of a
	 * horizontal edge and 216 px of a vertical one; the maximize band is
	 * [768, 1152). */
	check("top edge near the left corner is the top-left quarter",
	      SNAP_TOP_LEFT, edge_zone_at(100, 2, wide, 20, 0.2));
	check("last pixel of the corner segment",
	      SNAP_TOP_LEFT, edge_zone_at(383, 2, wide, 20, 0.2));
	check("first pixel past the corner segment is the top half",
	      SNAP_TOP, edge_zone_at(384, 2, wide, 20, 0.2));
	check("last pixel before the center band is the top half",
	      SNAP_TOP, edge_zone_at(767, 2, wide, 20, 0.2));
	check("first pixel of the center band maximizes",
	      SNAP_MAXIMIZE, edge_zone_at(768, 2, wide, 20, 0.2));
	check("the middle of the top edge maximizes",
	      SNAP_MAXIMIZE, edge_zone_at(960, 2, wide, 20, 0.2));
	check("last pixel of the center band maximizes",
	      SNAP_MAXIMIZE, edge_zone_at(1151, 2, wide, 20, 0.2));
	check("first pixel past the center band is the top half",
	      SNAP_TOP, edge_zone_at(1152, 2, wide, 20, 0.2));
	check("top edge near the right corner is the top-right quarter",
	      SNAP_TOP_RIGHT, edge_zone_at(1536, 2, wide, 20, 0.2));
	check("the bottom edge is the bottom half",
	      SNAP_BOTTOM, edge_zone_at(960, 1077, wide, 20, 0.2));
	check("bottom edge near the left corner is the bottom-left quarter",
	      SNAP_BOTTOM_LEFT, edge_zone_at(100, 1077, wide, 20, 0.2));
	check("bottom edge near the right corner is the bottom-right quarter",
	      SNAP_BOTTOM_RIGHT, edge_zone_at(1800, 1077, wide, 20, 0.2));
	check("left edge near the top is the top-left quarter",
	      SNAP_TOP_LEFT, edge_zone_at(2, 100, wide, 20, 0.2));
	check("left edge in the middle is the left half",
	      SNAP_LEFT, edge_zone_at(2, 540, wide, 20, 0.2));
	check("left edge near the bottom is the bottom-left quarter",
	      SNAP_BOTTOM_LEFT, edge_zone_at(2, 1000, wide, 20, 0.2));
	check("right edge in the middle is the right half",
	      SNAP_RIGHT, edge_zone_at(1917, 540, wide, 20, 0.2));
	check("right edge near the top is the top-right quarter",
	      SNAP_TOP_RIGHT, edge_zone_at(1917, 100, wide, 20, 0.2));
	check("the threshold is inclusive",
	      SNAP_MAXIMIZE, edge_zone_at(960, 20, wide, 20, 0.2));
	check("a pixel past the threshold is no zone",
	      SNAP_NONE, edge_zone_at(960, 21, wide, 20, 0.2));
	check("the middle of the monitor is no zone",
	      SNAP_NONE, edge_zone_at(960, 540, wide, 20, 0.2));

	/* A portrait monitor to the right of the first one: corners are 288 px
	 * of the top edge and 512 px of a side; the band is [4416, 4704). */
	check("offset monitor: left edge in the middle",
	      SNAP_LEFT, edge_zone_at(3842, 1280, tall, 20, 0.2));
	check("offset monitor: left edge near the top",
	      SNAP_TOP_LEFT, edge_zone_at(3842, 100, tall, 20, 0.2));
	check("offset monitor: center of the top edge",
	      SNAP_MAXIMIZE, edge_zone_at(4560, 2, tall, 20, 0.2));
	check("offset monitor: top edge near the left corner",
	      SNAP_TOP_LEFT, edge_zone_at(3900, 2, tall, 20, 0.2));

	/* Ratio 0 keeps the classic zones. */
	check("classic: the whole top edge maximizes",
	      SNAP_MAXIMIZE, edge_zone_at(500, 2, wide, 20, 0.0));
	check("classic: the bottom edge is no zone",
	      SNAP_NONE, edge_zone_at(960, 1077, wide, 20, 0.0));
	check("classic: left edge near the top is still the left half",
	      SNAP_LEFT, edge_zone_at(2, 100, wide, 20, 0.0));
	check("classic: a corner needs both edges",
	      SNAP_TOP_LEFT, edge_zone_at(2, 2, wide, 20, 0.0));
	check("classic: bottom-right corner",
	      SNAP_BOTTOM_RIGHT, edge_zone_at(1917, 1077, wide, 20, 0.0));

	return failures ? 1 : 0;
}
```

`tests/Makefile`: después de `all: test_window test_window_wl` añade `all: test_edge_zone`, y
después de la regla de `test_window_wl`:

```make
test_edge_zone: test_edge_zone.c ../src/edge_zone.c ../src/edge_zone.h
	$(CC) $(CFLAGS) -std=c23 -o $@ test_edge_zone.c ../src/edge_zone.c
```

Deja `clean:` con la misma línea exacta que en las tareas 2, 5 y 13:

```make
	$(RM) test_window test_window_wl test_color test_magnet send_moveresize test_edge_zone *.o
```

En `.gitignore`, después de `tests/test_stress`, añade `tests/test_edge_zone`.

Crea `tests/headless/edge_snap_zones.sh`:

```sh
# Edge snap zones: quarters near corners, top and bottom halves, and a
# centered band of the top edge that maximizes.

echo ""
echo "== Edge snap zones =="

assert_ok "edge zone unit tests pass" ./test_edge_zone
```

En `tests/run_headless`, antes de `# ---- Quit ----`, añade `. ./headless/edge_snap_zones.sh`.

- [ ] **Step 3: Ver que falla**

```bash
cd /websites/personal/bspwm/tests && make test_edge_zone 2>&1 | tail -n 2
```

Expected: `../src/edge_zone.h: No such file or directory`.

Crea `src/edge_zone.h` con la cabecera BSD de `src/snap.h` (líneas 1–23) y después:

```c
#ifndef BSPWM_EDGE_ZONE_H
#define BSPWM_EDGE_ZONE_H

/* types.h uses size_t without including <stddef.h>. */
#include <stddef.h>
#include "types.h"

/* Snap zone for a pointer at (x, y) on a monitor with rectangle `r`, when the
 * pointer is within `threshold` pixels of one of its edges.
 *
 * With `ratio` 0 the zones are the classic ones: a corner needs the pointer
 * at both edges, the whole top edge maximizes and the bottom edge is no zone.
 *
 * With `ratio` above 0, the part of an edge within `ratio` of its length from
 * a corner gives that quarter. On the top edge a centered band `ratio` of the
 * width wide maximizes and the rest gives the top half; the bottom edge gives
 * the bottom half and the sides the left and right halves.
 *
 * Pure geometry, so the unit tests drive it without a display. */
snap_zone_t edge_zone_at(int x, int y, bspwm_rect_t r, int threshold, double ratio);

#endif
```

Crea `src/edge_zone.c` con la cabecera BSD y un esqueleto:

```c
#include "edge_zone.h"

snap_zone_t edge_zone_at(int x, int y, bspwm_rect_t r, int threshold, double ratio)
{
	(void) x;
	(void) y;
	(void) r;
	(void) threshold;
	(void) ratio;
	return SNAP_NONE;
}
```

```bash
cd /websites/personal/bspwm/tests && make test_edge_zone >/dev/null && ./test_edge_zone; echo "salida: $?"
```

Expected: `PASS` solo en los casos que esperan `none`, `FAIL` en el resto, y `salida: 1`.

- [ ] **Step 4: Implementar**

Sustituye el cuerpo de `src/edge_zone.c` (bajo la cabecera BSD) por:

```c
#include <stdbool.h>
#include "edge_zone.h"

/* The zones as they were before `ratio`: corners only within the threshold of
 * both edges, the whole top edge maximizes, nothing on the bottom edge. */
static snap_zone_t classic_zone(bool at_left, bool at_right, bool at_top, bool at_bottom)
{
	if (at_left && at_top)
		return SNAP_TOP_LEFT;
	if (at_right && at_top)
		return SNAP_TOP_RIGHT;
	if (at_left && at_bottom)
		return SNAP_BOTTOM_LEFT;
	if (at_right && at_bottom)
		return SNAP_BOTTOM_RIGHT;
	if (at_top)
		return SNAP_MAXIMIZE;
	if (at_left)
		return SNAP_LEFT;
	if (at_right)
		return SNAP_RIGHT;
	return SNAP_NONE;
}

snap_zone_t edge_zone_at(int x, int y, bspwm_rect_t r, int threshold, double ratio)
{
	int x1 = r.x, y1 = r.y;
	int x2 = r.x + r.width, y2 = r.y + r.height;
	bool at_left = x <= x1 + threshold;
	bool at_right = x >= x2 - threshold;
	bool at_top = y <= y1 + threshold;
	bool at_bottom = y >= y2 - threshold;

	if (ratio <= 0)
		return classic_zone(at_left, at_right, at_top, at_bottom);
	if (!at_left && !at_right && !at_top && !at_bottom)
		return SNAP_NONE;

	/* The stretch of each edge that counts as a corner. The classic corner
	 * square still counts, however small the ratio. */
	int corner_w = (int) (ratio * r.width);
	int corner_h = (int) (ratio * r.height);
	bool near_left = at_left || x < x1 + corner_w;
	bool near_right = at_right || x >= x2 - corner_w;
	bool near_top = at_top || y < y1 + corner_h;
	bool near_bottom = at_bottom || y >= y2 - corner_h;

	if ((at_top && near_left) || (at_left && near_top))
		return SNAP_TOP_LEFT;
	if ((at_top && near_right) || (at_right && near_top))
		return SNAP_TOP_RIGHT;
	if ((at_bottom && near_left) || (at_left && near_bottom))
		return SNAP_BOTTOM_LEFT;
	if ((at_bottom && near_right) || (at_right && near_bottom))
		return SNAP_BOTTOM_RIGHT;

	if (at_top) {
		int half_band = (int) (ratio * r.width / 2);
		int center = x1 + r.width / 2;
		if (x >= center - half_band && x < center + half_band)
			return SNAP_MAXIMIZE;
		return SNAP_TOP;
	}
	if (at_bottom)
		return SNAP_BOTTOM;
	if (at_left)
		return SNAP_LEFT;
	return SNAP_RIGHT;
}
```

En el `Makefile` raíz, añade `edge_zone.c` al final de `CORE_SRC`.

- [ ] **Step 5: Ver que pasa**

```bash
cd /websites/personal/bspwm/tests && make test_edge_zone >/dev/null && ./test_edge_zone; echo "salida: $?"
cd .. && make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "edge zone unit|ALL GREEN|RED:"
```

Expected: 29 `PASS`, `salida: 0`, ningún aviso, `PASS: edge zone unit tests pass` y `ALL GREEN`.

- [ ] **Step 6: Commits**

```bash
git add src/edge_zone.c src/edge_zone.h Makefile
git commit -m "feat: add a backend-free edge snap zone module"
git add tests/test_edge_zone.c tests/Makefile tests/headless/edge_snap_zones.sh tests/run_headless .gitignore
git commit -m "test: unit-test the edge snap zones"
```

---

### Task 15: Ajuste `edge_snap_zone_ratio`, zonas nuevas y su vista previa (rama `edge-snap-zones`)

**Files:**
- Create: `tests/headless/drag.sh` (idéntico al de la tarea 4)
- Modify: `src/settings.h`, `src/settings.c`, `src/messages.c`, `src/snap.c`, `src/pointer.c`,
  `doc/bspwm.1.asciidoc`, `doc/bspwm.1`, `contrib/*_completion`,
  `tests/headless/edge_snap_zones.sh`, `tests/run_headless`, `.github/workflows/release.yaml`

**Interfaces:**
- Consumes: `edge_zone_at()` (tarea 14); `get_snap_zone(bspwm_point_t, monitor_t *)` en
  `snap.c`, que solo llama `pointer.c`.
- Produces: `extern double edge_snap_zone_ratio;` en `settings.h`, entre 0 y 0.5 y 0 por
  defecto.

- [ ] **Step 1: Ayudantes, CI y pruebas**

Crea `tests/headless/drag.sh` con el contenido exacto de la tarea 4, añade `. ./headless/drag.sh`
antes de `# ---- TESTS ----` en `tests/run_headless`, y haz la misma edición en `release.yaml`.

Añade al final de `tests/headless/edge_snap_zones.sh`:

```sh
assert_eq "zone ratio defaults to 0" "0.000000" "$($BSPC config edge_snap_zone_ratio 2>/dev/null)"
assert_ok "set the zone ratio" $BSPC config edge_snap_zone_ratio 0.2
assert_eq "zone ratio was set" "0.200000" "$($BSPC config edge_snap_zone_ratio 2>/dev/null)"
assert_fail "reject a zone ratio above 0.5" $BSPC config edge_snap_zone_ratio 0.6
assert_fail "reject a negative zone ratio" $BSPC config edge_snap_zone_ratio -0.1
assert_fail "reject a zone ratio that is not a number" $BSPC config edge_snap_zone_ratio wide

node_state() {
	$BSPC query -T -n "$1" 2>/dev/null | grep -o '"state":"[a-z_]*"' | head -1 | cut -d'"' -f4
}

# Mapped override-redirect unnamed InputOutput child of the root: the preview.
zone_preview() {
	for w in $(xwininfo -root -children | awk '/^ +0x/ && /\(has no name\)/ {print $1}'); do
		info=$(xwininfo -id "$w")
		echo "$info" | grep -q 'Map State: IsViewable' || continue
		echo "$info" | grep -q 'Override Redirect State: yes' || continue
		echo "$info" | grep -q 'Class: InputOutput' || continue
		echo "$w"
		return
	done
}

# Drag a fresh floating window from the middle of the screen until the pointer
# is at (x, y), release it there, and print its id.
zone_drop() {
	local name="$1" x="$2" y="$3" w
	w=$(spawn_floating "$name" 400x300+760+390)
	drag_begin 1 960 540
	drag_to "$x" "$y"
	drag_end 1
	echo "$w"
}

# Geometry a window gets from `bspc node -S ZONE`.
zone_reference() {
	local zone="$1" c
	c=$(spawn_floating "zone-ref-$zone" 200x200+100+100)
	$BSPC node "$c" -S "$zone"
	sleep 0.3
	win_geom "$c"
	$BSPC node "$c" -c
	sleep 0.3
}

if drag_tools_available; then
	drag_setup
	$BSPC config edge_snap_enabled true
	$BSPC config edge_snap_zone_ratio 0.2 || true

	W=$(zone_drop zone-corner 100 2)
	assert_eq "near a corner the window takes that quarter" "$(zone_reference top_left)" "$(win_geom "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	W=$(zone_drop zone-top 500 2)
	assert_eq "the top edge off center gives the top half" "$(zone_reference top)" "$(win_geom "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	W=$(zone_drop zone-center 960 2)
	assert_eq "the center of the top edge maximizes" "fullscreen" "$(node_state "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	W=$(zone_drop zone-bottom 960 1077)
	assert_eq "the bottom edge gives the bottom half" "$(zone_reference bottom)" "$(win_geom "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	W=$(zone_drop zone-side 2 540)
	assert_eq "a side gives that half" "$(zone_reference left)" "$(win_geom "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	W=$(zone_drop zone-side-corner 2 1000)
	assert_eq "a side near a corner gives that quarter" "$(zone_reference bottom_left)" "$(win_geom "$W")"
	$BSPC node "$W" -c
	sleep 0.3

	# While hovering the top half, the preview shows it.
	W=$(spawn_floating zone-preview 400x300+760+390)
	drag_begin 1 960 540
	drag_to 500 2
	P=$(zone_preview)
	assert_eq "the preview shows the top half" "0 0 1920 540" "$(win_geom "$P")"
	drag_end 1
	$BSPC node "$W" -c
	sleep 0.3

	# Ratio 0: the classic zones.
	$BSPC config edge_snap_zone_ratio 0 || true
	W=$(zone_drop zone-classic-top 500 2)
	assert_eq "classic zones: the whole top edge maximizes" "fullscreen" "$(node_state "$W")"
	$BSPC node "$W" -c
	sleep 0.3
	W=$(zone_drop zone-classic-bottom 960 1077)
	REF=$(zone_reference bottom)
	assert_fail "classic zones: the bottom edge does nothing" [ "$REF" = "$(win_geom "$W")" ]
	$BSPC node "$W" -c
	sleep 0.3
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: edge snap zones (needs X11, test_window, xdotool, xwininfo)"
fi
```

- [ ] **Step 2: Ver que falla**

```bash
cd /websites/personal/bspwm && make test 2>&1 | grep -E "zone|quarter|half|maximizes|preview shows|classic|RED:|ALL GREEN"
```

Expected:
- `FAIL` en «zone ratio defaults to 0», «set the zone ratio», «zone ratio was set»,
  «near a corner…», «the top edge off center…», «the bottom edge gives…», «a side near a
  corner…» y «the preview shows the top half»;
- `PASS` en «the center of the top edge maximizes», «a side gives that half» y las dos
  clásicas;
- `RED:`.

- [ ] **Step 3: Implementar**

`src/settings.h`: después de `#define EDGE_SNAP_THRESHOLD         20` añade
`#define EDGE_SNAP_ZONE_RATIO        0.0`, y después de `extern int edge_snap_threshold;` añade
`extern double edge_snap_zone_ratio;`.

`src/settings.c`: después de `int edge_snap_threshold;` añade `double edge_snap_zone_ratio;`, y
después de `edge_snap_threshold = EDGE_SNAP_THRESHOLD;` añade
`	edge_snap_zone_ratio = EDGE_SNAP_ZONE_RATIO;`.

`src/messages.c`, en `set_setting`, después de `		edge_snap_threshold = t;`:

```c
	} else if (streq("edge_snap_zone_ratio", name)) {
		double r;
		if (sscanf(value, "%lf", &r) != 1 || r < 0 || r > 0.5) {
			fail(rsp, "config: %s: Invalid value: '%s' (must be 0-0.5).\n", name, value);
			return;
		}
		edge_snap_zone_ratio = r;
```

`src/messages.c`, en `get_setting`, después de `		fprintf(rsp, "%i", edge_snap_threshold);`:

```c
	} else if (streq("edge_snap_zone_ratio", name)) {
		fprintf(rsp, "%lf", edge_snap_zone_ratio);
```

`src/snap.c`: añade `#include "edge_zone.h"` junto a los demás `#include "…"`, y sustituye
`get_snap_zone` entera por:

```c
snap_zone_t get_snap_zone(bspwm_point_t pos, monitor_t *m)
{
	if (!edge_snap_enabled || !m)
		return SNAP_NONE;
	return edge_zone_at(pos.x, pos.y, m->rectangle, edge_snap_threshold, edge_snap_zone_ratio);
}
```

`src/pointer.c`, en el `switch (zone)` de `show_snap_preview`, justo antes de
`		case SNAP_TOP_LEFT:`:

```c
		case SNAP_TOP:
			preview.x = rect.x;
			preview.y = rect.y;
			preview.width = rect.width;
			preview.height = rect.height / 2;
			break;
		case SNAP_BOTTOM:
			preview.x = rect.x;
			preview.y = rect.y + rect.height / 2;
			preview.width = rect.width;
			preview.height = rect.height / 2;
			break;
```

`doc/bspwm.1.asciidoc`, después de la entrada `'edge_snap_threshold'::` y su línea en blanco:

```
'edge_snap_zone_ratio'::
	Size of the edge snap zones, as a fraction of the monitor, from *0* to *0.5*. Within this fraction of an edge's length from a corner, a drag snaps to that quarter of the monitor. On the top edge, a centered band this fraction of the width wide maximizes and the rest snaps to the top half; the bottom edge snaps to the bottom half and the sides to the left and right halves. Above *1/3* the corners take over the center band. *0* keeps the classic zones: a corner needs the pointer at both edges, the whole top edge maximizes and the bottom edge does nothing. Defaults to *0*.

```

Autocompletado:
- `contrib/bash_completion` y `contrib/fish_completion`: cambia
  `edge_snap_threshold cascade_offset` por
  `edge_snap_threshold edge_snap_zone_ratio cascade_offset`.
- `contrib/zsh_completion`: en `input=(...)`, después de `edge_snap_threshold` añade
  `edge_snap_zone_ratio`.

```bash
make doc VERCMD=false && git diff --stat doc/bspwm.1
```

Expected: solo unas pocas líneas nuevas en `doc/bspwm.1` (mismo criterio que en la tarea 3).

- [ ] **Step 4: Ver que pasa**

```bash
make 2>&1 | grep -iE "warning|error"; make test 2>&1 | grep -E "zone|quarter|half|maximizes|preview shows|classic|RED:|ALL GREEN"
```

Expected: ningún aviso, todo `PASS` y `ALL GREEN`.

- [ ] **Step 5: Commits**

```bash
git add src/settings.h src/settings.c src/messages.c src/snap.c src/pointer.c doc/ contrib/
git commit -m "feat: add edge_snap_zone_ratio for corner quarters and top/bottom halves" \
  -m "Near a corner, within the ratio of the edge length, a drag snaps to that quarter. On the top edge only a centered band of that width maximizes and the rest snaps to the top half; the bottom edge snaps to the bottom half. The preview learns the two halves. A ratio of 0 keeps the classic zones."
git add tests/headless/drag.sh tests/headless/edge_snap_zones.sh tests/run_headless
git commit -m "test: check the edge snap zones"
git add .github/workflows/release.yaml
git commit -m "ci: install the X tools the drag tests use"
git push -u origin edge-snap-zones
```

---

### Task 16: Rama `local`

**Files:** los conflictos de la fusión (ver *Conflictos esperados*).

**Interfaces:**
- Consumes: las siete ramas anteriores.
- Produces: `origin/local` como rama por defecto del fork, con todo fundido y `make test` en
  verde.

- [ ] **Step 1: Fundir**

```bash
cd /websites/personal/bspwm
git switch -c local upstream/master
for b in edge-snap-preview-color magnet-edges edge-snap-zones upstream-1541-no-raise-on-focus \
         upstream-1284-resize-motion-interval upstream-1035-iconify upstream-1183-net-wm-moveresize; do
  git merge --no-ff --no-edit "$b" || break
done
git status --short | head
```

En cada conflicto, conserva **todas** las inserciones de ambos lados:
- en las listas, en el orden en que se funden las ramas;
- en `tests/run_headless`, todas las líneas `. ./headless/…`;
- en `tests/Makefile`, todas las líneas `all:` y todas las reglas;
- en `.gitignore`, todos los binarios.

En `src/pointer.c` pueden chocar la vista previa ARGB (tarea 4), el imán (tareas 7 y 8), el
intervalo de resize (tarea 11), `drag_node` (tarea 13) y los casos nuevos de la vista previa
(tarea 15). El resultado correcto tiene todos a la vez: la creación ARGB de la ventana, los
casos `SNAP_TOP`/`SNAP_BOTTOM` en el `switch`, la línea
`uint32_t interval = …` sustituye a la comparación con `pointer_motion_interval`, las ramas de
mover y redimensionar llevan el imán, y `grab_pointer` llama a `drag_node`.

Tras resolver:

```bash
git add -A && git commit --no-edit
```

y vuelve a lanzar el bucle con las ramas que faltan.

- [ ] **Step 2: Verificar**

```bash
make clean && make 2>&1 | grep -iE "warning|error"; make test 2>&1 | tail -n 3
git log --oneline upstream/master..local | wc -l
```

Expected: ningún aviso, `ALL GREEN` con N + las pruebas nuevas, y más de 20 commits.

- [ ] **Step 3: Publicar y hacerla la rama por defecto**

```bash
git push -u origin local
gh repo edit maflorezp/bspwm1 --default-branch local
gh repo view maflorezp/bspwm1 --json defaultBranchRef,visibility --jq '"\(.defaultBranchRef.name) \(.visibility)"'
```

Expected: `local PUBLIC`

---

### Task 17: Paquete `bspwm1-maflorezp-git` [SESIÓN]

**Files:**
- Create: `~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/PKGBUILD`, `build.sh`, `.gitignore`

**Interfaces:**
- Consumes: `origin/local` (tarea 16).
- Produces: el paquete instalado; `bspc config magnet_threshold` responde.

- [ ] **Step 1: Comprobación previa (debe fallar)**

```bash
pacman -Q bspwm1-maflorezp-git; bspc config magnet_threshold
```

Expected: `error: package 'bspwm1-maflorezp-git' was not found` y
`config: Unknown setting: 'magnet_threshold'.`

- [ ] **Step 2: Escribir el paquete**

`~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/PKGBUILD`:

```bash
# Maintainer: Mauricio Alexander Flórez (maflorezp)
#
# bspwm1 (rotkonetworks) con los cambios propios de la rama `local` del fork
# github.com/maflorezp/bspwm1: imán de bordes, vista previa y zonas del
# Aero Snap y cuatro PRs de bspwm original. Sustituye al bspwm1 de AUR y al
# bspwm oficial. Diseño y plan: docs/superpowers/ en este repo (tras la tarea
# 20, docs/maflorezp/ en el fork).

pkgname=bspwm1-maflorezp-git
_srcname=bspwm1
pkgver=1.6.2
pkgrel=1
pkgdesc="bspwm1 con cambios propios: imán de bordes y zonas del Aero Snap"
arch=('x86_64')
url="https://github.com/maflorezp/bspwm1"
license=('BSD-2-Clause')
depends=('libxcb' 'xcb-util' 'xcb-util-keysyms' 'xcb-util-wm' 'libxkbcommon')
makedepends=('git')
optdepends=('sxhkd: keybinding daemon')
provides=('bspwm' 'bspwm1')
conflicts=('bspwm' 'bspwm1')
source=("${_srcname}::git+${url}.git#branch=local")
sha256sums=('SKIP')

# Versión de paquete VCS: último tag, commits desde él y hash (1.6.2.r25.gabcdef0).
pkgver() {
	cd "${_srcname}"
	git describe --long --tags --abbrev=7 | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g'
}

build() {
	cd "${_srcname}"
	make
}

package() {
	cd "${_srcname}"
	make DESTDIR="$pkgdir" PREFIX=/usr install
}
```

`~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/build.sh`:

```bash
#!/usr/bin/env bash
# Compila e instala bspwm1-maflorezp-git sin ensuciar los dotfiles: makepkg
# trabaja en ~/.cache/pkgbuilds en vez de junto al PKGBUILD, donde el
# auto-commit subiría fuentes y paquetes. Pide sudo y confirmación para
# sustituir al bspwm1 instalado.
set -euo pipefail

DIR="$(dirname "$(realpath "$0")")"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/pkgbuilds"
mkdir -p "$CACHE/build" "$CACHE/src" "$CACHE/pkg"

cd "$DIR"
BUILDDIR="$CACHE/build" SRCDEST="$CACHE/src" PKGDEST="$CACHE/pkg" \
	makepkg --syncdeps --install --cleanbuild "$@"
```

`~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/.gitignore`:

```
# build.sh manda el trabajo de makepkg a ~/.cache/pkgbuilds; esto cubre el caso
# de lanzar makepkg a mano desde aquí.
src/
pkg/
bspwm1/
*.pkg.tar*
*.log
```

```bash
chmod +x ~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/build.sh
bash -n ~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/build.sh && echo "sintaxis OK"
cd ~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git && makepkg --printsrcinfo | grep -E "pkgname|provides|conflicts|source"
```

Expected: `sintaxis OK`, y `provides`/`conflicts` con `bspwm` y `bspwm1`, y `source` apuntando
a la rama `local`.

- [ ] **Step 3: Instalar (lo hace Mauricio)**

Pídele que ejecute en su terminal:

```bash
~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/build.sh
```

Pacman preguntará si quita `bspwm1`: la respuesta es **sí**. Espera a que confirme.

- [ ] **Step 4: Activar (lo hace Mauricio o lo autoriza)**

```bash
bspc wm -r
```

El socket ya está en `$XDG_RUNTIME_DIR` desde bspwm1, así que no hace falta cerrar sesión.

- [ ] **Step 5: Verificar la sesión**

```bash
pacman -Q bspwm1-maflorezp-git; bspwm -v
ls -l "/proc/$(pgrep -x bspwm | head -1)/exe" | awk '{print $NF}'
for s in magnet_threshold edge_snap_preview_color edge_snap_preview_opacity edge_snap_zone_ratio pointer_motion_interval_resize allow_net_wm_moveresize; do
  printf '%s = %s\n' "$s" "$(bspc config "$s")"
done
pgrep -a bspc | grep subscribe | awk '{$1=""; print}' | sort | uniq -c
for p in polybar sxhkd; do for pid in $(pgrep -x $p); do tr '\0' '\n' < /proc/$pid/environ | grep -q '^BSPWM_SOCKET=' && echo "$p $pid OK" || echo "$p $pid SIN SOCKET"; done; done
```

Expected:
- `bspwm1-maflorezp-git 1.6.2.r…` y una versión que empieza por `v1.6.2`;
- `/usr/bin/bspwm` (sin `(deleted)`);
- `magnet_threshold = 0`, `edge_snap_preview_color = #E6007A`,
  `edge_snap_preview_opacity = 25`, `edge_snap_zone_ratio = 0.000000`,
  `pointer_motion_interval_resize = 17` y `allow_net_wm_moveresize = true`;
- perfil de subscribers: `all` ×2, `monitor` ×1, `node_focus` ×2 y `report` ×1;
- `OK` en todos los polybar y en sxhkd.

El PKGBUILD lo sube solo el auto-commit de los dotfiles. No hace falta commit manual.

---

### Task 18: Configuración propia y verificación en vivo [SESIÓN]

**Files:**
- Modify: `~/.dotFiles/.config/bspwm/bspwm_config.sh`

- [ ] **Step 1: Comprobación previa (debe fallar)**

```bash
bspc config magnet_threshold; bspc config edge_snap_preview_color
```

Expected: `0` y `#E6007A`.

- [ ] **Step 2: Añadir los ajustes**

En `~/.dotFiles/.config/bspwm/bspwm_config.sh`, después de la línea
`bspc config pointer_action3           resize_corner`:

```bash

# Imán de bordes, y color y zonas del Aero Snap. Solo existen en
# bspwm1-maflorezp-git; con otro bspwm se saltan en silencio. Con 0.2, cada
# borde del monitor se reparte en tramos del 20 %: esquinas (cuartos de
# pantalla), mitades y, en el centro del borde superior, maximizar.
if bspc config magnet_threshold >/dev/null 2>&1; then
    bspc config magnet_threshold          20
    bspc config edge_snap_preview_color   '#04dd29'
    bspc config edge_snap_preview_opacity 25
    bspc config edge_snap_zone_ratio      0.2
fi
```

```bash
bash -n ~/.dotFiles/.config/bspwm/bspwm_config.sh && bash ~/.dotFiles/.config/bspwm/bspwm_config.sh
bspc config magnet_threshold; bspc config edge_snap_preview_color; bspc config edge_snap_preview_opacity; bspc config edge_snap_zone_ratio
```

Expected: `20`, `#04dd29`, `25` y `0.200000`.

- [ ] **Step 3: Verificación en vivo, con permiso**

Pregunta a Mauricio si puedes mover su ratón unos 20 segundos. Con su permiso, usa una ventana
desechable, como el 2026-09-16 (`/tmp/aero_en_vivo.sh` sirve de modelo), en su monitor grande
(`DisplayPort-2`, 3840×2160, padding 35 arriba y 32 abajo, borde 2):
- abre `kitty --class snaptest` flotante en `400x300+1500+800` (regla
  `bspc rule -a snaptest -o state=floating rectangle=400x300+1500+800`);
- **imán en vivo**: Alt + botón 1 en su centro, lleva el puntero hasta que el borde izquierdo
  libre quede a 8 px de x=0 y, **con el botón pulsado**, comprueba con `xwininfo` que la
  ventana está en `x=0`. Suelta;
- **vista previa**: Alt + botón 1 y puntero en x=2. Con el botón pulsado, busca la ventana
  override-redirect sin nombre (la función `preview_window` de la tarea 4) y comprueba que
  `xwd -id … -silent -nobdrs | tail -c 4 | od -An -tx1` da `0a 36 00 3f` (`#04dd29` al 25 %,
  premultiplicado);
- cierra la kitty y devuelve el ratón a su posición.

Después pide a Mauricio que confirme a ojo cuatro cosas:
1. la vista previa es verde y translúcida;
2. al arrastrar una ventana flotante hacia otra, se pega mientras la mueve;
3. arrastrando Chrome o mpv por su propia barra de título, también se pega (#1183);
4. en los dos monitores, llevar el puntero cerca de una esquina da un cuarto, el centro del
   borde superior maximiza, el resto de ese borde da la mitad superior y el borde inferior la
   mitad inferior, con su vista previa en cada caso.

---

### Task 19: Retirar el imán de bash [SESIÓN]

**Files:**
- Modify: `~/.dotFiles/.config/bspwm/bspwm_subscribers.sh`
- Delete: `~/.dotFiles/.config/bspwm/bspwm_snap.sh`, `~/.dotFiles/.config/bspwm/bspwm_snap-tests/`
- Modify: `~/.claude/projects/-home-maflorez--dotFiles/memory/bspwm-subscribers-reinicio.md`

- [ ] **Step 1: Comprobación previa**

```bash
cd ~/.dotFiles/.config/bspwm
grep -n "bspwm_snap.sh\|_pointer_snap" bspwm_subscribers.sh
bash bspwm_subscribers-tests/run_all_tests.sh 2>&1 | tail -n 1
```

Expected: aparecen el `source "$DIR/bspwm_snap.sh"`, la función `_pointer_snap` y su lanzamiento
comentado; las pruebas de subscribers están en verde.

- [ ] **Step 2: Quitar el código**

En `bspwm_subscribers.sh`, elimina:
- el bloque `# Aritmetica del iman de bordes…` y la línea `source "$DIR/bspwm_snap.sh"`;
- el bloque de comentarios `# Iman de bordes para ventanas flotantes…` y la función
  `_pointer_snap` completa;
- las dos líneas del lanzamiento comentado
  (`# Iman al soltar, desactivado…` y `# _pointer_snap &`).

Guardar el fichero dispara la recarga en caliente, y eso es lo esperado.

```bash
cd ~/.dotFiles/.config/bspwm
command rm -f bspwm_snap.sh
command rm -rf bspwm_snap-tests
bash -n bspwm_subscribers.sh && echo "sintaxis OK"
grep -c "snap" bspwm_subscribers.sh
bash bspwm_subscribers-tests/run_all_tests.sh 2>&1 | tail -n 1
sleep 6; pgrep -a bspc | grep subscribe | awk '{$1=""; print}' | sort | uniq -c
```

Expected:
- `sintaxis OK`;
- `0`, o solo menciones sin relación con el imán (revísalas);
- `TODO VERDE - 2 ficheros de prueba`;
- el perfil `all` ×2, `monitor` ×1, `node_focus` ×2 y `report` ×1, sin duplicados.

- [ ] **Step 3: Actualizar la memoria**

En `bspwm-subscribers-reinicio.md`, cambia la frase sobre `pointer_action node_geometry` para que
diga que ese subscriber ya no existe: el imán vive dentro de bspwm (paquete
`bspwm1-maflorezp-git`) desde que se completó este plan.

---

### Task 20: Mudar la documentación al fork

**Files:**
- Create (en `local`): `docs/maflorezp/2026-09-16-iman-de-bordes-bspwm1-diseno.md`,
  `docs/maflorezp/2026-09-16-iman-de-bordes-bspwm1-plan.md`
- Delete (en `~/.dotFiles`): `docs/superpowers/specs/2026-09-16-iman-de-bordes-bspwm1-diseno.md`,
  `docs/superpowers/plans/2026-09-16-iman-de-bordes-bspwm1.md`
- Modify: `~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/PKGBUILD` (comentario de cabecera)

- [ ] **Step 1: Copiar y publicar**

```bash
cd /websites/personal/bspwm && git switch local
mkdir -p docs/maflorezp
cp ~/.dotFiles/docs/superpowers/specs/2026-09-16-iman-de-bordes-bspwm1-diseno.md docs/maflorezp/
cp ~/.dotFiles/docs/superpowers/plans/2026-09-16-iman-de-bordes-bspwm1.md docs/maflorezp/2026-09-16-iman-de-bordes-bspwm1-plan.md
sed -i 's|docs/superpowers/specs/2026-09-16-iman-de-bordes-bspwm1-diseno.md|docs/maflorezp/2026-09-16-iman-de-bordes-bspwm1-diseno.md|' docs/maflorezp/*.md
git add docs/maflorezp
git commit -m "docs: diseño y plan del imán de bordes y del fork"
git push origin local
```

- [ ] **Step 2: Quitar las copias de los dotfiles y actualizar referencias**

```bash
command rm -f ~/.dotFiles/docs/superpowers/specs/2026-09-16-iman-de-bordes-bspwm1-diseno.md \
              ~/.dotFiles/docs/superpowers/plans/2026-09-16-iman-de-bordes-bspwm1.md
```

En el PKGBUILD, cambia la línea `# Aero Snap y cuatro PRs de bspwm original. …` y las dos
siguientes por:

```bash
# Aero Snap y cuatro PRs de bspwm original. Sustituye al bspwm1 de AUR y al
# bspwm oficial. Diseño y plan: docs/maflorezp/ en la rama local del fork
# (/websites/personal/bspwm).
```

```bash
grep -rn "2026-09-16-iman-de-bordes" ~/.dotFiles ~/.claude/projects/-home-maflorez--dotFiles/memory 2>/dev/null | grep -v '/\.git/'
gh api 'repos/maflorezp/bspwm1/contents/docs/maflorezp?ref=local' --jq '.[].name'
```

Expected: el `grep` no encuentra referencias a las rutas viejas (si encuentra, actualízalas), y
GitHub lista los dos ficheros.

- [ ] **Step 3: Cierre**

Informa a Mauricio:
- las ramas listas para PR, que son las siete de las tareas 2–15;
- que los PRs los abre él cuando quiera;
- que antes de abrirlos conviene compilar el backend Wayland (`make BACKEND=wlroots`), para lo
  que necesita `wlroots0.20` y `wlr-protocols`;
- que las ramas de los PRs de bspwm original conservan como autor a su autor original, y que
  al proponerlas a rotkonetworks conviene decirlo en la descripción.
