# Revisión final — rama `rule-match` (4cc03f1..e76b9d8)

Repo: `/websites/personal/bspwm` · 18 commits, 20 ficheros, +1308/−81 · fundida en `local` (36f8786).
Revisor: agente de revisión final. Fecha: 2026-09-17.

## Qué se verificó y cómo

No es una lectura del diff a secas. Todo lo que se afirma abajo está comprobado:

- **Compilación** con los CFLAGS estrictos del repo (`-std=c23 -pedantic -Wall -Wextra -Wvla
  -Wformat=2 -Wformat-overflow=2 -Wformat-truncation=2 -Wnull-dereference -O2
  -D_FORTIFY_SOURCE=3`), sobre una copia en `/tmp`: **cero avisos**.
- **Suite completa**: `flock /tmp/bspwm1-make-test.lock make test` → **ALL GREEN: 220/220 (x11)**.
- **ASan + UBSan + LSan** sobre `tests/test_rule_match.c` y sobre una sonda propia
  (`/tmp/rm_probe.c`) que recorre los caminos que la prueba unitaria no toca (regex inválida y
  luego `rule_cond_free`, normalización de `transient=true`, `/i` en `type`, `*` con cada
  combinación de marcas, el borde exacto de 255/256 caracteres, patrón vacío,
  `rule_cond_print` truncando, `rule_prop_name` fuera de rango): **sin errores y sin fugas**.
- **bspwm headless** en `:87`, `:88`, `:89` y `:90`, siempre con `-c /dev/null`, `BSPWM_SOCKET`
  propio y cerrados al terminar (comprobado: no quedaron ni procesos ni sockets, y la sesión real
  de `:0` no se tocó). Con eso se probaron ~35 casos de sintaxis y compatibilidad.
- **Criterio 7 de verdad**: se recuperó el `bspwm_rules.sh` **anterior a la migración**
  (`cbe5414^`) y se ejecutó entero contra el bspwm nuevo: **las 95 reglas se dan de alta, cero
  errores**. Después el fichero migrado: **29 reglas, cero errores**.
- **Criterio 11**: `git merge-base e76b9d8 upstream/master` = `4cc03f1` = HEAD de
  `upstream/master` (rotkonetworks/bspwm1), 0 commits intermedios. La rama sale limpia de
  upstream.

## Veredicto

**Apta, con correcciones antes del PR a upstream.** No hay ningún fallo de corrección de
memoria: ni fuga de `regex_t`, ni escritura fuera de límites, ni estructura a medias en una ruta
de error. Los 11 criterios de aceptación se cumplen, dos con matices que se detallan al final.
Lo que queda son 6 asuntos importantes —cuatro de compatibilidad/usabilidad de la interfaz, uno
de coste por ventana y uno de mantenimiento— y una lista de menores.

**Resumen: 0 Críticos · 6 Importantes · 15 Menores.**

---

## Fortalezas

- **El módulo está bien cortado.** `src/rule_match.{c,h}` es puro: sin X, sin estado global, sin
  incluir nada de bspwm. La decisión de que **las marcas las ponga quien llama**
  (`rule_match.h:73-79`) y que el módulo nunca mire el valor para adivinar si es regex es la
  correcta: el parseo del operador vive en un solo sitio (`messages.c`) y el módulo se puede
  probar entero desde una prueba unitaria sin X. La forma antigua compila con `flags = 0` y por
  eso `~` y `/i` vuelven a ser caracteres normales, que es exactamente lo que sostiene la
  compatibilidad.
- **Las rutas de error están limpias.** Todos los caminos de fallo de `cmd_rule` pasan por
  `remove_rule()` (`messages.c:1340, 1391, 1542`), que libera las seis condiciones
  (`rule.c:85-87`). `rule_cond_compile()` hace `memset` antes de nada y no marca `used` hasta el
  final, así que una condición que falló no deja nada que liberar y `rule_cond_free()` sobre ella
  es un no-op comprobado. El único `free(rule)` suelto (`messages.c:1301`) está antes de compilar
  nada.
