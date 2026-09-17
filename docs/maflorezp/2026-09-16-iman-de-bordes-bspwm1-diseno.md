# Imán de bordes y vista previa configurable para bspwm1 — diseño

Fecha: 2026-09-16
Estado: aprobado (2026-09-16). Plan: `docs/maflorezp/2026-09-16-iman-de-bordes-bspwm1-plan.md`

## Objetivo

Que las ventanas flotantes **se peguen en vivo**, mientras se mueven o se redimensionan con el
ratón, a los bordes de la pantalla y a los bordes de las demás ventanas. Y, de paso, que la
vista previa del Aero Snap de bspwm1 tenga un color configurable y la transparencia que su
código ya pretendía tener. Y que las zonas del Aero Snap sean más útiles: cuartos al acercarse
a una esquina, mitad superior e inferior, y maximizar solo desde una franja central del borde
de arriba, todo con una sola proporción configurable.

Además se incorporan cuatro PRs que siguen abiertos en bspwm original (baskerville/bspwm) y
que bspwm1 no tiene: #1541, #1284, #1035 y #1183 (ver *PRs de bspwm original*).

Todo vive en un fork público, `maflorezp/bspwm1`, clonado en `/websites/personal/bspwm`, y
Mauricio lo usa desde un paquete propio que sustituye al `bspwm1` de AUR. **Los PRs a
[rotkonetworks/bspwm1](https://github.com/rotkonetworks/bspwm1) quedan para después:** Mauricio
lo usará unas semanas y, si todo va bien, los abrirá él. El trabajo deja las ramas listas para
eso.

## Contexto: por qué en C y por qué sobre bspwm1

**No se puede hacer desde fuera de bspwm.** Durante un arrastre, `track_pointer` (`pointer.c`)
solo atiende eventos de X con `xcb_wait_for_event`: no sirve el socket. Cualquier `bspc` que
llegue durante el arrastre se queda esperando hasta que se suelta el botón. Se comprobó el
2026-09-15 con un demonio en bash: sus consultas en `pointer_action ... begin` ya devolvían la
geometría final. El imán en vivo tiene que ir dentro de ese bucle.

**Ese demonio de bash pegaba al soltar** (`_pointer_snap` y `bspwm_snap.sh`). Funcionaba, pero
no era lo que se quería. Está comentado en `bspwm_subscribers.sh` y se retira al final de este
trabajo (ver *Limpieza*).

**bspwm1 es la base porque:**

- Tiene actividad real y acepta contribuciones de terceros: siete versiones entre agosto y
  septiembre de 2026. Upstream (baskerville/bspwm) funde un PR al año.
- Trae arreglos útiles para este escritorio con dos monitores: cuelgues con un monitor enfocado
  obsoleto, reenfoque al desconectar un monitor y `ignore_monitor_updates`.
- Ya tiene el módulo `snap.c` (Aero Snap) y un `PKGBUILD` con `provides/conflicts=bspwm`.
- Está instalado desde AUR (`bspwm1 1.6.1-1`) y funcionando desde el 2026-09-16.

## Decisiones tomadas

| Decisión | Elección | Motivo |
|---|---|---|
| Dónde vive el imán | Dentro de `track_pointer`, solo en arrastres con ratón | Tocarlo en `move_client`/`resize_client` afectaría a `bspc node -v/-z`: los scripts no moverían donde piden y con el teclado una ventana pegada no se podría despegar |
| Ventanas afectadas | Solo flotantes | En tiled el redimensionado ya es pegajoso por construcción |
| Contra qué pega | Área útil del monitor y bordes de las demás ventanas visibles del escritorio | Pedido explícito |
| Tipo de pegado con ventanas | A tope **y** en línea | Pedido explícito, para poder formar filas y columnas |
| Ajuste del imán | Un solo `magnet_threshold`, global, en píxeles, `0` = apagado | Se configura como los demás con `bspc config`. `snap_threshold` se descartó porque se confunde con `edge_snap_threshold` del Aero Snap |
| Convivencia con el Aero Snap | Independientes | El Aero Snap depende del puntero y actúa al soltar; el imán depende de los bordes de la ventana y actúa en vivo. Si se suelta dentro de una zona, gana la zona |
| Vista previa | `edge_snap_preview_color` + `edge_snap_preview_opacity`, visual ARGB de 32 bits si existe | El color actual está fijo en el código y su transparencia nunca funcionó |
| Zonas del Aero Snap | Una proporción `edge_snap_zone_ratio` (0–0.5) fija a la vez el tramo de cada borde que cuenta como esquina y el ancho de la franja central del borde superior que maximiza; fuera de eso, el borde superior da la mitad superior y el inferior la mitad inferior | Pedido explícito: un solo valor para esquinas y franja. Una proporción se adapta a monitores de 3840 y 1440 de ancho |
| Zonas por defecto | `edge_snap_zone_ratio 0` conserva las zonas actuales: esquinas solo a `edge_snap_threshold` de ambos bordes, todo el borde superior maximiza y el inferior no hace nada | Nadie que no lo toque nota cambios |
| Valores por defecto upstream | `magnet_threshold 0`, rosa `#E6007A` al 25 % | Nadie que no toque su configuración nota cambios, salvo que la transparencia prometida pasa a funcionar |
| Base y destino | Fork `maflorezp/bspwm1`, PRs a rotkonetworks/bspwm1 | Ver *Contexto* |
| PRs | Una rama independiente por cambio, lista para proponer; se abren **después** de unas semanas de uso, y los abre Mauricio | Cada cambio tiene su alcance y su riesgo, y conviene probarlos en uso real antes de proponerlos |
| PRs de bspwm original | Se incorporan #1541, #1284, #1035 y #1183, una rama cada uno, conservando al autor original | Pedido explícito; ver *PRs de bspwm original* |
| Dónde vive el código | Clon del fork en `/websites/personal/bspwm`; rama por defecto `local`, que es la que ve quien visita el repo | Pedido explícito: repo público junto a los demás proyectos personales |
| Documentación de este trabajo | Se muda al repo (rama `local`) como **última** tarea | Pedido explícito; las ramas de PR no la llevan |
| Identidad de los commits en el fork | `Mauricio Alexander Flórez <maflorezp@gmail.com>` | El correo global de git es el de la empresa y quedaría público en GitHub |
| Convenciones del fork | Las de bspwm1: código, **comentarios**, commits y PRs en inglés, con su formato de commits y su estilo | El objetivo es que los PRs se puedan aceptar. Lo propio (PKGBUILD, dotfiles, este documento) sigue en español |
| Instalación | Paquete `bspwm1-maflorezp-git` en los dotfiles que sustituye a `bspwm1` | Pacman lo registra, las actualizaciones no lo pisan a escondidas y se vuelve atrás con una orden |
| Nombre del paquete | `bspwm1-maflorezp-git`, por el fork que compila | Es el vehículo de **todos** los cambios propios sobre bspwm1, no solo del imán; un nombre atado a una función se quedaría corto con el siguiente ajuste |
| Configuración propia | `magnet_threshold 20`, color `#04dd29` al 25 %, `edge_snap_zone_ratio 0.2` | El verde es el `presel_feedback_color` que ya se usa para «aquí irá la ventana». Con 0.2, cada borde se reparte en tramos del 20 % |

## Hechos verificados

Comprobados el 2026-09-15 y el 2026-09-16 sobre bspwm1 `v1.6.1` (código clonado en
`/tmp/bspwm1-explorar`) y sobre la sesión real.

- **La geometría de X**: `(x, y)` es la esquina exterior, con el borde incluido; ancho y alto
  son interiores. El borde exterior derecho está en `x + ancho + 2·border_width`. Lo confirma
  una ventana tiled de la sesión: en un hueco de 3840 px tiene `x=0` y ancho 3836 con borde 2.
  (La versión de bash lo modelaba mal y dejaba 4 px de borde fuera de pantalla a la derecha y
  abajo.)
- **El área útil** se calcula en `arrange()` sumando el padding del monitor y el del
  escritorio. Monitores reales: `DisplayPort-2` 3840×2160 en (0,0), padding 35 arriba y 32
  abajo; `HDMI-A-0` 1440×2560 en (3840,0), padding 32 abajo.
- **`track_pointer` en bspwm1** aplica `move_client(&loc, dx, dy)` al mover, y
  `resize_client(&loc, rh, dx, dy, true)` (o la variante absoluta con `honor_size_hints`) al
  redimensionar. El Aero Snap se evalúa en la misma rama de movimiento, y la zona se aplica
  tras el bucle con `apply_snap_zone`. `move_client` ya transfiere el nodo al cruzar de monitor.
- **El Aero Snap funciona en la sesión real.** Arrastrando una kitty con el puntero en x=2, la
  vista previa existía (1920×2093 en 0,35) y al soltar la ventana ocupó esa región.
  `edge_snap_enabled` está en `true` y `edge_snap_threshold` en `20` por defecto. Solo actúa al
  mover (`pac == ACTION_MOVE`).
- **La vista previa se crea con `XCB_COPY_FROM_PARENT`** y el píxel `0x40E6007A` («Semi-
  transparent pink» según el comentario). La raíz de la sesión tiene profundidad 24, así que el
  alfa se descarta y sale opaca. Existe un visual TrueColor de 32 bits (`0x89`), y Xvfb también
  ofrece visuales de 32 bits, lo que permite probarlo.
- **El relleno de una ventana ARGB se puede leer en Xvfb** con `xwd -id VENTANA -nobdrs`: los
  cuatro últimos bytes son el último píxel en orden B G R A (`byte_order` 0). Sin `-nobdrs`,
  `xwd` incluye el borde y devuelve su color. Comprobado con una ventana `0x7F007F00`, que dio
  `00 7f 00 7f`.
- **bspwm1 ya sabe colocar la mitad superior y la inferior**: `SNAP_TOP` y `SNAP_BOTTOM` existen
  y `apply_snap_zone` los coloca, pero solo se llega a ellos con `bspc node -S top|bottom`.
  `get_snap_zone` nunca los elige (el borde superior siempre maximiza y el inferior no hace
  nada) y `show_snap_preview` no sabe dibujarlos. Hoy las esquinas son un cuadrado de
  `edge_snap_threshold` píxeles.
- **`types.h` solo compila si antes se incluye `<stddef.h>`**: `backend.h` usa `size_t` sin
  incluirlo. Con ese orden, un módulo puro que use `snap_zone_t` y `bspwm_rect_t` se prueba sin
  enlazar nada más.
- **La vista previa se destruye al terminar cada arrastre** (`destroy_snap_preview`), así que
  un ajuste nuevo se aplica desde el siguiente arrastre sin más trabajo.
- **El backend Wayland no tiene vista previa**: en `backend_wlr.c` no hay ninguna referencia a
  `snap_preview`.
- **Los ajustes enteros** se validan con `sscanf` y un rango en `messages.c` (por ejemplo,
  `edge_snap_threshold` acepta 1–100). Ningún identificador contiene «magnet».
- **Pruebas**: `make test` compila y ejecuta `tests/run_headless [x11|wlroots]`, un ejecutor
  rojo-verde que arranca el WM en un display sin cabeza. El CI (`release.yaml`) lo corre para
  los dos backends. `run_headless` hace `unset BSPWM_SOCKET`; si no, el WM de prueba se quedaría
  con el socket de la sesión real y lo borraría al salir.
- **Estilo**: C23 con `-pedantic -Wall -Wextra -Wvla -Wformat=2 -Wnull-dereference` y otros;
  tabuladores (`.editorconfig`).
- **El socket de bspwm1** está en `$XDG_RUNTIME_DIR` y se exporta como `BSPWM_SOCKET` a todo lo
  que lanza. El `internal/bspwm` de polybar lo hereda y funciona.

## Arquitectura

### 1. Cambio A — vista previa configurable (rama `edge-snap-preview-color`)

**Ajustes nuevos**

| Ajuste | Tipo | Defecto | Validación |
|---|---|---|---|
| `edge_snap_preview_color` | color `#RRGGBB` | `#E6007A` | `is_hex_color`, con las macros `SET_COLOR`/`GET_COLOR` de `messages.c`, como los colores de borde |
| `edge_snap_preview_opacity` | entero | `25` | 0–100 |

Se declaran en `settings.h`/`settings.c`, se leen y escriben en `messages.c` y se documentan en
`doc/bspwm.1.asciidoc` (con `doc/bspwm.1` regenerado) y en los autocompletados de `contrib/`.
Solo los usa el backend X11; el manual lo dice.

**Dibujo** (`show_snap_preview`, `pointer.c`)

- Si la pantalla tiene un visual TrueColor de 32 bits, la ventana se crea con él, con un
  colormap propio y con `CW_BORDER_PIXEL` y `CW_COLORMAP` explícitos (obligatorios cuando la
  profundidad no es la del padre).
- El relleno usa el color con alfa **premultiplicado**, que es lo que espera un compositor.
- El borde de 2 px usa el mismo color, opaco, para que la región se lea bien.
- Sin visual de 32 bits se conserva el camino actual (opaco).
- Sin compositor, una ventana ARGB se ve opaca con el color premultiplicado, más oscuro. Se
  documenta.

**Pruebas**

- Validación de los ajustes: valores fuera de rango y formatos de color inválidos se rechazan,
  y `bspc config` devuelve lo que se fijó.
- En `run_headless` (X11): durante un arrastre a una zona, la vista previa existe con
  profundidad 32; con otro color u opacidad fijados, el siguiente arrastre la crea con los
  valores nuevos.

### 2. Cambio B — imán (rama `magnet-edges`)

**Ajuste nuevo**: `magnet_threshold`, entero de 0 a 100, validado igual que
`edge_snap_threshold` (que acepta 1–100) pero admitiendo el 0. Vale `0` por defecto, que es
apagado. Es global.

**Módulo puro `src/magnet.c` / `magnet.h`**, sin X, al estilo de `snap.c`. Recibe:

- el rectángulo **libre** de la ventana, es decir, donde estaría sin imán, en coordenadas
  exteriores;
- los bordes de la ventana que se están moviendo: los cuatro al mover, los del tirador al
  redimensionar;
- el área útil del monitor;
- los rectángulos exteriores de las demás ventanas;
- el umbral.

Devuelve el rectángulo exterior pegado.

Reglas:

- **Al mover**, en cada eje compiten los dos bordes y gana el candidato más cercano dentro del
  umbral. La ventana se traslada sin cambiar de tamaño.
- **Al redimensionar**, cada borde del tirador se pega por su cuenta y el opuesto no se mueve.
- **Candidatos**: los bordes del área útil del monitor (el borde inicial contra el inicial y el
  final contra el final) y, por cada otra ventana:
  - *a tope*: mi inicio contra su final, mi final contra su inicio;
  - *en línea*: inicio con inicio, final con final.
- **Proximidad en el otro eje**: una ventana solo aporta candidatos en un eje si en el otro se
  solapa con la ventana arrastrada o está a una distancia no mayor que el umbral. Sin esta
  regla, en vivo, un borde se engancharía al pasar por la coordenada de cualquier ventana del
  escritorio, aunque estuviera en la otra punta.
- **El umbral es inclusivo**, y con `0` no se pega nada.
- **Para despegar** basta con seguir arrastrando: el rectángulo libre sigue al puntero, y en
  cuanto se aleja más que el umbral la ventana lo vuelve a seguir.

**Integración en `track_pointer`** (solo si `magnet_threshold > 0` y la ventana es flotante)

- Al empezar el arrastre, el rectángulo libre es la geometría exterior actual.
- En cada `MOTION_NOTIFY` se le suma el desplazamiento del puntero:
  - al mover, a `x` e `y`;
  - al redimensionar en modo relativo, a los bordes del tirador;
  - en modo absoluto (`honor_size_hints`), los bordes del tirador salen de la posición del
    puntero.
- Se reúnen los candidatos del monitor y del escritorio actuales (`loc`, que `move_client`
  actualiza al cruzar de monitor) recorriendo las hojas con `first_extrema`/`next_leaf`. Se
  omiten la propia ventana, los nodos sin cliente y los ocultos. El rectángulo de cada una sale
  de `get_rectangle` más su propio `border_width`.
- Se llama a `magnet.c` y la diferencia entre el rectángulo pegado y el actual se aplica con
  `move_client` o `resize_client`, en relativo o en absoluto según el modo. Así el transfer de
  monitor, los tamaños mínimos y los size hints siguen como están. Con size hints, el redondeo a
  celdas puede dejar la ventana a menos de una celda del objetivo; se documenta.
- El Aero Snap no cambia: su zona se decide por el puntero y, si al soltar hay zona,
  `apply_snap_zone` la aplica encima.

**Documentación**: `doc/bspwm.1.asciidoc` y `bspwm.1`, y los autocompletados de `contrib/`.

**Pruebas**

- Unitarias de `magnet.c`, en C y sin X. Portan los casos de la suite de bash y añaden los
  nuevos:
  - gana el candidato más cercano;
  - el umbral es inclusivo y con `0` no hay pegado;
  - al mover compiten los dos bordes; al redimensionar solo cuentan los del tirador;
  - a tope y en línea;
  - la proximidad en el otro eje (una ventana lejana no atrae, una contigua sí);
  - el área útil descuenta el padding;
  - el borde exterior se calcula con el `border_width` de cada ventana;
  - la ventana se despega cuando el rectángulo libre sale del umbral.

  Requisito: `make test` las ejecuta y su fallo pone la suite en rojo. El plan decide cómo
  engancharlas después de leer `tests/run_headless` y `tests/Makefile` enteros.
- En `run_headless` (X11), con `test_window` y arrastres de `xdotool` sobre el display sin
  cabeza. **La geometría se consulta a X con el botón todavía pulsado**, porque es la prueba de
  que el pegado es en vivo. Casos:
  - borde de pantalla;
  - a tope contra otra ventana;
  - en línea;
  - despegar siguiendo el arrastre;
  - redimensionar por lado y por esquina;
  - una ventana lejana que no atrae;
  - una tiled que no se toca;
  - `magnet_threshold 0` sin cambios de comportamiento;
  - paso de monitor con dos monitores virtuales (`bspc wm -a`);
  - soltar en una zona del Aero Snap, donde gana la zona.

  Si `xdotool` no está en el CI de bspwm1, se añade a sus dependencias en el mismo PR.
- La suite existente (`make test`) debe seguir verde en X11, y el backend wlroots debe seguir
  compilando.

### 3. Cambio C — zonas del Aero Snap (rama `edge-snap-zones`)

**Ajuste nuevo**: `edge_snap_zone_ratio`, decimal de 0 a 0.5 (se lee como `split_ratio`, con
`%lf`), por defecto `0`. Es global.

**Módulo puro `src/edge_zone.c` / `edge_zone.h`**: `edge_zone_at(x, y, rect, threshold, ratio)`
devuelve la zona. `get_snap_zone` solo comprueba `edge_snap_enabled` y lo llama con el
rectángulo del monitor.

- **Con `ratio` 0**, las zonas actuales tal cual.
- **Con `ratio` > 0**, el puntero tiene que tocar un borde (a `threshold` píxeles o menos) y
  gana la primera regla que se cumpla:
  1. **Esquina**: está a menos de `ratio` × largo del borde de una esquina, en ese borde o en el
     contiguo. Va al cuarto de pantalla de esa esquina.
  2. **Borde superior**: dentro de la franja central de ancho `ratio` × ancho, maximiza; fuera
     de ella, va a la mitad superior.
  3. **Borde inferior**: mitad inferior.
  4. **Bordes laterales**: mitad izquierda o derecha.
- Con `ratio` 0.2, cada borde horizontal queda en cinco tramos iguales. Por encima de 1/3, las
  esquinas se comen la franja central. Se documenta.

**Vista previa**: `show_snap_preview` añade los casos `SNAP_TOP` y `SNAP_BOTTOM`.

**Documentación**: manual y autocompletados.

**Pruebas**
- Unitarias de `edge_zone.c`:
  - cada tramo con `ratio` 0.2, con los límites exactos de cada tramo;
  - un monitor que no empieza en el origen;
  - las zonas clásicas con `ratio` 0.
- En `run_headless` (X11):
  - validación del ajuste;
  - arrastres que sueltan en una esquina (cuarto), en la franja central (pantalla completa), en
    el resto del borde superior (mitad superior), en el borde inferior (mitad inferior) y en un
    lateral;
  - la vista previa de la mitad superior;
  - con `ratio` 0, el borde inferior no hace nada y todo el superior maximiza.

  Las geometrías se comparan con una ventana de referencia colocada con `bspc node -S`.

### 4. Repositorio, ramas y PRs

- Fork `rotkonetworks/bspwm1` → `maflorezp/bspwm1`, público, clonado en
  `/websites/personal/bspwm`. Remotos: `origin` (el fork), `upstream` (rotkonetworks/bspwm1) y
  `baskerville` (baskerville/bspwm, para traer sus PRs).
- Ramas desde `upstream/master` (hoy `v1.6.2`): `edge-snap-preview-color`, `magnet-edges`,
  `edge-snap-zones` y una
  por cada PR de bspwm original (ver sección 7), todas independientes. La rama `local` funde todas las ramas propias y es la que compila el paquete.
  Cada ajuste futuro sigue el mismo camino: su propia rama desde bspwm1 y un merge en `local`.
- La rama por defecto del fork es `local`. Su `master` refleja el de rotkonetworks sin cambios.
- Los PRs no se abren en este trabajo: los abre Mauricio tras unas semanas de uso.

**Convenciones de bspwm1 que se siguen** (sacadas de su historial y su código):

- Todo en inglés: identificadores, **comentarios**, mensajes de commit y descripción del PR.
- Comentarios solo con `/* */`; en `pointer.c` y `snap.c` no hay ningún `//`.
- Commits en formato Conventional Commits, como en su historial: `feat:` para cada ajuste
  nuevo, `fix:` para la transparencia, `test:` para las pruebas y `docs:` para el asciidoc.
  Sin trailer de Claude.
- Un `feat:` lleva juntos el código, los ajustes y el `doc/bspwm.1` regenerado (así se hizo
  `ignore_monitor_updates`, b25f2ac). El asciidoc puede ir en su propio `docs:`.
- **No se tocan `doc/CHANGELOG.md` ni `VERSION`.** Los escribe el mantenedor al publicar
  (v1.5.0 resume los commits de otro contribuidor). Lo que haría falta en el CHANGELOG se
  cuenta en la descripción del PR.
- Estilo: C23, tabuladores y los avisos estrictos del `Makefile` sin ningún aviso nuevo.
- Las pruebas siguen el ejecutor rojo-verde de `tests/run_headless`, y el PR muestra
  `make test` en verde.

### 5. Paquete `bspwm1-maflorezp-git`

- `~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/PKGBUILD`, derivado del de bspwm1:
  - `provides=('bspwm' 'bspwm1')` y `conflicts=('bspwm' 'bspwm1')`;
  - las mismas `depends` (`libxcb xcb-util xcb-util-keysyms xcb-util-wm libxkbcommon`);
  - `source` es la rama `local` del fork;
  - `pkgver()` sale de `git describe`, como corresponde a un paquete `-git`.
- La compilación va fuera del repo (`BUILDDIR`, `SRCDEST` y `PKGDEST` en
  `~/.cache/pkgbuilds`), y un `.gitignore` en el directorio del PKGBUILD evita que el
  auto-commit de los dotfiles suba fuentes o tarballs.
- Instalación: `makepkg -si`, que ejecuta Mauricio porque pide sudo. Para activarlo basta
  `bspc wm -r`: el socket ya está en `$XDG_RUNTIME_DIR` desde bspwm1 y no hace falta cerrar
  sesión.
- Vuelta atrás: `paru -S bspwm1` (AUR). Volver al `bspwm` oficial también es posible, pero
  requiere cerrar sesión porque el socket regresa a `/tmp` y polybar tiene el entorno viejo.
- Cuando un cambio entre en una versión publicada de bspwm1, su rama se retira de `local`. Si
  `local` se queda sin cambios propios, se vuelve al `bspwm1` de AUR y se retira el PKGBUILD.

### 6. Configuración propia

En `.config/bspwm/bspwm_config.sh`, junto a los ajustes del puntero:

```bash
bspc config magnet_threshold          20
bspc config edge_snap_preview_color   '#04dd29'
bspc config edge_snap_preview_opacity 25
bspc config edge_snap_zone_ratio      0.2
```

Solo se añaden cuando el paquete propio está instalado. Con el `bspwm1` de AUR serían ajustes
desconocidos y `bspc` avisaría en cada arranque.

### 7. PRs de bspwm original

Ninguno entra tal cual en bspwm1, que reorganizó mucho el código, así que cada uno se porta a
mano en su propia rama y **conserva al autor original** (`cherry-pick -x` cuando se puede;
`--author` y la referencia al PR cuando hay que reescribir).

| PR | Autor | Qué aporta | Rama |
|---|---|---|---|
| #1541 | Sean C. Farley | No sube la ventana enfocada al cambiar de escritorio o de monitor, que desordenaba las flotantes solapadas | `upstream-1541-no-raise-on-focus` |
| #1284 | Loic Coyle | Ajuste `pointer_motion_interval_resize`: intervalo propio al redimensionar, útil con aplicaciones OpenGL | `upstream-1284-resize-motion-interval` |
| #1035 | nwwdles | Maneja `WM_CHANGE_STATE`: una aplicación o barra de tareas puede minimizar, y activar una ventana oculta la muestra | `upstream-1035-iconify` |
| #1183 | Jeffrey McAteer | Maneja `_NET_WM_MOVERESIZE` para mover: las aplicaciones con barra de título propia piden el arrastre al gestor, y así el imán y el Aero Snap también actúan | `upstream-1183-net-wm-moveresize` |

Del #1183 solo se porta el caso de mover, con el ajuste `allow_net_wm_moveresize` (por defecto
`true`). Su versión original no compila con los avisos de bspwm1 (rango `case A ... B:`,
comentarios `//`) y deja una función vacía para redimensionar; nada de eso se trae. El inicio
del arrastre se comparte con `grab_pointer`, para que las dos vías eleven la ventana y emitan
`pointer_action ... begin` igual.

