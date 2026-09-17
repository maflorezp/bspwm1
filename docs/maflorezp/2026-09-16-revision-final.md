> Informe de la revisión final de la rama `local` (2026-09-16), antes de los arreglos D y E. El Importante 1 ya está resuelto (ver el anexo del diseño). Los scripts de `/tmp` que menciona eran temporales y ya no existen.

# Revisión final de la rama `local` (maflorezp/bspwm1)

- **Fecha:** 2026-09-16
- **Rango:** `4cc03f1` (`upstream/master`) → `3903bc4` (`local`): 39 ficheros, +1985 −181.
- **Autoridad:** especificación `docs/superpowers/specs/2026-09-16-iman-de-bordes-bspwm1-diseno.md`, plan y registro `progress.md` (Rulings 1–22).
- **Lo ya conocido** de `final-review-context.md` no se repite salvo donde hay un efecto nuevo.

## Cómo se revisó

La revisión se hizo en tres pasadas:

1. **`src/`:**
   - `pointer.c` completo en `local`;
   - `magnet.c/h`, `edge_zone.c/h`, `color.c/h` y `snap.c`;
   - los cambios en `events.c`, `tree.c`, `messages.c`, `settings.c/h` y `backend_x11.c/h`;
   - las funciones de las que dependen: `move_client`, `resize_client`, `transfer_node`, `unlink_node`, `set_hidden`, `focus_node`, `stack`, `configure_request` y `apply_layout`.
2. **Pruebas:**
   - `tests/run_headless`, `tests/Makefile` y los nueve `tests/headless/*.sh`;
   - `test_color.c`, `test_magnet.c`, `test_edge_zone.c` y `send_moveresize.c`.
3. **Documentación y autocompletados:**
   - `doc/bspwm.1.asciidoc` y `doc/bspwm.1`, este último renderizado con `groff`;
   - `contrib/{bash,fish,zsh}_completion`;
   - `.gitignore`, `Makefile` y `release.yaml`.

**Verificación ejecutada** (todo en copias de `/tmp/bspwm-final-review`, con Xvfb en :170–:184 y `BSPWM_SOCKET` sin definir o propio; nada contra :0):

| Comprobación | Resultado |
|---|---|
| `make` de cada una de las 8 ramas por separado, y de `local` | Sin avisos |
| Suite de cada rama sola sobre `upstream/master` | Todas en verde: preview 93/93, magnet 102/102, zones 97/97, 1541 79/79, 1284 83/83, 1035 81/81, 1183 83/83, transfer 83/83 |
| Suite de `local` | ALL GREEN 155/155 |
| wlroots (sin `wlroots0.20` en la máquina) | Los objetos del núcleo y `window_ops.c` compilan con `-DBACKEND_WLROOTS` y los avisos estrictos. No aparece ningún símbolo sin resolver que no existiera ya en `4cc03f1`. `backend_wlr.c` no se toca. Es un indicio, no sustituye a compilar de verdad. |
| Fusiones de `local` | Las líneas añadidas en `local` son exactamente la unión de las ocho ramas. Las únicas diferencias son las líneas únicas combinadas de `Makefile` y de los autocompletados. No hay cambios metidos en las fusiones. |
| Commits | 5 portes con el autor original (Farley, Coyle, nwwdles, McAteer); el resto, Mauricio `<maflorezp@gmail.com>`. Sin trailers y sin `//`. `git diff --check` limpio. |
| Coste del imán | 0,028 ms por movimiento con 64 ventanas en cascada (`bench_magnet.c`) |
| Ventana GTK3 con barra propia (`csd_check.sh`) | Ver Importante 1 |

## Puntos fuertes

- **La integración de `pointer.c` es sólida.**
  - `drag_node` concentra el inicio del arrastre, y el imán, la vista previa, las zonas y `_NET_WM_MOVERESIZE` pasan todos por el mismo `track_pointer`. No hay una segunda copia del bucle.
  - El imán calcula en cada movimiento el destino absoluto (`want − cur`). Por eso se corrige solo cuando `move_client` o `resize_client` recortan, redondean o transfieren de monitor, y el rectángulo libre nunca se desincroniza de forma permanente.
- **El estado compartido está bien acotado.**
  - `magnet_stack` se pide después del `stack()` de `drag_node`, en el mismo búfer de salida, así que ya refleja la ventana elevada. Se libera en el único camino de salida del bucle, y no hay `return` entre la reserva y el `free`.
  - `snap_preview_cmap` solo existe junto a `snap_preview_win` y se libera en `destroy_snap_preview`, que se llama siempre al terminar el arrastre.
  - `magnet_stack` solo guarda identificadores de ventana, no punteros a nodos: una ventana destruida a mitad de arrastre no deja nada colgando.