- **El arreglo del `/i` antes de medir (commit 16198ea) es el correcto** y está probado justo en
  el borde, con 254 y con 255 (`tests/headless/rule_match.sh:56-63`). Sin él, un patrón legítimo
  de 255 caracteres se habría rechazado por dos caracteres que nunca fueron parte del patrón.
- **Los `#pragma GCC diagnostic ignored "-Wformat-truncation"` están justificados.** Se comprobó
  recompilando `rule_match.c` sin ellos: GCC avisa de verdad, y avisa por lo que dice el
  comentario (`rule_match.c:75-81`) — al ver el `len == 0` deduce «región de tamaño entre 0 y 1»
  y marca cualquier mensaje más largo. No es una supresión de conveniencia.
- **Las pruebas de extremo a extremo prueban lo que dicen.** Sobre todo dos detalles bien
  pensados: el caso `type=dialog` usa `sticky=on` en vez de `state=floating`
  (`tests/headless/rule_match.sh:198-201`), porque flotante es lo que bspwm ya hace solo con los
  diálogos y no distinguiría la regla del comportamiento por defecto; y el caso del PWA de Chrome
  comprueba además la **ventana normal del mismo `class`**, que es lo único que demuestra que son
  las dos condiciones juntas las que discriminan.
- **`node_ignores_tile_limits` (`tree.c:388-400`) mejora de verdad**: la condición de «solo
  reglas sin título» pasa a ser «sin título, tipo, rol ni transitoriedad», que es lo correcto
  ahora que hay más propiedades que no se conocen tan pronto, y ya no repite el `streq`.
- **El refactor de `_apply_window_type` / `_apply_transient` no cambia comportamiento.** Se
  verificó: cuando la ventana no declara `_NET_WM_WINDOW_TYPE`, ahora se llama con
  `BSP_WINDOW_TYPE_NORMAL` y el `switch` cae en `default: break` (`rule.c:288-308`), igual que
  antes cuando se salía temprano. Y `backend_get_transient_for` escribe `*transient_for` siempre,
  también al fallar, en los dos backends, así que ignorar su valor de retorno es seguro.
- **Comentarios en inglés, `/* */`, sin `//`, sin texto en español** en ninguno de los ficheros
  tocados. Verificado con grep.

---

## Hallazgos

### Críticos (0)

Ninguno.

---

### Importantes (6)

#### I-1. Un patrón de la forma antigua que contenga `=` deja de funcionar

**`src/messages.c:1293`**

```c
bool new_form = (strchr(args[0], '=') != NULL);
```

El comentario de al lado dice «El patrón antiguo CLASS[:INSTANCE[:NAME]] nunca contiene uno».
No es cierto: el tercer campo es **el título de la ventana**, texto arbitrario.

Comprobado en headless:

```
$ bspc rule -a 'st:*:vim = notes' state=floating
rule: Unknown key: 'st:*:vim '.
   [exit 1]
```

Antes de la rama esa regla se daba de alta y funcionaba. Es el único punto donde la promesa de
«compatibilidad hacia atrás total» se rompe de forma visible. El diseño lo eligió a conciencia
(«Si el primer argumento no contiene `=`…»), y falla en voz alta en vez de callar, que es lo
menos malo. Pero:

- **el manual no lo cuenta.** En `doc/bspwm.1.asciidoc:644-648` se ofrecen las dos formas sin
  decir en ningún sitio **cómo se decide cuál es**. Quien tenga esa regla en su `bspwmrc` verá un
  error que habla de una clave que él nunca escribió.
- **sí hay salida, y tampoco se cuenta**: la forma nueva sí lo admite, porque `strchr` coge el
  **primer** `=` y el resto del valor se conserva tal cual. Verificado:
  `bspc rule -a 'name~=^Notes = ' state=floating` se da de alta y se lista bien.