Las pruebas siguen el mismo ejecutor: la configuración de cada ajuste; minimizar con
`xdotool windowminimize` y restaurar con `xdotool windowactivate`; que volver a un escritorio no
emita `node_stack`; y un arrastre pedido por `_NET_WM_MOVERESIZE` con un pequeño cliente de
prueba en C.

Evaluados y descartados: #917 (bspwm1 ya lo tiene), #1246 (solo actúa con
`pointer_follows_focus`, apagado aquí), #1251 (bspwm1 ya distingue `honor_size_hints` entre
tiled y flotantes) y el resto, ajenos a este escritorio.

### 8. Limpieza del intento anterior

Cuando el imán funcione en la sesión real y sus casos estén portados a C:

- se retiran `_pointer_snap` (ya comentado), `bspwm_snap.sh` y `bspwm_snap-tests/`;
- se conservan `_self_reload` y `_kill_matching` y sus pruebas en `bspwm_subscribers-tests/`;
- se actualiza la memoria `bspwm-subscribers-reinicio`.

### 9. Mudanza de la documentación

Como última tarea, esta especificación y su plan se mudan a la rama `local` del fork (en
`docs/maflorezp/`), y el PKGBUILD y la memoria pasan a referirse a esa ubicación. En
`.dotFiles` queda solo el paquete.

