> Investigación del 2026-09-17: por qué un diálogo abierto desde una ventana en monocle ocupa toda la pantalla. Escrita antes de la rama `rule-match`.

# El diálogo que ocupa toda la pantalla en un escritorio monocle

Depuración del 2026-09-17. Todo lo que sigue se ejecutó en un Xvfb propio (`:220`), con
`BSPWM_SOCKET` sin definir. La sesión de Mauricio (`:0`) solo se consultó en lectura
(`bspc query`, `bspc rule -l`, `bspc config`, `xprop`, y el log `/tmp/bspwm.log`).

## Resumen

El diálogo no «se pone de toda la pantalla»: **nace *tiled***, y en un escritorio monocle con
`gapless_monocle true` una ventana tiled *es* toda la pantalla. La causa no está ni en sus 95
reglas ni en su script externo: ambos se comprobaron y **ninguno deshace el `state=floating`** que
bspwm pone a un diálogo de verdad. La causa es que las ventanas que él llama «hijas» **no son
diálogos a ojos de X**: al mapearse no declaran `_NET_WM_WINDOW_TYPE_DIALOG` (como primer tipo
reconocido) ni `WM_TRANSIENT_FOR`, así que bspwm no tiene por dónde saber que son secundarias y
las coloca en el mosaico. Reproducido con una aplicación real: un *pop-up* de Chrome.

Además se ha encontrado, y demostrado, **un fallo real de bspwm1** que agrava el caso: solo se
aplica el **primer** átomo reconocido de `_NET_WM_WINDOW_TYPE`, mientras que bspwm aplica todos.
Una ventana que declara `[UTILITY, DIALOG]` flota en bspwm 0.9.12 y queda *tiled* en bspwm1.

---

## 1. Por qué «tiled» equivale a «toda la pantalla»

`bspwm_config.sh` fija `gapless_monocle true` y `borderless_monocle false`. En monocle, cada nodo
tiled recibe el rectángulo completo del escritorio sin hueco (`src/tree.c:73-85`, `apply_layout`
en `src/tree.c:90+`), y todos los tiled se solapan.

Medido en el Xvfb de 1920x1080 con su configuración: un nodo tiled en monocle sale
`geom=1916x1076+0+0` (1916 + 2·2 de borde = 1920). Un flotante sale `400x200+758+438`.

Casi todos sus escritorios son monocle (comprobado en `:0`): `terminal, internet, work, code,
data, communication, file, utils` → `layout=monocle`; solo los `development1..5` son `tiled`.

## 2. Quién decide el estado de un diálogo en su configuración

Orden real (`src/rule.c:396-422` y `424-456`):

1. `_apply_window_type` (`src/rule.c:283-308`) → `DIALOG` ⇒ `state=floating`, `center=on`.
2. `_apply_window_state` → `_NET_WM_STATE`.
3. `_apply_transient` (`src/rule.c:336-342`) → `WM_TRANSIENT_FOR` ⇒ `state=floating`.
4. `_apply_hints` (`src/rule.c:344-353`) → tamaño fijo (min == max) ⇒ `state=floating`.
5. Sus **95 reglas**, en orden de alta, acumulándose.
6. `external_rules_command` (`schedule_rules`, `src/rule.c:424-456`), que puede sobrescribir
   cualquier clave.

**Sus reglas no tocan el estado de los diálogos.** Ninguna de las 95 fija `state=tiled`. Las nueve
que dicen `state=monocle` (DBeaver, dbgate, jetbrains-datagrip/phpstorm/idea/webstorm, rambox,
ferdium, Teams, Slack, SoapUI) **no hacen nada**: `monocle` no es un estado de cliente válido
—la tabla es `floating|fullscreen|pseudo_tiled|tiled`, `src/parse.c:50-55`— y `parse_key_value`
descarta en silencio el valor que no parsea (`src/rule.c:494-499`). No estorban, pero tampoco
hacen lo que él cree.

**Su script externo tampoco.** `bspwm_external_rules.sh` solo puede *añadir* `state=floating`
(líneas 85-99 y 104-112) y `node=`/`follow=` (líneas 61-71). Comprobado en el Xvfb:

