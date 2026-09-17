# Reglas por propiedades de la ventana (diseño)

Estado: aprobado (2026-09-17). Repo: fork `maflorezp/bspwm1`, rama de trabajo `rule-match`.

## Objetivo

Que una regla de bspwm pueda identificar ventanas por más de una propiedad y sin depender de
mayúsculas exactas:

```bash
bspc rule -a class=Pavucontrol/i state=floating sticky=on
bspc rule -a 'class~=^(eog|feh|ristretto)$/i' state=floating focus=on follow=on
bspc rule -a class=Google-chrome instance~=^crx_ state=floating sticky=on center=on
bspc rule -a type=dialog state=floating center=on
bspc rule -a class=Google-chrome role=pop-up state=floating
bspc rule -a transient=on state=floating
```

## Por qué

En la configuración de Mauricio hay **95 reglas activas**, y la forma de identificar ventanas se
queda corta de tres maneras:

- **Las mayúsculas se comparan tal cual.** `apply_rules` usa `strcmp` (`src/rule.c:409-411`,
  `streq` en `src/helpers.h:120`). En su configuración conviven `pavucontrol` (lista de
  flotantes) y `Pavucontrol` (lista de *sticky*): son dos reglas que nunca se tocan, así que esa
  ventana no recibe el `state=floating` que él cree que tiene. Lo mismo pasa con `Rambox` y
  `Ferdium` en la lista de exclusión de su script externo.
- **No hay patrones parciales.** `MATCH_ANY` (`*`, `src/rule.h:28`) solo vale como campo entero.
  Por eso sus 13 aplicaciones de Chrome se escriben una a una (`Google-chrome:crx_<ID>`), y sus
  34 aplicaciones flotantes son 34 reglas generadas por un bucle.
- **Solo se puede filtrar por clase, instancia y título.** bspwm ya lee el tipo de ventana
  (`_NET_WM_WINDOW_TYPE`, `src/backend_x11.c:438-458`) y si la ventana es hija
  (`WM_TRANSIENT_FOR`, `src/backend_x11.c:400-407`), pero **no se pueden usar en una regla**, y
  `WM_WINDOW_ROLE` no se lee en ningún sitio. Mauricio ya los necesita: los consulta a mano con
  `xprop` en `focus_windows_by_role.sh` y en `run_if_window_match`.

El resultado es que la misma pregunta —«¿esta ventana coincide con este patrón?»— está resuelta
hoy en cuatro sitios distintos, cada uno con sus propias reglas de mayúsculas y comodines: las
reglas nativas (`src/rule.c`), una copia dentro de bspwm para `ignore_tile_limits`
(`src/tree.c:385-402`), el `external_rules_command` de Mauricio y su `organize-windows.sh`.

## Hechos verificados (2026-09-17, sobre `local` = 6452afd)

- **Estructura de la regla:** `rule_t` (`src/types.h:388-397`) solo tiene `class_name`,
  `instance_name`, `name`, `effect` (texto sin parsear) y `one_shot`.