**Qué haría:** documentar la regla de desambiguación y la salida (`'name=vim = notes'`) en el
manual, en el párrafo que ya describe las dos formas. Y, si se quiere ser fino, decidir la forma
no por «hay un `=`» sino por «lo que hay antes del primer `=` (quitando un `~` final) es una
propiedad o una consecuencia conocida»: eso deja pasar `st:*:vim = notes` como forma antigua y
no cuesta más que una llamada a `rule_prop_from_key()` y otra a `is_consequence_key()`.

#### I-2. `-o` escrito antes de las condiciones se traga como patrón antiguo

**`src/messages.c:1281-1293`**

La forma nueva no tiene argumento posicional, así que escribir la bandera primero es lo natural.
Comprobado:

```
$ bspc rule -a -o class=kitty state=floating
rule: Unknown key: 'class'.
   [exit 1]
```

`args[0]` es `-o`, no lleva `=`, se decide forma antigua, y `-o` acaba siendo el patrón de clase;
después `class=kitty` no es una consecuencia y revienta con un mensaje que no tiene nada que ver
con el problema. En la forma antigua `-o` al principio tampoco valía, pero allí había un patrón
posicional obligatorio que lo hacía obvio; aquí no lo hay.

**Qué haría:** consumir los `-o`/`--one-shot` iniciales (anotando `one_shot`) **antes** de
calcular `new_form`. Son cuatro líneas y quita un error inexplicable.

#### I-3. Las consecuencias se siguen truncando en silencio, justo al lado del sitio donde las condiciones fallan en voz alta

**`src/messages.c:1381-1386` y `1515-1520`** (copia del bucle), con el remate en `1394-1402` y
`1531-1540`.

`rule->effect` son `MAXLEN` = 256 bytes. El bucle copia hasta llenar y para, sin avisar.
Comprobado:

```
$ bspc rule -a class=kitty desktop=<60c> monitor=<60c> node=<60c> rectangle=<60c> sticky=on
   [exit 0]
class=kitty => desktop=ddd… monitor=ddd… node=ddd… rectangle=ddddddddddddddddddddddddddddddddddddddd
```

El `rectangle=` se cortó por la mitad y el `sticky=on` desapareció entero. La regla se dio de alta
con éxito y hace menos de lo que se le pidió, sin decirlo.

Esto viene de upstream, pero **la rama lo agrava por contraste**: en `messages.c:1484-1490` se
añadió a propósito un fallo duro para cuando las condiciones no caben en `cause` («fail the rule
instead of silently listing it as something shorter than what was actually compiled»), y el
commit se llama literalmente «stop lying about long or crowded rules». El gemelo de ese caso, a
treinta líneas de distancia, sigue mintiendo.

**Qué haría:** el mismo tratamiento. Si la consecuencia no cabe, `fail()` y no dar de alta la
regla. Y, ya puestos, el bucle de copia manual debería ser un helper compartido por las dos
formas (ver M-7).

#### I-4. `rule -l` imprime causas que `rule -r` no entiende, y el autocompletado las ofrece

**`src/rule.c:594-598`, `src/rule.c:123-131`, `src/types.h:392`,
`contrib/zsh_completion:308-317`**

`types.h:392` dice: `/* The conditions as they were written, for 'rule -l' and 'rule -r'. */`.
Para la forma nueva la segunda mitad es falsa. `remove_rule_by_cause()` sigue troceando el
argumento por `:` y comparándolo contra los patrones de `class`, `instance` y `name`.
Comprobado:

```
$ bspc rule -l
class=kitty => state=floating
$ bspc rule -r 'class=kitty'      # la causa exacta que acaba de imprimir
   [exit 0]
$ bspc rule -l
class=kitty => state=floating     # sigue ahí
$ bspc rule -r 'kitty:*:*'        # esto sí
$ bspc rule -l
   [exit 0]
```