## Fuera de alcance

- **Abrir los PRs** a rotkonetworks/bspwm1: los abre Mauricio después de unas semanas de uso.
- **Proponer el imán a baskerville/bspwm.** Su `pointer.c` es distinto y el parche no entraría
  limpio. Se puede portar después si hay interés.
- **Los demás PRs abiertos de bspwm original.**
- **Imán con teclado o con `bspc node -v/-z`**: la decisión de la tabla lo excluye.
- **Imán y vista previa en el backend Wayland (`bspwm-wl`)**: la arquitectura deja el cálculo
  en un módulo sin X para que se pueda enchufar después.
- **Los 10 commits de upstream que bspwm1 no tiene** («Handle SIGCHLD», «Revamp signal
  handling», etc.). Como mucho, se avisa a rotkonetworks en un issue aparte.
- **Ajustes separados para pegar al monitor y a ventanas**: con un solo umbral basta mientras
  no se demuestre lo contrario.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| rotkonetworks no acepta los PRs o tarda | El paquete propio no depende de ello |
| bspwm1 cambia rápido y hay que hacer rebase de las ramas | Cambios pequeños y aislados en módulos propios |
| Coste por movimiento del ratón | Recorre las hojas de un solo escritorio; se mide con `benches/` si hace falta |
| Redondeo de size hints | Documentado; el usuario tiene `honor_size_hints false` |
| Una prueba del WM que toque la sesión real | Siempre sobre display sin cabeza y con `BSPWM_SOCKET` aislado, como hace `run_headless` |
| Pruebas en vivo moviendo el ratón real | Solo con permiso y como verificación final; el grueso va en el display sin cabeza |
| Volver al `bspwm1` de AUR con los ajustes nuevos en la configuración | Avisos de `bspc` sin efecto; retirar las tres líneas |