- Ejecutado a mano sobre un diálogo, imprime `state=floating` (rama `*)` + `xprop`, líneas 93-99).
- Con un receptáculo presente imprime además `node=0x…` y `follow=off`. **`node=` no deshace el
  flotante**: se abrió un diálogo con un receptáculo en el escritorio y siguió
  `state=floating geom=400x200`. En `manage_window` (`src/window.c:166-173`) `node=` solo elige el
  punto de inserción; el estado se aplica después en `set_state` (`src/window.c:306-308`).
- Un diálogo de verdad (tipo `DIALOG` + `WM_TRANSIENT_FOR` al mapear) sale **flotante y centrado
  con su configuración completa**, para las clases `TestApp`, `Google-chrome` y `dbgate`.

## 3. Reproducción

Herramientas escritas para esto (todas en `/tmp/bspwm-dbg/`): `mkwin.c`, un cliente X mínimo que
crea una ventana con las propiedades exactas que se le pidan; `app.py`/`app2.py` (GTK3);
`dump.py`, que vuelca estado y geometría de cada nodo; `case4.sh`, que levanta bspwm con una
configuración dada, abre padre e hija y vuelca el resultado.

Configuración de prueba (`rc-full.sh`): sus mismos `bspwm_config.sh` y `bspwm_rules.sh`
(95 reglas + `external_rules_command` apuntando a su script), todos los escritorios en monocle.

Binarios comparados:

- `local` = `/usr/bin/bspwm` (el instalado, `v1.6.2-67-g6452afd`).
- `upstream/master` = `4cc03f1`, compilado en `/tmp/bspwm-upstream`.
- bspwm original de baskerville (`0.9.12`), compilado en `/tmp/bspwm-baskerville`, como tercera
  referencia.

| Caso (ventana hija, escritorio en monocle) | local | upstream 4cc03f1 | bspwm 0.9.12 |
|---|---|---|---|
| tipo `DIALOG` + `WM_TRANSIENT_FOR` | flotante 400x200 | flotante | flotante |
| solo `WM_TRANSIENT_FOR` (tipo `NORMAL`) | flotante | — | — |
| `Gtk.Dialog` de GTK3 | flotante | — | — |
| `JDialog` de Swing con `_JAVA_AWT_WM_NONREPARENTING=1` | flotante | — | — |
| **sin tipo `DIALOG` y sin transient** | **tiled 1916x1076** | **tiled** | tiled |
| tipo+transient puestos 200 ms **después** de mapear | **tiled 1916x1076** | **tiled** | — |
| lista `[UTILITY, DIALOG]` sin transient, clase `TestApp` | flotante (lo rescata su script) | flotante | flotante |
| lista `[UTILITY, DIALOG]` sin transient, clase `Google-chrome` | **tiled 1916x1076** | **tiled** | **flotante** |

### La reproducción con una aplicación real

Chrome de verdad, con perfil temporal, en el Xvfb, con su configuración y el escritorio
`internet` en monocle. La página abre `window.open(..., 'popup=yes,width=500,height=350')`:

```
desktop internet layout=monocle
  Google-chrome:google-chrome  state=tiled  geom=1916x1076+0+0  "pagina padre - Google Chrome"
  Google-chrome:google-chrome  state=tiled  geom=1916x1076+0+0  "about:blank - Google Chrome"
```

Propiedades de las dos ventanas:

```
padre:   WM_WINDOW_ROLE = "browser"   _NET_WM_WINDOW_TYPE = _NET_WM_WINDOW_TYPE_NORMAL   WM_TRANSIENT_FOR: not found
pop-up:  WM_WINDOW_ROLE = "pop-up"    _NET_WM_WINDOW_TYPE = _NET_WM_WINDOW_TYPE_NORMAL   WM_TRANSIENT_FOR: not found
```