`bspc rule -r '*:*:*'` sí borra también las reglas de la forma nueva (verificado), así que no hay
reglas «inmortales». Pero el ciclo natural «listo, copio, borro» no funciona, y **el
autocompletado de zsh lo hereda**: `contrib/zsh_completion:310-317` lee `bspc rule -l` y parte
cada línea en `target settings` por el primer espacio, así que ahora ofrece `class=Google-chrome`
como candidato de `rule -r`, que no borra nada.

**Qué haría:** lo mínimo, documentar en el manual que `rule -r <causa>` solo entiende la forma
`CLASS:INSTANCE:NAME` y arreglar el `remove*` del autocompletado para que no ofrezca causas de la
forma nueva. Lo bueno, que `remove_rule_by_cause()` acepte también una lista de condiciones y la
compare contra `cause` completa.

#### I-5. Se lee `WM_WINDOW_ROLE` en cada ventana aunque ninguna regla lo use, y se interna el átomo cada vez

**`src/backend_x11.c:337-359`, `src/rule.c:418-429`**

```c
xcb_atom_t atom;
get_atom("WM_WINDOW_ROLE", &atom);          /* round-trip 1: xcb_intern_atom_reply */
...
xcb_get_property_reply(dpy, xcb_get_property(...), NULL);   /* round-trip 2 */
```

Dos viajes síncronos al servidor **por cada ventana gestionada**, y `collect_window_props()`
llama siempre, haya o no alguna regla con condición `role`.

El fichero ya tiene la convención contraria: `x11_setup_atoms()` (`backend_x11.c:776-782`) interna
`WM_STATE`, `WM_DELETE_WINDOW`, `WM_TAKE_FOCUS` y `WM_CHANGE_STATE` una sola vez al arrancar. Y
`tree.c:379-381` lleva un comentario explícito sobre haber quitado exactamente este tipo de
round-trip por inserción. Esto va justo en contra de las dos cosas.

**Qué haría:** añadir `WM_WINDOW_ROLE` a `x11_setup_atoms()` con su variable global, y saltarse la
lectura salvo que alguna regla tenga `conds[RULE_PROP_ROLE].used` (una bandera global que
`add_rule`/`remove_rule` mantengan, o un recorrido de la lista, que es corto).

#### I-6. La lista de claves de consecuencia está duplicada y nada impide que se separe

**`src/messages.c:1258-1272`** duplica el encadenado de `streq` de
**`src/rule.c:parse_key_value` (líneas 529-589)**, más `ignore_tile_limits`.

Hoy coinciden exactamente: se comprobó una por una contra un bspwm vivo
(`honor_size_hints split_dir split_ratio layer rectangle monitor desktop node hidden private
locked marked border state sticky follow manage focus center ignore_tile_limits` → todas
aceptadas). Hay un comentario que explica la excepción de `ignore_tile_limits`.

El problema es el futuro. **Antes de esta rama, una clave desconocida se ignoraba en silencio;
ahora es un error duro.** Eso convierte cualquier deriva entre las dos listas en un fallo visible
al usuario: quien añada una consecuencia nueva a `parse_key_value` y no se acuerde de esta lista
dejará una regla legítima rechazada con «Unknown key», y no hay ninguna prueba que lo detecte.

**Qué haría:** una sola fuente. O una tabla en `rule.c` que `parse_key_value` recorra y que
`messages.c` consulte con una función exportada, o —si se prefiere no tocar `parse_key_value`—
una prueba en `tests/headless/rule_match.sh` que dé de alta una regla con **todas** las claves y
falle si alguna se rechaza.

---

### Menores (15)