## Criterios de aceptación

1. Con `magnet_threshold 20`:
   - al mover una ventana flotante, su borde queda pegado **con el botón todavía pulsado** al
     borde del monitor o de otra ventana en cuanto está a 20 px o menos;
   - se despega al seguir arrastrando;
   - al redimensionar pasa lo mismo, solo con los bordes del tirador.
2. Con `magnet_threshold 0` el comportamiento es el de bspwm1 sin cambios.
3. El Aero Snap sigue funcionando, y soltar dentro de una zona aplica la zona.
4. Con `edge_snap_zone_ratio 0.2`:
   - soltar cerca de una esquina da el cuarto de pantalla;
   - la franja central del borde superior maximiza y el resto de ese borde da la mitad
     superior;
   - el borde inferior da la mitad inferior;
   - la vista previa muestra cada caso.

   Con `0`, las zonas son las de hoy.
5. La vista previa usa `edge_snap_preview_color` y `edge_snap_preview_opacity` desde el
   siguiente arrastre, y con picom se ve translúcida.
6. `make test` está en verde con las pruebas nuevas. Antes de abrir cualquier PR, el backend
   wlroots también compila (aquí faltan `wlroots0.20` y `wlr-protocols`).
7. El paquete `bspwm1-maflorezp-git` está instalado y la sesión funciona: polybar, sxhkd,
   subscribers con su perfil correcto, y `bspc wm -r` sin duplicados.