El *pop-up* pidió 500x350 y acabó ocupando la pantalla entera. **Para bspwm es indistinguible de
una ventana normal de Chrome**: misma clase, misma instancia, mismo tipo, sin transient. Lo único
que las separa es `WM_WINDOW_ROLE`, que bspwm no lee en ningún sitio.

## 4. La causa, con fichero y línea

**Causa principal (no es un fallo de bspwm):** una ventana hija que al mapearse no declara
`_NET_WM_WINDOW_TYPE_DIALOG` ni `WM_TRANSIENT_FOR` no pasa por ninguna de las tres puertas de
`apply_rules` que ponen `STATE_FLOATING` —`src/rule.c:283-308`, `336-342` y `344-353`—, nace
tiled, y `gapless_monocle` (`src/tree.c:80-85`) la estira a todo el monitor. Es el
comportamiento de bspwm de toda la vida; lo que lo vuelve visible es que casi todos sus
escritorios son monocle.

**Fallo real de bspwm1 que lo agrava:** `backend_get_window_type` (`src/backend_x11.c:438-458`)
recorre `_NET_WM_WINDOW_TYPE` y se queda con **el primer** átomo reconocido:

```c
	bool found = false;
	for (unsigned int i = 0; i < reply.atoms_len && !found; i++) {
		...
		else if (a == ewmh->_NET_WM_WINDOW_TYPE_DIALOG) { *type = BSP_WINDOW_TYPE_DIALOG; found = true; }
		else if (a == ewmh->_NET_WM_WINDOW_TYPE_UTILITY) { *type = BSP_WINDOW_TYPE_UTILITY; found = true; }
```

bspwm original recorre **todos** los átomos y aplica el efecto de cada uno, así que `DIALOG`
flota la ventana esté donde esté en la lista (`_apply_window_type` en `src/rule.c` de
`baskerville/master`). Demostrado arriba: `[UTILITY, DIALOG]` sin transient ⇒ flotante en 0.9.12,
tiled en bspwm1.

**Agravante de su configuración:** `bspwm_external_rules.sh:52-59` corta el script antes de la
comprobación de `DIALOG` (líneas 93-99) para las clases de `ruled_classes`:

```bash
ruled_classes="Google-chrome|firefox|DBeaver|dbgate|jetbrains-datagrip|jetbrains-phpstorm|…"
if [[ "$window_class" =~ ^($ruled_classes)$ ]]; then exit 0; fi
```

Son justo las aplicaciones que viven en sus escritorios monocle. Por eso el mismo caso
`[UTILITY, DIALOG]` sale flotante con clase `TestApp` (el script lo rescata) y tiled con clase
`Google-chrome` (el script se ha ido antes). Nota: la lista compara mayúsculas tal cual, así que
`Rambox`, `Ferdium`, `Microsoft Teams` y `Double-commander` **no** excluyen a nada —las clases
reales son `rambox`, `ferdium`, `teams-for-linux`/`Microsoft Teams - Preview`, `Doublecmd`—; la
exclusión solo es efectiva para `Google-chrome`, `firefox`, `DBeaver`, `dbgate`, los cuatro
`jetbrains-*`, `Slack`, `doublecmd` y `KeePassXC`.

## 5. ¿Es una regresión de nuestras ramas?

**No.** Las dos cosas se comportan igual en `local` (6452afd) y en `upstream/master` (4cc03f1),
medido con los dos binarios en la misma configuración (tabla de arriba).

`git diff --stat upstream/master local -- src/` confirma que sus ramas **no tocan** `src/rule.c`
ni `src/window.c` ni `src/backend_x11.c` en la parte del tipo de ventana: los cambios propios son
`magnet*`, `edge_zone*`, `color*`, `pointer.c`, `snap.c`, `settings*`, `messages.c`, `events.c`,
y dos arreglos en `query.c` (selector `automatic`) y `tree.c`. El fallo del primer átomo viene de
rotkonetworks; el resto viene de bspwm de siempre.

De paso, se descartó que el arreglo del selector `automatic` (`4170d88`) tenga que ver: con él,
`newest.!automatic` solo devuelve nodos preseleccionados, así que el script externo casi nunca
imprime `node=`; y cuando lo imprime (probado con un receptáculo), el diálogo sigue flotando.