#### M-1. En la forma antigua se rechaza una consecuencia acabada en `/i`, y la razón que se da es falsa
**`src/messages.c:1367-1380`.** El comentario dice que un valor acabado en `/i` «would still be
silently dropped by parse_key_value()». Para `state`, `layer`, `split_dir` y los booleanos es
cierto; para `monitor`, `desktop`, `node` y `rectangle` **no**: `parse_key_value` los guarda tal
cual (`rule.c:532-538`). Comprobado: `bspc rule -a kitty desktop=web/i` daba antes una regla que
funcionaba y ahora da `rule: desktop: A consequence can't take a case marker.`. El riesgo real es
casi nulo (haría falta un escritorio llamado `web/i`), pero es un cambio de comportamiento en la
forma antigua apoyado en una justificación equivocada. Dejaría el rechazo solo para las claves
donde el valor sí se descarta, o al menos corregiría el comentario.

#### M-2. La misma equivocación se trata de dos maneras según la forma
**`src/messages.c:1357-1359`** (forma antigua) trunca una clave demasiado larga y luego la acusa
truncada; **`messages.c:1425-1429`** (forma nueva) falla con «Key too long». Dos mensajes para el
mismo error.

#### M-3. El `/i` en `type` y `transient` se acepta, no hace nada y desaparece del listado
**`src/rule_match.c:105-121`.** `cond->ignore_case = false` borra la marca, así que
`bspc rule -a type=dialog/i center=on` se lista como `type=dialog`. Verificado. Está documentado
en el manual, pero es el único punto donde el criterio 9 («`rule -l` devuelve cada regla tal como
se escribió») no se cumple. Dado que a esas mismas dos propiedades sí se les rechaza el `~=`,
sería más coherente rechazarles también el `/i`.

#### M-4. `regfree()` sobre un `regex_t` que `regcomp()` dejó indefinido
**`src/rule_match.c:126-130`.** POSIX dice que si `regcomp()` devuelve distinto de cero el
contenido de `preg` es indefinido; llamar a `regfree()` sobre él es formalmente UB. En glibc es
inofensivo (`regcomp` limpia y pone a NULL `buffer` y `fastmap` en el camino de error, y el
`memset` previo deja el resto a cero) y ASan no protesta, pero en una libc con otra
implementación puede no serlo. Es además innecesario. Lo quitaría.

#### M-5. `pattern` y `text` son dos copias de 256 bytes de lo mismo
**`src/rule_match.h:62-65`.** Solo difieren cuando `transient` se escribe `true`/`false`. Son
~640 bytes por condición y ~3,8 KB por `rule_t` (seis condiciones): con la configuración de 95
reglas, ~360 KB de reglas. Bastaría un buffer y un `bool` con el valor normalizado de
`transient`.

#### M-6. `window_props_t` copia tres cadenas que no hace falta copiar
**`src/rule.c:395-429`.** `collect_window_props()` hace tres `snprintf` de 256 bytes desde
`csq->class_name`, `csq->instance_name` y `csq->name` a un buffer nuevo, por ventana, para luego
solo leerlos. `rule_conds_match()` toma `const char *`. Solo `role` necesita almacenamiento
propio; el `values[]` podría apuntar directamente a los campos de `csq`, y `window_props_t`
desaparecería.

#### M-7. Cuatro bloques casi idénticos de copia de la consecuencia
**`src/messages.c:1381-1386` vs `1515-1520`**, y **`1394-1402` vs `1531-1540`**. El bucle de copia
y el recorte del espacio final están duplicados letra por letra entre las dos formas. Un helper
`append_effect(rule, arg, &i, more_follows)` los unifica y es donde tendría que vivir el arreglo
de I-3.

#### M-8. `cause` está dimensionado para la forma antigua y rechaza reglas nuevas perfectamente válidas
**`src/types.h:393`** (`char cause[3 * MAXLEN]`, 768 bytes). La forma nueva puede tener seis
condiciones de hasta 255 caracteres cada una, ~1600 bytes. Cuando no cabe, la regla **se rechaza**
(`messages.c:1484-1490`), y la propia suite lo da por bueno
(`tests/headless/rule_match.sh:124-126`). Es decir: una regla legítima se cae por el tamaño de un
buffer de impresión, no por nada semántico. Dimensionaría `cause` para el peor caso real
(`RULE_PROP_COUNT * (RULE_PATTERN_MAXLEN + 32)`) y así nadie se topa con un límite que no puede
prever.