- **No hay reentrada.**
  - `pointer_move_node` sale si `grabbing` está activo.
  - El grab activo no selecciona `ButtonPress`, así que `button_press` no puede volver a entrar en `grab_pointer` durante un arrastre.
  - Las guardas de la Ruling 17 cierran el cuelgue de #1183, salvo la carrera del Menor 1.
- **`fix-transfer-focus` es correcto y mínimo.**
  - `unlink_node` solo libera el padre de `ns`, y ese caso ya lo anula `focus_was_child`, así que `is_descendant(last_ds_focus, ns)` nunca recorre memoria liberada.
  - Arregla justo el camino que usa el imán al cruzar de monitor (`move_client` → `transfer_node(..., true)`).
- **Los módulos puros están bien diseñados.**
  - `magnet.c` y `edge_zone.c` no dependen de X y tienen pruebas unitarias con los límites exactos: umbral inclusivo, tramos con `ratio` 0,2, alto impar y monitor desplazado.
  - La recursión de `offer_line` está acotada: profundidad ≤ 63 y coste real despreciable.
  - `edge_zone_rect` quita duplicación de `snap.c` y de `pointer.c`, y de paso corrige las zonas clásicas.
- **Las desviaciones del plan están justificadas y registradas:**
  - NaN rechazado (Ruling 14);
  - round-trip en `send_moveresize` (Ruling 16);
  - guardas de #1183 (Ruling 17);
  - pruebas con mutación (Ruling 18);
  - arreglos A y B en su rama (Ruling 19);
  - rama propia para el foco (Ruling 21).
- **Las pruebas miden comportamiento real.**
  - La geometría se lee de X con el botón pulsado, y las zonas se comparan con una referencia de `bspc node -S`.
  - La vista previa se comprueba por píxel (`007f007f`).
  - La prueba de mosaico está verificada por mutación, y las pruebas nuevas tuvieron fase roja documentada.
- **La documentación es coherente.** Los seis ajustes nuevos están en `set_setting`, `get_setting`, `settings.c/h`, el asciidoc, el roff y los tres autocompletados. `groff` no da avisos nuevos, y el texto de `pointer_motion_interval_resize` coincide con la descripción original del PR #1284.
- **Cada rama se sostiene sola:** compila sin avisos y pasa su suite sobre `upstream/master`.

## Problemas

### Críticos

Ninguno. No se encontró ningún crash, cuelgue ni fuga alcanzable nuevo; la carrera del Menor 1 es la más cercana.

### Importantes

#### 1. Anunciar `_NET_WM_MOVERESIZE` rompe el redimensionado de las ventanas GTK con barra propia, y `allow_net_wm_moveresize false` no permite volver atrás

- **Dónde:**
  - `src/backend_x11.c:931` añade `ewmh->_NET_WM_MOVERESIZE` a `_NET_SUPPORTED` siempre;
  - `src/events.c:329-333` solo atiende la dirección `MOVE` (8), y solo si `allow_net_wm_moveresize` está activo.
  - Rama: `upstream-1183-net-wm-moveresize`. También está en `local`, que es lo que tiene instalado Mauricio.
- **Qué falla:**
  - GTK3 y GTK4 miran `_NET_SUPPORTED`. Sin el átomo, emulan ellas mismas el movimiento y el redimensionado con `ConfigureRequest`, que bspwm1 respeta en las flotantes (`configure_request`). Con el átomo, se lo piden al gestor.
  - Qt (`startSystemMove/Resize`) hace la misma comprobación. No lo he medido.
  - bspwm1 ahora anuncia el átomo pero ignora las direcciones de redimensionado (0–7), así que esas peticiones se pierden.
- **Evidencia medida** con `/tmp/bspwm-final-review/csd_check.sh` (ventana `Gtk.HeaderBar` flotante; `begin_move_drag` / `begin_resize_drag` más arrastre de +120,+80 con `xdotool`):

  | bspwm | mover | redimensionar esquina |
  |---|---|---|
  | `4cc03f1` (base) | se mueve (emulado por GTK) | 400x300 → 520x380 (emulado) |
  | `local`, `allow_net_wm_moveresize true` | se mueve (bspwm) | **no cambia (400x300)** |
  | `local`, `allow_net_wm_moveresize false` | **no se mueve** | **no cambia** |