## 6. Arreglo propuesto

**Lo que de verdad le quita el problema (dotfiles, `~/.dotFiles/.config/bspwm/`):** una regla que
distinga la ventana secundaria por `WM_WINDOW_ROLE`, que hoy bspwm no sabe leer. Es exactamente lo
que ya tiene diseñado en `docs/maflorezp/2026-09-17-reglas-por-propiedades-diseno.md` (rama
`rule-match`):

```bash
bspc rule -a class=Google-chrome role=pop-up state=floating center=on
bspc rule -a type=dialog state=floating center=on
```

Hasta que eso exista, el parche de andar por casa es en su script externo: mover la comprobación
de `_NET_WM_WINDOW_TYPE`/`WM_TRANSIENT_FOR`/`WM_WINDOW_ROLE` **antes** del `exit 0` de
`ruled_classes` (`bspwm_external_rules.sh:52-59`), de modo que el rescate valga también para
Chrome y los JetBrains. Va en la rama `local` de los dotfiles, no en bspwm.

**Lo que es un fallo y debería corregirse en bspwm1:** que `backend_get_window_type` deje de
quedarse con el primer átomo. Como la firma devuelve un tipo único, lo limpio es devolver el
conjunto de tipos (o un `bool` por tipo relevante) y que `_apply_window_type` aplique todos los
efectos, como bspwm. Rama nueva a partir de `master`, al estilo de sus otros arreglos
—`fix-window-type-list`—, con su prueba, y luego *merge* a `local`; es un candidato claro a PR
hacia `rotkonetworks/bspwm1`, porque es una divergencia de comportamiento respecto a bspwm.

**Aparte, dos limpiezas de configuración** que salieron por el camino y no cuestan nada:

- Las nueve reglas `state=monocle` no hacen nada (`src/parse.c:50-55`). Si lo que quiere es que
  esas aplicaciones caigan en un escritorio monocle, eso ya lo da el escritorio; la clave sobra.
- `bspc rule -a pavucontrol …` nunca coincide: la clase real es `Pavucontrol` (ya está anotado en
  su documento de diseño).

## 7. Lo que no he podido aclarar

- **Qué aplicación concreta le pasa a él.** El mecanismo está demostrado y reproducido con Chrome,
  pero no puedo afirmar que sea Chrome lo que él vio. `/tmp/bspwm.log` guarda solo ids: hay 47
  `node_add` de 201 que se quedaron tiled, y los que son ventanas secundarias de un cliente que ya
  tenía ventanas (Chrome `0x0220…`, PhpStorm `0x0380…`) ya no existen, así que no se les puede
  preguntar la clase ni el rol. Las dos ventanas de Chrome vivas ahora mismo son `role=browser`,
  es decir, ventanas normales bien colocadas.
- **Si el caso `[UTILITY, DIALOG]` le ocurre de verdad.** Es un fallo real de bspwm1, demostrado
  en el banco de pruebas, pero no he encontrado ninguna ventana suya que declare una lista de
  tipos con `UTILITY` o `TOOLBAR` por delante de `DIALOG`. Puede ser un fallo latente y no el suyo.
- **El caso «propiedades puestas después de mapear»** también produce el síntoma y explicaría el
  «muchas veces» (es una carrera), pero no he podido comprobar si alguna de sus aplicaciones lo
  hace.

**Lo que me falta para cerrarlo:** la próxima vez que le pase, con la ventana todavía abierta:

```bash
W=$(bspc query -N -n focused)
xprop -id $W WM_CLASS WM_WINDOW_ROLE _NET_WM_WINDOW_TYPE WM_TRANSIENT_FOR WM_NAME
bspc query -T -n $W | head -20
```

Con eso se sabe en un segundo por cuál de los tres caminos se escapó. Si prefiere no estar
pendiente, un *subscriber* de `node_add` que registre `class`, `instance`, `role`, tipo y
transient de cada ventana nueva deja el dato recogido para cuando vuelva a pasar.