#### M-9. `strcmp(text, "*")` en cada comparación
**`src/rule_match.c:150`.** Se evalúa por ventana × regla × propiedad. Una bandera `bool any`
puesta al compilar lo quita.

#### M-10. Huecos del manual
**`doc/bspwm.1.asciidoc:644-676` y `doc/bspwm.1:1089-1176`.** Falta: (a) cómo se decide entre las
dos formas —el `=` del primer argumento— (ver I-1); (b) que `*` sigue valiendo como comodín de
campo con `=` pero es una regex inválida con `~=` (comprobado: `class~=*` →
«Invalid preceding regular expression»); (c) el límite de 255 caracteres por patrón; (d) que una
regla sin ninguna condición coincide con todas las ventanas; (e) que `role` es solo de X11 y en la
compilación de wlroots siempre está vacío (`backend_wlr.c:2303-2312`); (f) que `rule -r <causa>`
solo entiende la forma antigua (ver I-4). Además la sinopsis de `-r`
(`doc/bspwm.1.asciidoc:678`) no se actualizó.

#### M-11. El autocompletado no ofrece condiciones donde más falta hacen
**`contrib/zsh_completion:264-281` y `300-304`.** El `[[ "$words[1]" == *=* ]]` de la línea 300 es
correcto (tras el `compset -N` de la 262, `words[1]` es el primer argumento de la regla, no
`bspc`). Pero el caso `(add1)` —el que se dispara al completar **el primer** argumento— solo
propone nombres de clase de las ventanas abiertas, así que `bspc rule -a cla<TAB>` nunca sugiere
`class=`, que es justo por donde empieza la forma nueva. Además siguen faltando
`honor_size_hints` e `ignore_tile_limits` de la lista de consecuencias (venía de antes, pero ahora
que una clave desconocida es un error se nota más).

#### M-12. La prueba unitaria ignora varios valores de retorno de `rule_cond_compile`
**`tests/test_rule_match.c:140, 148, 155, 157, 167, 168`.** Si alguno dejara de compilar, los
`check_str`/`rule_conds_match` de después leerían un `cond` a cero o rancio y podrían pasar por el
motivo equivocado. Envolverlos en el `matches_flags()` que ya existe, o comprobar el retorno.

#### M-13. Huecos de la prueba unitaria
**`tests/test_rule_match.c`.** No se cubre: el borde de longitud 255/256 (solo está a nivel de
shell), la normalización `transient=true` → `on`, ni `rule_cond_print()` para `transient` o para
un patrón vacío. Son tres `check` más y cierran el módulo entero.

#### M-14. Dos asserts que no aseguran nada
**`tests/headless/rule_match.sh:23-25` y todos los `$BSPC rule -r tail || true`.**
`bspc rule -r` sale con 0 tanto si borra como si no (verificado), así que
`assert_ok "remove old pattern with an invalid regex"` pasa siempre. La regla de la línea 24 nunca
se demuestra eliminada, y la comparación `BEFORE`/`AFTER` de la línea 128, al ser relativa,
tampoco lo detectaría. Comprobar `bspc rule -l | wc -l` después de cada borrado.

#### M-15. Detalles de construcción y de la lectura del rol
**`tests/Makefile:3-4`**: dos líneas `all:` separadas (funciona, pero es raro) y
`$(CC) $(CFLAGS) -std=c23` cuando `CFLAGS` ya trae `-std=c99` —gana el último, pero es frágil—;
además la prueba unitaria se compila solo con `-Wall -Wextra`, no con las banderas estrictas con
las que se compila el módulo. **`src/backend_x11.c:349`**: el argumento `long_length` de
`xcb_get_property` va en unidades de 32 bits, así que pasar `len` (256) pide 1024 bytes en vez de
256; es inofensivo porque `safe_len` recorta, pero las unidades están mal. Y se pide solo
`XCB_ATOM_STRING`, así que un cliente que publique `WM_WINDOW_ROLE` como `UTF8_STRING` se lee como
«sin rol».