8. Los cuatro PRs de bspwm original funcionan en la rama `local`, cada uno con su prueba.
9. Cada cambio está en su rama, con las convenciones de bspwm1, listo para proponerse.
10. El intento de bash está retirado, según *Limpieza*.
11. La documentación está en `/websites/personal/bspwm` (rama `local`) y el repo es público.

## Anexo: cómo terminó la ejecución (2026-09-16)

El plan se ejecutó con subagentes, en paralelo por ramas y cada una en su propio `git worktree`.
Cada tarea pasó por una revisión antes de darse por buena, y al final hubo una revisión de toda
la rama `local`. Este anexo recoge tres cosas: lo que cambió respecto al diseño, los fallos que
aparecieron al usarlo y lo que queda antes de proponer los PRs.

### Ramas

Todas salen de `upstream/master` (4cc03f1, bspwm1 v1.6.2) y están en `origin`. `local` las
funde todas y es la rama por defecto del fork.

| Rama | Cabeza | Commits | Contenido |
|---|---|---|---|
| `edge-snap-preview-color` | 9de2bd1 | 9 | Color y opacidad de la vista previa; vista previa ARGB translúcida |
| `magnet-edges` | f18c6d1 | 15 | Imán en vivo al mover y redimensionar, también entre monitores; ignora los bordes tapados |
| `edge-snap-zones` | 4d9710b | 10 | Cuartos, mitades superior e inferior y banda que maximiza; las zonas caben en pantalla |
| `upstream-1541-no-raise-on-focus` | 854000b | 2 | Port de baskerville/bspwm#1541 |
| `upstream-1284-resize-motion-interval` | 7c6cac4 | 2 | Port de #1284 |
| `upstream-1035-iconify` | 3f64544 | 2 | Port de #1035 |
| `upstream-1183-net-wm-moveresize` | c5c0007 | 10 | Port de #1183, ampliado: mover, redimensionar y cancelar |
| `fix-transfer-focus` | 4e7ebe0 | 2 | Fallo de bspwm1: foco perdido al pasar una ventana a otro monitor |
| `fix-automatic-selector` | 61ac93d | 3 | Fallo de bspwm1: modificador de selector `automatic` invertido |
| `local` | 6452afd | 67 | Todas fundidas; `make test` en verde (170/170) |