- **Por qué importa:**
  - Es una regresión que se alcanza a diario. Los diálogos GTK (selector de ficheros, entre otros) son flotantes en bspwm y usan barra propia. Con picom, sus bordes de redimensionado son la zona de sombra, y arrastrarlos ya no hace nada.
  - El ajuste que el manual presenta como forma de desactivar la función (`doc/bspwm.1.asciidoc:869`) deja las cosas peor que antes: esas ventanas tampoco se pueden mover.
  - Viene del diseño («Del #1183 solo se porta el caso de mover») y del PR original, que también anunciaba el átomo. La especificación no preveía que anunciar el átomo desactiva la emulación de los toolkits.
  - Un revisor de rotkonetworks que use GNOME o GTK lo notará enseguida.
- **Cómo arreglarlo, en la rama `upstream-1183-net-wm-moveresize`:**
  1. **Atender las direcciones de redimensionado.** Ahora que existe `drag_node`, cuesta poco:
     - pasar a `drag_node`/`track_pointer` un `resize_handle_t` fijo en lugar de calcularlo con `get_handle`;
     - traducir 0–7 a `HANDLE_TOP_LEFT`, `HANDLE_TOP`, … y 8 a mover;
     - atender `_NET_WM_MOVERESIZE_CANCEL` (11) terminando el arrastre;
     - ignorar las direcciones de teclado (9 y 10).
     
     Así el imán también actuaría en esos redimensionados.
  2. **Que `allow_net_wm_moveresize false` sea una vuelta atrás real:** anunciar el átomo solo mientras el ajuste está activo. Cuando cambie en `set_setting`, se vuelve a llamar a `x11_setup_ewmh_supported()` o a una variante que quite el átomo.
  3. **Pruebas:**
     - `send_moveresize W … 4 1` debe redimensionar, sustituyendo la prueba actual «a client-initiated resize is ignored»;
     - con el ajuste en `false`, `xprop -root _NET_SUPPORTED` no debe contener el átomo.
  4. **Documentación:** quitar «Only moving is handled» del manual (`doc/bspwm.1.asciidoc:869-870`) y del mensaje de commit si cambia el alcance.
  
  **Mientras tanto:** con el modificador y el botón 2 o 3, bspwm sigue redimensionando esas ventanas. No hay que proponer `allow_net_wm_moveresize false` como escape.

### Menores

1. **`pointer_move_node` puede dejar el puntero agarrado hasta el siguiente clic, y acepta nodos ocultos** (`src/pointer.c:322-343` y `237-247`).
   - **Qué falla:** si el botón se suelta entre `xcb_query_pointer` y `xcb_grab_pointer`, el grab sale bien pero no llega ningún `ButtonRelease`. bspwm se queda en `track_pointer`, sin atender a `bspc` ni a sxhkd, hasta el siguiente clic, que entonces se pierde. La ventana dura milisegundos; la Ruling 17 solo cerró el caso en que el botón ya estaba suelto al llegar la petición. Además, un nodo `hidden` en el escritorio visible pasa la guarda (el comentario de la línea 324 dice «not shown»).
   - **Arreglo:**
     - en el camino de `pointer_move_node`, repetir `xcb_query_pointer` después de conseguir el grab y soltarlo si ya no hay ningún botón pulsado;
     - añadir `loc.node->hidden` a la guarda.
2. **El estado del nodo se decide una sola vez por arrastre** (`src/pointer.c:508`, `src/events.c:336-341`).
   - **Qué falla:** si durante el arrastre el cliente pide minimizarse (`WM_CHANGE_STATE`, nuevo con #1035) o ponerse a pantalla completa (`_NET_WM_STATE`), `handle_event` lo aplica y el bucle sigue moviendo una ventana oculta o a pantalla completa. Con el imán, en pantalla completa `magnet_box_of` devuelve el rectángulo del monitor y `move_client` recibe un salto grande. No es un crash, y el caso de pantalla completa ya existía antes sin imán.
   - **Arreglo:** en cada `MOTION_NOTIFY`, salir del bucle (o no mover) si `n->hidden` o si `n->client->state` ya no es el del inicio, y recalcular `magnet_on` con `IS_FLOATING`.
3. **#1035 cambia el significado de `hidden` en la sesión de Mauricio, y el manual no lo cuenta** (`src/events.c:318-319` y `336-341`).
   - **Qué cambia:**
     - un `_NET_ACTIVE_WINDOW` sobre una ventana oculta ahora la muestra (antes no hacía nada, porque `is_focusable` la descartaba);
     - una aplicación que llama a `XIconifyWindow` (por ejemplo, el `minimize()` de Electron) ahora se oculta.
   - **Por qué importa:** Mauricio usa `hidden` como scratchpad (`open_hide.sh`, `open_chrome_app.sh`, `unhide.sh`). Una aplicación oculta que pida activación reaparecerá. Con `ignore_ewmh_focus true` solo se bloquean las peticiones con origen «aplicación», no las de un paginador.
   - **Arreglo:** documentarlo en el manual (bandera `hidden` o `ignore_ewmh_focus`), avisar a Mauricio y contarlo en la descripción del PR.
4. **Documentación que la especificación pide y falta** (`doc/bspwm.1.asciidoc:830-838`):
   - que, con size hints, el imán puede quedar a menos de una celda del objetivo (especificación §2, «se documenta»);
   - que sin compositor la vista previa sale opaca **y más oscura**, por el color premultiplicado (§1). El manual solo dice «opaque».
   - Además, `edge_snap_zone_ratio` no dice «X11 only», aunque solo lo usa el arrastre (`get_snap_zone` no existe en `backend_wlr.c`).
5. **`tests/Makefile:27-28`:** en las cuatro ramas, `clean:` borra `test_color`, `test_magnet`, `send_moveresize` y `test_edge_zone`, aunque cada rama solo construye uno. Ayuda a fundir sin conflictos, pero en un PR aislado nombra binarios de otros PRs. Conviene que cada rama nombre solo el suyo y resolver el conflicto al rebasar.
6. **Huecos de cobertura frente a la especificación:**
   - no hay ninguna prueba con padding de monitor o escritorio (`magnet_area_of`, `src/pointer.c:361-373`; especificación §2: «el área útil descuenta el padding»);
   - no hay ninguna con `border_width` distinto por ventana;
   - `edge_snap_preview.sh:33-50` hace un solo arrastre, así que no demuestra que el siguiente arrastre use un color nuevo (especificación §1);
   - nada comprueba que la vía `_NET_WM_MOVERESIZE` emita `pointer_action … move begin/end` igual que el atajo (especificación §7).
7. **Aislamiento de las pruebas** (`tests/headless/drag.sh:34-40`): `drag_setup` deja `pointer_modifier mod1`, las tres acciones y `border_width 2` para todas las pruebas siguientes y nadie los restaura. Hoy no afecta a nada, pero el resultado depende del orden. Hay que restaurarlos al final de cada bloque, o en un `drag_teardown`.
8. **`src/pointer.c:691-696`, `715-725`:**
   - el borde de 2 px de la vista previa aparece como literal en tres sitios; conviene una constante `SNAP_PREVIEW_BORDER`;
   - `if (preview.width == 0)` es código muerto, porque `SNAP_NONE` ya sale en la línea 671.
9. **Padding incoherente entre el imán y las zonas:**
   - `magnet_area_of` (`src/pointer.c:361-373`) suma el padding del escritorio;
   - `apply_snap_zone` (`src/snap.c`) y `show_snap_preview` (`src/pointer.c:683-689`) solo usan el del monitor, algo que ya estaba antes.
   
   Con padding por escritorio, el imán y las zonas no coinciden. A Mauricio no le afecta, porque su padding es por monitor. Conviene sacar una sola función de área útil y usarla en los tres sitios.
10. **Validación permisiva** (`src/messages.c:1975`, `1982`, `1989`):
    - `%i` acepta octal y hexadecimal: `bspc config magnet_threshold 010` deja 8;
    - `%lf` acepta basura al final: `0.2x` se da por bueno.
    
    Es el mismo patrón que `edge_snap_threshold` y `split_ratio`, así que solo cambiaría por coherencia con un arreglo general (`strtol`/`strtod` con comprobación del final).

## Estado de cada rama como PR independiente

Todas compilan sin avisos y pasan su suite sobre `upstream/master` (medido hoy, en copias aisladas). Ninguna necesita otra rama.

| Rama | Commits | Suite sola | ¿Lista? | Pendiente |
|---|---|---|---|---|
| `edge-snap-preview-color` | 9 | 93/93 | Con pulido | Ruling 11; aplastar los dos `ci:`; Menores 4, 5 y 8 |
| `magnet-edges` | 15 | 102/102 | Con pulido | Ruling 11; aplastar los dos `ci:`; Menores 2, 4, 5, 6 y 7. En la descripción del PR: límites del imán (64 ventanas, apilado leído una vez por arrastre) |
| `edge-snap-zones` | 11 | 97/97 | Con pulido | Ruling 11; Menor 5. En la descripción del PR: `bspc node -S` y las zonas clásicas cambian de geometría, porque ahora descuentan 2·borde y la mitad impar va a la segunda. Es un cambio visible para quien ya las usa. |
| `upstream-1541-no-raise-on-focus` | 2 | 79/79 | Sí | Ruling 11 (`no_raise_on_focus.sh`) |
| `upstream-1284-resize-motion-interval` | 2 | 83/83 | Sí | Desalineación ya conocida en `settings.h` |
| `upstream-1035-iconify` | 2 | 81/81 | Con pulido | Prueba intermitente ya conocida; Menor 3 (documentar el cambio de `hidden`) |
| `upstream-1183-net-wm-moveresize` | 6 | 83/83 | **No** | **Importante 1**; Menor 1; Ruling 11 |
| `fix-transfer-focus` | 2 | 83/83 | Sí | Nada que bloquee; órdenes ya protegidas con `\|\| true` |

**Conflictos previsibles al abrirlos en serie.** No son defectos, pero hay que planificarlos. Cinco ramas tocan la misma línea única de la lista de ajustes en `contrib/bash_completion` y `contrib/fish_completion`, y la línea `input=`/`look=` de zsh. Además chocan:

- las líneas `all:` adyacentes de `tests/Makefile`;
- las líneas `. ./headless/*.sh` adyacentes de `run_headless`;
- las inserciones contiguas en `settings.h`, `messages.c` y el asciidoc;
- `src/pointer.c` entre `magnet-edges` y `upstream-1183` (inicio del arrastre y `track_pointer`).

Cada PR que se funda obliga a rebasar los demás; las resoluciones son triviales («conservar ambas»). `release.yaml` y `drag.sh` son idénticos entre ramas y se funden solos.

## Recomendaciones

1. **Corregir el Importante 1** en `upstream-1183-net-wm-moveresize` antes del PR, y también en `local`: el paquete instalado ya tiene la regresión. Después, volver a fundir en `local`, pasar la suite y `csd_check.sh`, y reinstalar. Hasta entonces, avisar a Mauricio de que las ventanas GTK con barra propia se redimensionan con el modificador y el botón, no por el borde.
2. **Pulido antes de los PRs**, en este orden:
   - Ruling 11 (`assert_ok` o `|| true` en las órdenes que modifican estado en los `tests/headless/*.sh`);
   - los Menores 1, 2 y 7, que son baratos;
   - los Menores 3 y 4 (documentación);
   - aplastar los `ci:` duplicados de las tareas 4 y 7.
3. **Compilar wlroots** en un contenedor Arch con `wlroots0.20` y `wlr-protocols` (criterio de aceptación 6). La comprobación de símbolos de esta revisión no la sustituye.
4. **Abrir los PRs de uno en uno**, empezando por los pequeños e independientes: `fix-transfer-focus`, #1541, #1284, #1035, vista previa, zonas, imán y #1183. Cada descripción debe avisar de los conflictos triviales de autocompletados y ajustes, y contar lo que iría en el CHANGELOG.
5. **Quedan pendientes** la tarea 20 (mudar la especificación y el plan a `docs/maflorezp/` en `local`, criterio 11) y el anexo con los arreglos A, B y C y las Rulings. También recordar a Mauricio el `pushurl` por SSH de la Ruling 12.
6. **Reproducción** de lo medido en esta revisión: `/tmp/bspwm-final-review/` (`run_branch.sh`, `csd_check.sh`, `csd_drag.py`, `bench_magnet.c`).
   - Los procesos `Xvfb :210` y `../bspwm -c /dev/null` que siguen vivos no son de esta revisión, así que no los toqué.
   - Tampoco toqué los sockets `bspwm_15[0-3]_0-socket` antiguos de `$XDG_RUNTIME_DIR`.

## Valoración

**¿Lista para PRs? Con correcciones.**

- No hay nada crítico: no encontré crashes, cuelgues ni fugas nuevas. El estado compartido (`magnet_stack`, `snap_preview_win`/`snap_preview_cmap`, `grabbing`) está bien acotado y la integración de las ocho ramas en `pointer.c` es limpia.
- Siete de las ocho ramas se sostienen solas y solo necesitan el pulido ya previsto (Ruling 11 y menores).
- La excepción es `upstream-1183-net-wm-moveresize`: al anunciar `_NET_WM_MOVERESIZE` sin atender el redimensionado, rompe algo que antes funcionaba (redimensionar por el borde las ventanas GTK flotantes con barra propia). Su interruptor, `allow_net_wm_moveresize false`, deja esas ventanas sin poder moverse siquiera.
- Esa regresión está medida, se alcanza en el uso diario de Mauricio y cualquier revisor de upstream la vería. Hay que corregirla antes de proponer esa rama, y conviene hacerlo ya en `local`.