---

## Los 11 criterios de aceptación

| # | Criterio | Estado | Evidencia |
|---|---|---|---|
| 1 | `class=Pavucontrol/i` coincide con `pavucontrol` | **Cumple** | e2e en Xvfb, `rule_match.sh:137-146`, PASS |
| 2 | `class~=^(eog\|feh)$` coincide con las dos y no con otras | **Cumple** | unitaria (`test_rule_match.c:85-88`); el e2e equivalente se hace con `instance~=^crx_` |
| 3 | `class=Google-chrome instance~=^crx_` distingue PWA de navegador | **Cumple** | e2e, incluida la ventana normal del mismo `class`, PASS |
| 4 | `type=dialog` coincide con `_NET_WM_WINDOW_TYPE_DIALOG` | **Cumple** | e2e con `sticky=on` para no confundirse con el flotante por defecto, PASS |
| 5 | `role=pop-up` coincide con `WM_WINDOW_ROLE=pop-up` | **Cumple** | e2e, PASS |
| 6 | `transient=on` coincide con ventana hija y no con una normal | **Cumple** | e2e con los dos casos, PASS |
| 7 | La forma antigua sigue igual y la config de Mauricio arranca sin cambios | **Cumple, con dos excepciones** | el `bspwm_rules.sh` previo a la migración da de alta **95/95 reglas, cero errores**. Excepciones: un patrón antiguo con `=` se rechaza (I-1) y un campo de más de 255 caracteres se rechaza donde antes se truncaba en silencio. Ninguna de las dos aparece en su configuración |
| 8 | Regex inválida / `type` inválido / condición repetida / clave desconocida fallan y no dan de alta | **Cumple** | los cuatro casos, más la forma antigua, en `rule_match.sh:103-128`, PASS; verificado también a mano |
| 9 | `rule -l` devuelve cada regla tal como se escribió | **Cumple, salvo un caso** | verificado el ida y vuelta de `role=Pop-Up/i`, `name~=^notes$/i`, `transient=true`, la forma antigua y una regla de seis condiciones. La excepción: el `/i` inerte de `type`/`transient` no se imprime (M-3) |
| 10 | `make` sin avisos y `make test` en verde | **Cumple** | compilación limpia con los CFLAGS estrictos; **220/220 (x11)** |
| 11 | La rama sale de `upstream/master` y se sostiene sola | **Cumple** | `merge-base(e76b9d8, upstream/master)` = `4cc03f1` = HEAD de `upstream/master`, 0 commits intermedios |

---

## Recomendaciones para el PR a upstream

1. Antes de abrirlo, I-1 y I-2: son los dos que un revisor de upstream encontrará en cinco
   minutos probando la interfaz, y los dos se arreglan en pocas líneas.
2. I-3 e I-6 son los que más valor tienen a medio plazo: cierran la incoherencia entre «las
   condiciones fallan fuerte» y «las consecuencias se truncan callando», y quitan la única
   duplicación que puede convertirse en un fallo de usuario.
3. En la descripción del PR hay que contar explícitamente los **dos cambios de comportamiento
   deliberados**: una clave desconocida ahora es un error (antes se ignoraba), y un primer
   argumento con `=` se lee como la forma nueva. Son los dos que pueden romper configuraciones
   ajenas, y ambos se justifican solos si se cuentan de frente.
4. El riesgo «memoria» que preveía el diseño no se ha materializado: ASan/LSan limpio y todas las
   rutas de error liberan. Vale la pena decirlo en el PR.