Los ports conservan como autor a su autor original: Sean C. Farley, Loic Coyle, nwwdles y
Jeffrey McAteer. Al proponerlos a rotkonetworks conviene decirlo en la descripción.

### Fallos encontrados al usarlo, ya corregidos

Mauricio instaló el paquete, lo usó y encontró estos fallos. La revisión final encontró uno
más. Todos están corregidos en su rama e instalados.

1. **Imán fantasma** (`magnet-edges`).
   - **Síntoma:** el imán usaba todas las ventanas del escritorio, también las tapadas. El caso
     real fue KeePassXC: flotante, *sticky* y tapada por Chrome en monocle, atraía ventanas en
     x=3/y=46 en todos los escritorios.
   - **Arreglo:** ahora un borde solo atrae en los tramos que ninguna ventana apilada encima
     tapa. El orden de apilado se lee de X (`xcb_query_tree`) una vez por arrastre.
2. **Aero Snap desfasado** (`edge-snap-zones`).
   - **Síntoma:** la zona se daba a la ventana como tamaño interior, y el borde la empujaba
     2×`border_width` fuera, bajo polybar o fuera del monitor. Pasaba también en las zonas
     clásicas de bspwm1.
   - **Arreglo:** una función pura, `edge_zone_rect`, calcula la zona para la ventana y para la
     vista previa. Descuenta el borde y da a la segunda mitad el píxel sobrante de un largo
     impar.