- **Patrón:** `CLASE[:INSTANCIA[:NOMBRE]]`, tokenizado con `:` y con `\` como escape
  (`src/messages.c:1269-1287`). Los campos vacíos se guardan como `*`.
- **Aplicación:** las reglas se recorren en orden de alta y **se acumulan**; cada una sobrescribe
  las claves que fija (`parse_keys_values`, `src/rule.c:481-541`). Una regla `-o` se aplica una
  vez y corta el bucle.
- **Claves desconocidas:** `parse_key_value` **las ignora en silencio**. Una errata como
  `clas=kitty` hoy no da error y no hace nada.
- **Tipos de ventana que bspwm reconoce:** `DOCK`, `DESKTOP`, `NOTIFICATION`, `DIALOG`,
  `UTILITY`, `TOOLBAR` y `NORMAL` (`src/backend.h:269-275`).
- **Reglas externas:** `schedule_rules` (`src/rule.c:424-456`) llama al comando con el id de
  ventana, la clase, la instancia y las consecuencias intermedias. **No pasa el título.**

## Sintaxis

### Forma nueva

Una regla es una lista de argumentos `clave=valor`. Las claves se reparten en dos grupos que no
se solapan:

- **Condiciones:** `class`, `instance`, `name`, `type`, `role`, `transient`.
- **Consecuencias:** las de siempre (`monitor`, `desktop`, `node`, `split_dir`, `split_ratio`,
  `state`, `layer`, `honor_size_hints`, `rectangle`, `hidden`, `sticky`, `private`, `locked`,
  `marked`, `center`, `follow`, `manage`, `focus`, `border`).

Reglas de la forma nueva:

- Cada condición puede aparecer **una sola vez** por regla. Repetirla es un error.
- **Todas las condiciones tienen que cumplirse.** Para una alternativa, se usa la regex.
- Una regla **sin ninguna condición** coincide con todas las ventanas, igual que `*:*` hoy.
- **Una clave desconocida es un error**, tanto si parece condición como si parece consecuencia.
  Es un cambio respecto a hoy, que las ignora: una errata dejaba la regla sin efecto y sin aviso.

### Patrones

La regex se marca con el **operador**, `~=` en vez de `=`, y las mayúsculas con el sufijo `/i`
del valor. El valor no se interpreta de ninguna otra forma: puede empezar por `~` sin que eso
signifique nada.

El valor de `class`, `instance`, `name` y `role` admite cuatro formas:

| Forma | Ejemplo | Significado |
|---|---|---|
| Exacta | `class=kitty` | Idéntico, distinguiendo mayúsculas (lo de hoy) |
| Exacta sin mayúsculas | `class=kitty/i` | Idéntico, sin distinguir mayúsculas |
| Regex | `class~=^crx_` | Expresión regular POSIX extendida, la de `grep -E` |
| Regex sin mayúsculas | `class~=^crx_/i` | Igual, sin distinguir mayúsculas |

- El sufijo `/i` solo cuenta **al final del valor**. Para comparar un texto que de verdad termina
  en `/i`, se usa la forma regex: `name~=/i$`.
- `*` sigue valiendo como «cualquier cosa», por compatibilidad con la forma antigua.
- La regex se compila al crear la regla. Si está mal escrita, `bspc rule -a` **falla en ese
  momento**, con el mensaje de `regerror`, y la regla no se da de alta.

### Valores de `type` y de `transient`

- `type` admite exactamente `normal`, `dialog`, `utility`, `toolbar`, `dock`, `desktop` y
  `notification`. Cualquier otro valor es un error. No admite regex: es una lista cerrada.
- `transient` admite `on` y `off`, como los booleanos de las consecuencias. `on` significa que la
  ventana declara `WM_TRANSIENT_FOR`, es decir, que es hija de otra.

### Forma antigua

Si el **primer argumento no contiene `=`**, se lee como el patrón de siempre,
`CLASE[:INSTANCIA[:NOMBRE]]`, con comparación exacta y `*` como comodín de campo:

```bash
bspc rule -a Google-chrome:crx_abc desktop=work follow=on
```

Es la compatibilidad hacia atrás: ninguna configuración existente se rompe, y el PR a upstream no
obliga a nadie a migrar. Internamente, esa forma se convierte en tres condiciones exactas.

### `bspc rule -l`

Cada regla se imprime **como se escribió**: la forma antigua se ve como antes, y la nueva se ve
con sus condiciones. Para eso, la regla guarda el texto del patrón además de su forma compilada.

## Semántica

- El orden y la acumulación **no cambian**: las reglas se evalúan en orden de alta, cada una
  sobrescribe las claves que fija, y `-o` sigue aplicándose una vez y cortando el resto.
- Las condiciones se evalúan contra las propiedades de la ventana tal como están **cuando bspwm
  la va a gestionar**. El título puede cambiar después; eso ya pasa hoy con el tercer campo.
- Una propiedad que la ventana no declara (por ejemplo, `role` en una ventana sin
  `WM_WINDOW_ROLE`) se trata como cadena vacía: solo coincide con una condición que acepte vacío,
  como `role~=^$`.

## Arquitectura

### `src/rule_match.c` y `src/rule_match.h` (nuevos)

Módulo puro, sin X y sin estado global, al estilo de `magnet.c` y `edge_zone.c`, para poder
probarlo con pruebas unitarias:

- Un tipo de condición con: la propiedad, la forma de comparar, el texto original del patrón y,
  si hace falta, la regex compilada.
- Compilar un valor con las marcas que le da quien llama (`RULE_COND_REGEX` y `RULE_COND_ICASE`),
  devolviendo el error de `regcomp` si lo hay. El módulo **no interpreta el valor**: quién decide
  las marcas es el parseo del argumento, que ve el operador y el sufijo.
- Comparar una condición contra un valor de texto.
- Liberar lo compilado.

Las propiedades de la ventana viajan en una estructura sencilla (clase, instancia, título, tipo,
rol y si es hija), que el que llama rellena.

### Cambios en el resto

- **`src/types.h`:** `rule_t` guarda un array de condiciones, una por propiedad, en vez de los
  tres campos de texto.
- **`src/rule.c`:**
  - `apply_rules` construye una vez la estructura de propiedades y la compara con cada regla a
    través del módulo nuevo;
  - `remove_rule` libera las regex compiladas.
- **`src/messages.c`:** `cmd_rule` distingue la forma nueva de la antigua, separa la propiedad,
  el operador (`=` o `~=`) y el valor, quita el sufijo `/i`, valida las claves y da de alta la
  regla. La forma antigua compila sin ninguna marca, así que se compara literal.
- **`src/query.c`:** la impresión de `rule -l`.
- **`src/tree.c`:** `node_ignores_tile_limits` deja de repetir la comparación y usa el módulo.
- **Backend:** una función nueva para leer `WM_WINDOW_ROLE`, con implementación en
  `backend_x11.c` y una versión vacía en el backend de wlroots.
- **Documentación:** la sección `rule` del manual, con las dos formas y una tabla de propiedades.

## Pruebas

1. **Unitarias** (`tests/test_rule_match.c`), sin X:
   - las tres formas de comparar, incluyendo `/i`;
   - regex inválida: error al compilar;
   - `*` y condición ausente;
   - propiedad vacía (`role` sin declarar);
   - el caso real: `instance~=^crx_` coincide con `crx_abc` y **no** con la ventana normal de
     Chrome.
2. **De la interfaz** (`tests/headless/rule_match.sh`):
   - alta con la forma antigua y con la nueva; `rule -l` devuelve cada una tal cual;
   - clave desconocida, condición repetida, `type` inválido y regex inválida dan error y no dan
     de alta la regla.
3. **De extremo a extremo**, en Xvfb: abrir ventanas con clase, rol, tipo y transitoriedad
   concretos y comprobar dónde acaban. Para esto hay que ampliar `tests/test_window.c`, que hoy
   solo fija nombre y clase, con opciones para el rol, el tipo y la ventana padre.

## Migración de la configuración de Mauricio

Va **después** de instalar y comprobar que su `bspwm_rules.sh` actual sigue funcionando sin
tocarlo.

- Las 34 aplicaciones flotantes pasan a una regla con alternancia, generada por el mismo bucle.
- Las 13 PWA de Chrome pasan a una regla con `instance~=^crx_`, y solo las que necesiten un
  escritorio propio conservan la suya.
- Los cuatro grupos de escritorio (`data`, `code`, `work`, `communication`) pasan a una regla
  cada uno.
- Las 20 reglas sueltas de `sticky=on` y `center=on` se funden en la regla de su grupo.
- Se corrigen `pavucontrol`/`Pavucontrol` y `Rambox`/`Ferdium`. **Es un cambio de comportamiento
  visible:** esas ventanas empezarán a salir flotantes.
- La versión anterior del fichero se conserva hasta que Mauricio valide.

## Fuera de alcance

- **Pasar más datos al `external_rules_command`** (título, tipo, rol y si es hija). Va en su
  propia rama y su propio PR, para no engordar este cambio.
- Listas separadas por comas (`class=eog,feh`): la regex ya lo cubre.
- Grupos de reglas con nombre: añadirían un concepto y estado nuevos a bspwm.
- Filtrar por PID, por el binario del proceso o por los estados EWMH.
- `organize-windows.sh`, que reimplementa el matching en bash por su cuenta.

## Riesgos

- **Una regex de más.** Un patrón demasiado amplio afecta a más ventanas de las previstas. Lo
  acotan el error al crear la regla, que `rule -l` muestre el patrón original y la prueba del
  caso `crx_`.
- **Claves desconocidas que ahora fallan.** Si alguna configuración tenía una errata silenciosa,
  ahora dará error al arrancar. Es el objetivo, pero conviene contarlo en el PR.
- **Coste por ventana.** Se añade una lectura de `WM_WINDOW_ROLE` por ventana nueva y la
  ejecución de las regex compiladas. Solo ocurre al gestionar la ventana, no en cada evento.
- **Memoria.** Cada regla con regex reserva y libera su `regex_t`; `remove_rule` tiene que
  liberarlas, y las pruebas de alta y baja repetida lo cubren.

## Criterios de aceptación

1. `bspc rule -a class=Pavucontrol/i state=floating` coincide con una ventana cuya clase es
   `pavucontrol`.
2. `bspc rule -a 'class~=^(eog|feh)$' state=floating` coincide con las dos clases y no con otras.
3. `bspc rule -a class=Google-chrome instance~=^crx_ …` coincide con las PWA y no con la ventana
   normal de Chrome.
4. `bspc rule -a type=dialog state=floating center=on` coincide con una ventana que declara
   `_NET_WM_WINDOW_TYPE_DIALOG`.
5. `bspc rule -a role=pop-up …` coincide con una ventana cuyo `WM_WINDOW_ROLE` es `pop-up`.
6. `bspc rule -a transient=on …` coincide con una ventana hija y no con una normal.
7. La forma antigua (`CLASE:INSTANCIA:NOMBRE`) sigue funcionando igual, y la configuración actual
   de Mauricio arranca sin cambios.
8. Una regex inválida, un `type` inválido, una condición repetida o una clave desconocida dan
   error en `bspc rule -a` y no dan de alta la regla.
9. `bspc rule -l` devuelve cada regla tal como se escribió.
10. `make` no da avisos y `make test` queda en verde, con las pruebas nuevas incluidas.
11. La rama `rule-match` sale de `upstream/master` y se sostiene sola como PR.