3. **Foco perdido al cambiar de monitor** (`fix-transfer-focus`, fallo de bspwm1).
   - **Causa:** `transfer_node` revalidaba el foco guardado con `find_by_id` mientras el nodo
     movido estaba fuera del árbol. Lo descartaba, y el escritorio de destino enfocaba y subía
     su propia ventana.
4. **Ventana nueva en el escritorio anterior** (`fix-automatic-selector`, fallo de bspwm1
   desde a920b89).
   - **Causa:** en `node_matches`, las ramas del modificador `automatic` estaban
     intercambiadas. `newest.!automatic` devolvía la última ventana enfocada sin preselección,
     y `bspwm_external_rules.sh` mandaba allí la ventana nueva con `follow=on`. Afectaba también
     a `super + y` y a `bspwm_smart_presel.sh`.
   - **Por qué apareció ahora:** con bspwm 0.9.12, que Mauricio usaba hasta ese día, no
     pasaba.
   - **Comprobación:** una auditoría de 2061 consultas contra baskerville no encontró más
     inversiones.
5. **Ventanas GTK con barra propia sin redimensionado por el borde**
   (`upstream-1183-net-wm-moveresize`, hallazgo de la revisión final).
   - **Causa:** al anunciar `_NET_WM_MOVERESIZE`, GTK y Qt dejan de emular el arrastre y se lo
     piden al gestor, pero el port solo atendía el movimiento.
   - **Arreglo:** ahora se atienden las direcciones 0–7 con el borde exacto, además de mover y
     de cancelar (11). El átomo solo se anuncia si `allow_net_wm_moveresize` está activo.
   - **Comprobación:** se hizo con una ventana GTK3 real en Xvfb.

### Correcciones al plan durante la ejecución

- **`edge_snap_zone_ratio`:** ahora rechaza `nan`. La validación del plan lo aceptaba, y eso
  acababa en un cast indefinido.
- **`_NET_WM_MOVERESIZE`:** se ignora en cuatro casos:
  - sin botón pulsado, también si el botón se suelta justo al tomar el grab (antes el grab se
    quedaba colgado hasta el siguiente clic);
  - durante otro arrastre;
  - en ventanas ocultas;
  - en escritorios no visibles.
- **`tests/send_moveresize.c`:** espera la respuesta del servidor antes de desconectar. Sin eso,
  el Xvfb perdía el mensaje.
- **Prueba de mosaico del imán:** se ajustó para que falle de verdad si se quita la guarda
  `IS_FLOATING`. Además, se añadió una prueba con `honor_size_hints`.
- **`.github/workflows/release.yaml`:** la edición va en la misma línea en todas las ramas, para
  que se fundan limpias.

### Decisiones de ejecución

- **Carriles en paralelo.** Cada rama tiene su worktree en `/websites/personal/bspwm-worktrees/`,
  y `make test` se serializa con `flock`.
- **Pruebas aisladas.** Las pruebas y la depuración se hicieron solo en Xvfb, nunca contra la
  sesión real.
- **Identidad.** Los commits del fork son de `Mauricio Alexander Flórez <maflorezp@gmail.com>`.
- **Manual.** `doc/bspwm.1` se editó a mano porque `a2x` no está instalado. Conviene regenerarlo
  con `make doc` cuando se instale `asciidoc`.
- **Push por SSH.** `origin` empuja por SSH (`remote.origin.pushurl`), porque el token HTTPS no
  tiene permiso para cambiar `.github/workflows`. Para volver a HTTPS:
  `gh auth refresh -h github.com -s workflow`.
- **Verificación en vivo.** La hizo Mauricio a mano (imán, zonas, vista previa, foco y
  escritorio vacío) en lugar de la comprobación con el ratón controlado por el agente.
- **Fallos heredados en ramas propias.** Los de bspwm1 van en ramas nuevas desde
  `upstream/master`, para que salgan como PRs independientes.

### Revisión final de `local`

- **Veredicto:** «Con correcciones».
- **Críticos:** ninguno.
- **Importante:** uno, el punto 5 de arriba, ya corregido.
- **Ramas:** todas compilan sin avisos y pasan su suite solas sobre `upstream/master`.

Orden recomendado para abrir los PRs, de uno en uno:
1. `fix-transfer-focus`
2. `fix-automatic-selector`
3. #1541
4. #1284
5. #1035
6. vista previa
7. zonas
8. imán
9. #1183

Cada PR que se funda obliga a rebasar los demás, pero los conflictos son triviales: se
conservan ambas inserciones en los autocompletados, `settings.h`, `messages.c`, el manual,
`tests/Makefile` y `run_headless`.

### Pendiente antes de proponer los PRs

- **Backend Wayland.** Compilarlo (`make BACKEND=wlroots`). Aquí no se pudo porque faltan
  `wlroots0.20` y `wlr-protocols`. Las comprobaciones de sintaxis no sustituyen a la
  compilación.
- **Pruebas en `tests/headless/*.sh`.**
  - Envolver en `assert_ok` o `|| true` las órdenes `bspc` de preparación y limpieza que
    quedaron sueltas.
  - Restaurar lo que deja `drag_setup` (modificador, acciones y borde).
  - Añadir `xorg-xprop` a CI, o la prueba del anuncio saldrá como SKIP.
- **Aplastar los commits.** Juntar los dos `ci:` de `edge-snap-preview-color` y de
  `magnet-edges`.
- **`tests/Makefile`.** En cada rama, que `clean` nombre solo sus binarios.
- **Documentación** (menores de la revisión final):
  - el cambio de significado de `hidden` con #1035: una ventana oculta reaparece si alguien
    pide activarla;
  - que sin compositor la vista previa sale opaca **y más oscura**;
  - que con *size hints* el imán puede quedar a menos de una celda;
  - que `edge_snap_zone_ratio` solo vale en X11.
- **Bucle principal de bspwm1.** El bucle de epoll de `src/bspwm.c` solo vacía la cola de xcb
  cuando el descriptor de X está legible. Los eventos que xcb leyó mientras esperaba otra
  respuesta se quedan atascados hasta la siguiente actividad de X.
  - **Efecto:** la prueba de minimizar y restaurar (`iconify.sh`) falla alguna vez, unas 7 de
    cada 60, y la revisión vio una vez un `MapRequest` de GTK retrasado.
  - **Pendiente:** hay además un segundo factor de foco sin aclarar. Merece su propia rama.
- **Otros menores:**
  - **Durante un arrastre:** el estado del nodo se fija al empezar; si se minimiza o se pone a
    pantalla completa a mitad, el bucle sigue.
  - **Bordes:** el imán y las zonas usan el `border_width` del cliente aunque
    `borderless_singleton`, `borderless_monocle` o la pantalla completa dibujen sin borde.
  - **Área útil:** el imán suma el padding del escritorio y las zonas no; conviene una sola
    función.
  - **Cruce de monitor:** el imán elige el monitor de destino con el centro de la caja exterior.
  - **Límites del imán:** solo tapan las hojas del escritorio, hay un tope de 64 ventanas y los
    bordes fuera del monitor cuentan como visibles.
  - **`settings.h`:** `POINTER_MOTION_INTERVAL_RESIZE` está desalineado.
  - **Banda de maximizar:** con `ratio 0.5` es inalcanzable.
  - **Validación:** `%i` y `%lf` son permisivos (aceptan octal y basura al final), igual que los
    ajustes vecinos.
  - **CANCEL de `_NET_WM_MOVERESIZE`:** deja la geometría del momento; KWin y Openbox la
    restauran.
  - **Ruido de las pruebas:** la salida trae avisos `BadWindow` benignos.
  - **Descriptores de selector:** uno de exactamente 256 caracteres se recorta a 255 sin avisar
    (a920b89).

### Actualizar el paquete

```bash
~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/build.sh --noconfirm   # compila la rama local del fork
bspc wm -r                                                        # sin cerrar la sesión
```

Las ventanas GTK ya abiertas conservan la lista de funciones que leyeron al arrancar: si cambia
`allow_net_wm_moveresize`, hay que reabrirlas.
