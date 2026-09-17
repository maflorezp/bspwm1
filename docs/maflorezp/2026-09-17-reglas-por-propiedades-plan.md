# Reglas por propiedades de la ventana — plan de implementación

> **Para quien lo ejecute:** usa la skill `superpowers:subagent-driven-development`. Los pasos
> llevan casilla (`- [ ]`) para ir marcándolos.

**Goal:** que una regla de bspwm pueda identificar ventanas por clase, instancia, título, tipo,
rol y transitoriedad, con comparación exacta, exacta sin mayúsculas o por expresión regular.

**Architecture:** un módulo puro nuevo (`src/rule_match.c`) compila y evalúa condiciones
`propiedad=patrón`. `rule_t` pasa a guardar un array de condiciones en vez de tres cadenas.
`apply_rules` reúne una vez las propiedades de la ventana y las compara con cada regla a través
del módulo. La sintaxis antigua `CLASE:INSTANCIA:NOMBRE` se convierte en condiciones exactas, así
que sigue funcionando igual.

**Tech Stack:** C23, xcb, `regcomp`/`regexec` de POSIX (libc, sin dependencias nuevas), pruebas
unitarias en C y pruebas de extremo a extremo en Xvfb con `tests/run_headless`.

**Spec:** `docs/maflorezp/2026-09-17-reglas-por-propiedades-diseno.md`

## Global Constraints

- **Rama:** `rule-match`, creada desde `upstream/master` (4cc03f1). Se funde en `local` al final.
- **Convenciones de bspwm1:** identificadores y comentarios en inglés, comentarios `/* */`,
  tabuladores, C23, sin avisos con los `CFLAGS` del `Makefile`, Conventional Commits en inglés y
  pruebas en commits separados del código.
- **No se tocan** `doc/CHANGELOG.md` ni `VERSION`.
- **Nunca** se añade un trailer de Claude a un commit.
- **Identidad de los commits:** `Mauricio Alexander Flórez <maflorezp@gmail.com>`, ya configurada
  en el repositorio.
- **Compatibilidad hacia atrás:** `bspc rule -a CLASE[:INSTANCIA[:NOMBRE]] …` sigue funcionando
  exactamente igual; la configuración actual de Mauricio tiene que arrancar sin cambios.
- **Propiedades admitidas:** `class`, `instance`, `name`, `type`, `role`, `transient`.
- **Formas de comparar:** exacta (`class=kitty`), exacta sin mayúsculas (`class=kitty/i`), regex
  POSIX extendida (`class~=^crx_`) y regex sin mayúsculas (`class~=^crx_/i`).
- **Valores de `type`:** `normal`, `dialog`, `utility`, `toolbar`, `dock`, `desktop`,
  `notification`. **De `transient`:** `on`, `off`, `true`, `false`.
- **Errores al crear la regla:** regex inválida, `type` o `transient` con valor inválido,
  condición repetida y clave desconocida. En todos, `bspc rule -a` falla y la regla no se da de
  alta.
- **`make test` siempre con bloqueo:** `flock /tmp/bspwm1-make-test.lock make test`.
- **Nada de X contra el display real (:0).** Solo dentro de `make test`, o en un Xvfb propio en un
  display ≥ :230 con `BSPWM_SOCKET` sin definir.
- **`rm` es `rm -i` y `cp` es `cp -i`:** usa `command rm` y `command cp -f`.
- **Push:** `git push -u origin rule-match` está autorizado (`origin` empuja por SSH). Sin
  `--force`. **No se abren PRs.**
- **El worktree y la rama los crea quien coordina**, con
  `git worktree add -b rule-match /websites/personal/bspwm-worktrees/rule-match upstream/master`.
  Quien implementa trabaja siempre dentro de ese worktree, no en `/websites/personal/bspwm`.

---

### Task 1: Módulo `rule_match`

> **Nota del 2026-09-17, posterior a escribir el plan.** Tras la ronda de corrección de la tarea
> 3, `rule_cond_compile` recibe las marcas de quien llama —`RULE_COND_REGEX` y `RULE_COND_ICASE`,
> declaradas en `src/rule_match.h`— y **no interpreta el valor**: ni el `~` ni el sufijo `/i`. La
> regex se marca con el operador `~=` del argumento, y el sufijo `/i` lo quita el parseo de la
> tarea 4. El código de esta tarea que aparece abajo es el original, anterior a ese cambio.

**Files:**
- Create: `src/rule_match.h`, `src/rule_match.c`, `tests/test_rule_match.c`
- Modify: `Makefile`, `tests/Makefile`, `tests/run_headless`

**Interfaces:**
- Produces: `rule_prop_t`, `rule_cond_t`, `rule_prop_from_key()`, `rule_prop_name()`,
  `rule_cond_compile()`, `rule_cond_matches()`, `rule_cond_pattern()`, `rule_cond_print()`,
  `rule_cond_free()` y `rule_conds_match()`. Las tareas 3 y 4 los usan.

- [ ] **Step 1: Escribir la prueba que falla**

Crea `tests/test_rule_match.c`:

```c
/* Unit tests for rule_match.c: how a rule condition matches a window. */

#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include "../src/rule_match.h"

static int failures;

static void check(const char *desc, bool expected, bool actual)
{
	if (expected == actual) {
		printf("  PASS: %s\n", desc);
		return;
	}
	printf("  FAIL: %s: expected %s, got %s\n", desc,
	       expected ? "true" : "false", actual ? "true" : "false");
	failures++;
}

static void check_str(const char *desc, const char *expected, const char *actual)
{
	if (strcmp(expected, actual) == 0) {
		printf("  PASS: %s\n", desc);
		return;
	}
	printf("  FAIL: %s: expected '%s', got '%s'\n", desc, expected, actual);
	failures++;
}

/* Compile `value` for `prop` and return whether `text` matches it. The
 * condition must compile. */
static bool matches(rule_prop_t prop, const char *value, const char *text)
{
	rule_cond_t cond;
	char err[256];
	if (!rule_cond_compile(&cond, prop, value, err, sizeof(err))) {
		printf("  FAIL: could not compile '%s': %s\n", value, err);
		failures++;
		return false;
	}
	bool result = rule_cond_matches(&cond, text);
	rule_cond_free(&cond);
	return result;
}

int main(void)
{
	rule_prop_t prop;

	/* Property names. */
	check("class is a property", true, rule_prop_from_key("class", &prop));
	check("the property is the class", true, prop == RULE_PROP_CLASS);
	check("transient is a property", true, rule_prop_from_key("transient", &prop));
	check("state is not a property", false, rule_prop_from_key("state", &prop));
	check_str("the name of the role property", "role", rule_prop_name(RULE_PROP_ROLE));

	/* Exact, the way it has always worked. */
	check("an exact pattern matches", true, matches(RULE_PROP_CLASS, "kitty", "kitty"));
	check("an exact pattern is case sensitive", false,
	      matches(RULE_PROP_CLASS, "kitty", "Kitty"));
	check("a star matches anything", true, matches(RULE_PROP_CLASS, "*", "kitty"));

	/* Case insensitive. */
	check("with /i the case does not count", true,
	      matches(RULE_PROP_CLASS, "Pavucontrol/i", "pavucontrol"));
	check("with /i the rest still has to match", false,
	      matches(RULE_PROP_CLASS, "Pavucontrol/i", "pavucontrolx"));

	/* Regular expressions. */
	check("a regex matches a prefix", true,
	      matches(RULE_PROP_INSTANCE, "~^crx_", "crx_abcdef"));
	check("a regex anchored at the start does not match in the middle", false,
	      matches(RULE_PROP_INSTANCE, "~^crx_", "google-crx_abcdef"));
	check("the real case: a plain Chrome window is not a web app", false,
	      matches(RULE_PROP_INSTANCE, "~^crx_", "google-chrome"));
	check("an alternation matches every branch", true,
	      matches(RULE_PROP_CLASS, "~^(eog|feh|ristretto)$", "feh"));
	check("an alternation matches nothing else", false,
	      matches(RULE_PROP_CLASS, "~^(eog|feh|ristretto)$", "firefox"));
	check("a regex with /i ignores the case", true,
	      matches(RULE_PROP_CLASS, "~^(eog|feh)$/i", "FEH"));

	/* Empty properties: a window with no WM_WINDOW_ROLE. */
	check("an empty property matches an empty regex", true,
	      matches(RULE_PROP_ROLE, "~^$", ""));
	check("an empty property does not match a pattern", false,
	      matches(RULE_PROP_ROLE, "pop-up", ""));
	check("a NULL property counts as empty", true, matches(RULE_PROP_ROLE, "~^$", NULL));

	/* Closed value lists. */
	rule_cond_t cond;
	char err[256];
	check("dialog is a window type", true,
	      rule_cond_compile(&cond, RULE_PROP_TYPE, "dialog", err, sizeof(err)));
	rule_cond_free(&cond);
	check("popup is not a window type", false,
	      rule_cond_compile(&cond, RULE_PROP_TYPE, "popup", err, sizeof(err)));
	check("a regex is not allowed for the type", false,
	      rule_cond_compile(&cond, RULE_PROP_TYPE, "~dia", err, sizeof(err)));
	check("on is a transient value", true,
	      rule_cond_compile(&cond, RULE_PROP_TRANSIENT, "on", err, sizeof(err)));
	rule_cond_free(&cond);
	check("maybe is not a transient value", false,
	      rule_cond_compile(&cond, RULE_PROP_TRANSIENT, "maybe", err, sizeof(err)));

	/* A broken regex is refused, with the reason. */
	check("an unbalanced regex does not compile", false,
	      rule_cond_compile(&cond, RULE_PROP_CLASS, "~^(eog", err, sizeof(err)));
	check("and the error says something", true, err[0] != '\0');

	/* The pattern is kept as it was written. */
	rule_cond_compile(&cond, RULE_PROP_INSTANCE, "~^crx_/i", err, sizeof(err));
	check_str("the pattern keeps its shape", "~^crx_/i", rule_cond_pattern(&cond));
	char printed[512];
	rule_cond_print(&cond, RULE_PROP_INSTANCE, printed, sizeof(printed));
	check_str("printing gives back the condition", "instance~=^crx_/i", printed);
	rule_cond_free(&cond);

	/* A whole rule: every condition has to hold. */
	rule_cond_t conds[RULE_PROP_COUNT];
	memset(conds, 0, sizeof(conds));
	rule_cond_compile(&conds[RULE_PROP_CLASS], RULE_PROP_CLASS, "Google-chrome", err, sizeof(err));
	rule_cond_compile(&conds[RULE_PROP_INSTANCE], RULE_PROP_INSTANCE, "~^crx_", err, sizeof(err));
	const char *web_app[RULE_PROP_COUNT] = {"Google-chrome", "crx_abc", "Mail", "normal", "", "off"};
	const char *browser[RULE_PROP_COUNT] = {"Google-chrome", "google-chrome", "News", "normal", "", "off"};
	check("both conditions hold for the web app", true, rule_conds_match(conds, web_app));
	check("the instance rules the browser out", false, rule_conds_match(conds, browser));
	for (int i = 0; i < RULE_PROP_COUNT; i++) {
		rule_cond_free(&conds[i]);
	}

	rule_cond_t none[RULE_PROP_COUNT];
	memset(none, 0, sizeof(none));
	check("a rule with no conditions matches anything", true, rule_conds_match(none, browser));

	return failures ? 1 : 0;
}
```

En `tests/Makefile`, después de la línea `all: send_moveresize`, añade una línea nueva:

```make
all: test_rule_match
```

y, después de la regla de `test_edge_zone`, la suya:

```make
test_rule_match: test_rule_match.c ../src/rule_match.c ../src/rule_match.h
	$(CC) $(CFLAGS) -std=c23 -o $@ test_rule_match.c ../src/rule_match.c
```

y añade `test_rule_match` a la línea `clean`, que queda así:

```make
	$(RM) test_window test_window_wl test_color test_magnet send_moveresize test_edge_zone test_rule_match *.o
```

- [ ] **Step 2: Ver que falla**

```bash
make -C tests test_rule_match
```

Expected: falla la compilación, porque no existe `../src/rule_match.c`. Guarda la salida: es la
evidencia de la fase roja.

- [ ] **Step 3: Escribir el módulo**

`src/rule_match.h`:

```c
#ifndef BSPWM_RULE_MATCH_H
#define BSPWM_RULE_MATCH_H

#include <regex.h>
#include <stdbool.h>
#include <stddef.h>

/* How a rule picks the windows it applies to.
 *
 * A condition is one `property=pattern` pair. The pattern is compared as
 * written, ignoring case when it ends in `/i`, or as a POSIX extended regular
 * expression when it starts with `~`. Pure text handling with no backend, so
 * the unit tests drive it directly. */

#define RULE_PATTERN_MAXLEN 256

typedef enum {
	RULE_PROP_CLASS,
	RULE_PROP_INSTANCE,
	RULE_PROP_NAME,
	RULE_PROP_TYPE,
	RULE_PROP_ROLE,
	RULE_PROP_TRANSIENT,
	RULE_PROP_COUNT,
} rule_prop_t;

typedef struct {
	bool used;
	bool is_regex;
	bool ignore_case;
	/* The pattern as the user wrote it, `~` and `/i` included. */
	char pattern[RULE_PATTERN_MAXLEN];
	/* What is compared: the pattern without `~` and without `/i`. */
	char text[RULE_PATTERN_MAXLEN];
	regex_t preg;
} rule_cond_t;

/* The property `key` names, if it names one. */
bool rule_prop_from_key(const char *key, rule_prop_t *prop);
const char *rule_prop_name(rule_prop_t prop);

/* Compile `value` into `cond`. On failure it fills `err` with the reason and
 * leaves nothing to free. */
bool rule_cond_compile(rule_cond_t *cond, rule_prop_t prop, const char *value,
                       char *err, size_t len);
/* Whether `value` satisfies `cond`. An unused condition and the `*` pattern
 * match anything; a NULL value counts as empty. */
bool rule_cond_matches(const rule_cond_t *cond, const char *value);
/* Whether every condition in `conds` holds for `values`, indexed by property. */
bool rule_conds_match(const rule_cond_t *conds, const char *const *values);
/* The pattern as it was written, or "*" when the condition is unused. */
const char *rule_cond_pattern(const rule_cond_t *cond);
/* "property=pattern" into `buf`; the empty string when the condition is unused. */
void rule_cond_print(const rule_cond_t *cond, rule_prop_t prop, char *buf, size_t len);
void rule_cond_free(rule_cond_t *cond);

#endif
```

`src/rule_match.c`:

```c
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include "rule_match.h"

static const char *prop_names[RULE_PROP_COUNT] = {
	"class", "instance", "name", "type", "role", "transient",
};

/* The values `type` and `transient` accept; NULL ends each list. */
static const char *type_values[] = {
	"normal", "dock", "desktop", "notification", "dialog", "utility", "toolbar", NULL,
};
static const char *transient_values[] = {"on", "off", "true", "false", NULL};

bool rule_prop_from_key(const char *key, rule_prop_t *prop)
{
	if (key == NULL) {
		return false;
	}
	for (int i = 0; i < RULE_PROP_COUNT; i++) {
		if (strcmp(prop_names[i], key) == 0) {
			if (prop != NULL) {
				*prop = (rule_prop_t) i;
			}
			return true;
		}
	}
	return false;
}

const char *rule_prop_name(rule_prop_t prop)
{
	if (prop < 0 || prop >= RULE_PROP_COUNT) {
		return "?";
	}
	return prop_names[prop];
}

/* Whether `value` is one of the NULL-terminated `list`. */
static bool value_in(const char *const *list, const char *value)
{
	for (; *list != NULL; list++) {
		if (strcmp(*list, value) == 0) {
			return true;
		}
	}
	return false;
}

bool rule_cond_compile(rule_cond_t *cond, rule_prop_t prop, const char *value,
                       char *err, size_t len)
{
	if (cond == NULL || value == NULL || err == NULL || len == 0) {
		return false;
	}
	memset(cond, 0, sizeof(*cond));
	err[0] = '\0';

	if (strlen(value) >= sizeof(cond->pattern)) {
		snprintf(err, len, "the pattern is longer than %zu characters",
		         sizeof(cond->pattern) - 1);
		return false;
	}
	snprintf(cond->pattern, sizeof(cond->pattern), "%s", value);

	const char *text = value;
	if (text[0] == '~') {
		cond->is_regex = true;
		text++;
	}
	snprintf(cond->text, sizeof(cond->text), "%s", text);

	size_t text_len = strlen(cond->text);
	if (text_len >= 2 && strcmp(cond->text + text_len - 2, "/i") == 0) {
		cond->ignore_case = true;
		cond->text[text_len - 2] = '\0';
	}

	if (prop == RULE_PROP_TYPE || prop == RULE_PROP_TRANSIENT) {
		const char *const *list = (prop == RULE_PROP_TYPE) ? type_values : transient_values;
		if (cond->is_regex) {
			snprintf(err, len, "%s takes no regular expression", rule_prop_name(prop));
			return false;
		}
		if (!value_in(list, cond->text)) {
			snprintf(err, len, "'%s' is not a %s", cond->text, rule_prop_name(prop));
			return false;
		}
		/* `true` and `false` are the same as `on` and `off`. */
		if (prop == RULE_PROP_TRANSIENT) {
			bool on = strcmp(cond->text, "on") == 0 || strcmp(cond->text, "true") == 0;
			snprintf(cond->text, sizeof(cond->text), "%s", on ? "on" : "off");
		}
		cond->ignore_case = false;
	}

	if (cond->is_regex) {
		int flags = REG_EXTENDED | REG_NOSUB | (cond->ignore_case ? REG_ICASE : 0);
		int status = regcomp(&cond->preg, cond->text, flags);
		if (status != 0) {
			regerror(status, &cond->preg, err, len);
			regfree(&cond->preg);
			return false;
		}
	}

	cond->used = true;
	return true;
}

bool rule_cond_matches(const rule_cond_t *cond, const char *value)
{
	if (cond == NULL || !cond->used) {
		return true;
	}
	if (value == NULL) {
		value = "";
	}
	if (cond->is_regex) {
		return regexec(&cond->preg, value, 0, NULL, 0) == 0;
	}
	if (strcmp(cond->text, "*") == 0) {
		return true;
	}
	if (cond->ignore_case) {
		return strcasecmp(cond->text, value) == 0;
	}
	return strcmp(cond->text, value) == 0;
}

bool rule_conds_match(const rule_cond_t *conds, const char *const *values)
{
	if (conds == NULL || values == NULL) {
		return false;
	}
	for (int i = 0; i < RULE_PROP_COUNT; i++) {
		if (!rule_cond_matches(&conds[i], values[i])) {
			return false;
		}
	}
	return true;
}

const char *rule_cond_pattern(const rule_cond_t *cond)
{
	if (cond == NULL || !cond->used) {
		return "*";
	}
	return cond->pattern;
}

void rule_cond_print(const rule_cond_t *cond, rule_prop_t prop, char *buf, size_t len)
{
	if (buf == NULL || len == 0) {
		return;
	}
	if (cond == NULL || !cond->used) {
		buf[0] = '\0';
		return;
	}
	snprintf(buf, len, "%s=%s", rule_prop_name(prop), cond->pattern);
}

void rule_cond_free(rule_cond_t *cond)
{
	if (cond == NULL || !cond->used) {
		return;
	}
	if (cond->is_regex) {
		regfree(&cond->preg);
	}
	memset(cond, 0, sizeof(*cond));
}
```

En el `Makefile` de la raíz, añade `rule_match.c` al final de `CORE_SRC` (línea 10), que hoy
termina en `color.c magnet.c edge_zone.c`, para que se compile con los dos backends:

```make
	 messages.c parse.c query.c restore.c rule.c subscribe.c keybind.c snap.c color.c magnet.c edge_zone.c rule_match.c
```

- [ ] **Step 4: Ver que pasa**

```bash
make -C tests test_rule_match && tests/test_rule_match
make 2>&1 | grep -iE "warning|error"
```

Expected: todas las comprobaciones en `PASS`, `tests/test_rule_match` con código 0, y la
compilación del proyecto sin avisos.

- [ ] **Step 5: Cargar la prueba en la suite**

En `tests/run_headless`, justo antes de la línea `# ---- Quit ----`, añade:

```sh
. ./headless/rule_match.sh

```

y crea `tests/headless/rule_match.sh` con:

```sh
# Rule conditions: how a rule picks the windows it applies to.

echo ""
echo "== Rule matching =="

assert_ok "rule match unit tests pass" ./test_rule_match
```

Ejecuta `flock /tmp/bspwm1-make-test.lock make test > /tmp/bspwm1-rulematch-t1.log 2>&1` y
comprueba que sale ALL GREEN.

- [ ] **Step 6: Commits**

```bash
git add src/rule_match.c src/rule_match.h Makefile
git commit -m "feat: add a module for matching windows against rule conditions"
git add tests/test_rule_match.c tests/Makefile tests/headless/rule_match.sh tests/run_headless
git commit -m "test: cover the rule condition matching"
```

---

### Task 2: El rol de la ventana y las propiedades en un solo sitio

**Files:**
- Modify: `src/backend.h`, `src/backend_x11.c`, `src/window_ops.c`, `src/rule.c`, `src/rule.h`

**Interfaces:**
- Consumes: `backend_get_window_type()`, `backend_get_transient_for()` (ya existen).
- Produces: `bool backend_get_window_role(bspwm_wid_t win, char *role, size_t len)` y, en
  `rule.c`, la función estática `collect_window_props()`, que la tarea 3 usa para comparar.

Esta tarea **no cambia el comportamiento**: solo lee el rol y reúne las propiedades una sola vez,
para que la tarea 3 pueda comparar sin pedirle nada más al servidor.

- [ ] **Step 1: Leer `WM_WINDOW_ROLE`**

En `src/backend.h`, junto a la declaración de `backend_get_window_name`, añade:

```c
/* WM_WINDOW_ROLE, the role a client gives its own window ("pop-up", ...). */
bool backend_get_window_role(bspwm_wid_t win, char *role, size_t len);
```

En `src/backend_x11.c`, justo después de `backend_get_window_name`, añade:

```c
bool backend_get_window_role(bspwm_wid_t win, char *role, size_t len)
{
	if (role == NULL || len == 0) {
		return false;
	}
	role[0] = '\0';
	xcb_atom_t atom = get_atom("WM_WINDOW_ROLE");
	if (atom == XCB_ATOM_NONE) {
		return false;
	}
	xcb_get_property_reply_t *reply = xcb_get_property_reply(dpy,
		xcb_get_property(dpy, 0, win, atom, XCB_ATOM_STRING, 0, (uint32_t) len), NULL);
	if (reply == NULL) {
		return false;
	}
	int value_len = xcb_get_property_value_length(reply);
	if (value_len > 0) {
		size_t safe_len = (size_t) value_len < len - 1 ? (size_t) value_len : len - 1;
		memcpy(role, xcb_get_property_value(reply), safe_len);
		role[safe_len] = '\0';
	}
	free(reply);
	return role[0] != '\0';
}
```

**Antes de darlo por bueno:** comprueba cómo consigue este fichero un átomo por nombre. Busca
`get_atom`, `xcb_intern_atom` o una tabla de átomos (`grep -n 'intern_atom\|get_atom' src/backend_x11.c`)
y usa el mecanismo que ya exista, en vez de inventar uno. Si no hay ninguno, resuelve el átomo
con `xcb_intern_atom` una sola vez, en una variable estática del fichero.

En `src/window_ops.c`, junto a los demás stubs del backend de wlroots, añade:

```c
bool backend_get_window_role(bspwm_wid_t win, char *role, size_t len)
{
	(void) win;
	if (role != NULL && len > 0) {
		role[0] = '\0';
	}
	return false;
}
```

Comprueba cómo están escritos los stubs vecinos de ese fichero y sigue su forma.

- [ ] **Step 2: Reunir las propiedades una sola vez**

En `src/rule.c`, antes de `apply_rules`, añade:

```c
/* Everything a rule can match against, read once per window. */
typedef struct {
	char class_name[MAXLEN];
	char instance_name[MAXLEN];
	char name[MAXLEN];
	char role[MAXLEN];
	const char *type;
	const char *transient;
} window_props_t;

static const char *window_type_name(bspwm_window_type_t type)
{
	switch (type) {
		case BSP_WINDOW_TYPE_DOCK: return "dock";
		case BSP_WINDOW_TYPE_DESKTOP: return "desktop";
		case BSP_WINDOW_TYPE_NOTIFICATION: return "notification";
		case BSP_WINDOW_TYPE_DIALOG: return "dialog";
		case BSP_WINDOW_TYPE_UTILITY: return "utility";
		case BSP_WINDOW_TYPE_TOOLBAR: return "toolbar";
		default: return "normal";
	}
}
```

Después cambia `apply_rules` para que lea el tipo y la transitoriedad una sola vez y se los pase
a quien los aplica:

```c
void apply_rules(bspwm_wid_t win, rule_consequence_t *csq)
{
	/* Query window properties via backend */
	bspwm_window_type_t type = BSP_WINDOW_TYPE_NORMAL;
	if (!backend_get_window_type(win, &type)) {
		type = BSP_WINDOW_TYPE_NORMAL;
	}
	bspwm_wid_t transient_for = BSPWM_WID_NONE;
	backend_get_transient_for(win, &transient_for);

	_apply_window_type(type, csq);
	_apply_window_state(win, csq);
	_apply_transient(transient_for, csq);
	_apply_hints(win, csq);
	_apply_class(win, csq);
	_apply_name(win, csq);

	window_props_t props;
	collect_window_props(win, csq, type, transient_for, &props);
```

El resto de la función —el bucle `while (rule != NULL) { … }` con la comparación de los tres
campos— **se queda exactamente igual en esta tarea**. Lo cambia la tarea 3.

y añade, justo antes de `apply_rules`:

```c
/* Fill `props` from what the rules already read plus the role. */
static void collect_window_props(bspwm_wid_t win, rule_consequence_t *csq,
                                 bspwm_window_type_t type, bspwm_wid_t transient_for,
                                 window_props_t *props)
{
	snprintf(props->class_name, sizeof(props->class_name), "%s", csq->class_name);
	snprintf(props->instance_name, sizeof(props->instance_name), "%s", csq->instance_name);
	snprintf(props->name, sizeof(props->name), "%s", csq->name);
	props->role[0] = '\0';
	backend_get_window_role(win, props->role, sizeof(props->role));
	props->type = window_type_name(type);
	props->transient = (transient_for != BSPWM_WID_NONE) ? "on" : "off";
}
```

`_apply_window_type` y `_apply_transient` cambian de firma, así que actualiza también sus
definiciones y sus declaraciones en `src/rule.h`:

```c
void _apply_window_type(bspwm_window_type_t type, rule_consequence_t *csq);
void _apply_transient(bspwm_wid_t transient_for, rule_consequence_t *csq);
```

Dentro de `_apply_window_type`, quita la llamada a `backend_get_window_type` y usa el parámetro.
Dentro de `_apply_transient`, quita la llamada a `backend_get_transient_for` y usa el parámetro.
Comprueba con `grep -rn '_apply_window_type(\|_apply_transient(' src/` que no queda ningún otro
sitio que las llame con la firma vieja.

Si el compilador avisa de que `props` no se usa todavía, añade `(void) props;` al final de
`apply_rules` **solo en esta tarea**, con el comentario `/* Used by the rule loop in the next
commit. */`, y quítalo en la tarea 3.

- [ ] **Step 3: Ver que no cambia nada**

```bash
make 2>&1 | grep -iE "warning|error"
flock /tmp/bspwm1-make-test.lock make test > /tmp/bspwm1-rulematch-t2.log 2>&1
tail -n 3 /tmp/bspwm1-rulematch-t2.log
```

Expected: ningún aviso y ALL GREEN, con el mismo número de pruebas que antes de la tarea.

- [ ] **Step 4: Commit**

```bash
git add src/backend.h src/backend_x11.c src/window_ops.c src/rule.c src/rule.h
git commit -m "refactor: read the window role and gather the rule properties once" \
  -m "The type and the transient parent were read inside the functions that apply them; a rule that matches on them needs the values themselves. They are read once per window now, together with WM_WINDOW_ROLE, which bspwm did not read at all."
```

---

### Task 3: La regla guarda condiciones

**Files:**
- Modify: `src/types.h`, `src/rule.c`, `src/messages.c`, `src/tree.c`

**Interfaces:**
- Consumes: el módulo de la tarea 1 y `collect_window_props()` de la tarea 2.
- Produces: `rule_t` con `rule_cond_t conds[RULE_PROP_COUNT]` y `char cause[3 * MAXLEN]`, que la
  tarea 4 rellena y imprime.

En esta tarea la sintaxis **no cambia todavía**: `cmd_rule` sigue recibiendo el patrón antiguo,
pero lo guarda como condiciones. Las pruebas existentes tienen que seguir en verde.

- [ ] **Step 1: Cambiar la estructura**

En `src/types.h`, añade el include del módulo junto a los demás y sustituye los tres campos de
texto de `rule_t`:

```c
struct rule_t {
	rule_cond_t conds[RULE_PROP_COUNT];
	/* The conditions as they were written, for `rule -l` and `rule -r`. */
	char cause[3 * MAXLEN];
	char effect[MAXLEN];
	bool one_shot;
	rule_t *prev;
	rule_t *next;
};
```

- [ ] **Step 2: Adaptar `rule.c`**

- `make_rule`: `calloc` ya deja las condiciones a cero; quita las asignaciones de
  `class_name`, `instance_name` y `name`, y deja `r->cause[0] = r->effect[0] = '\0';`.
- `remove_rule`: antes de `free(r)`, libera las condiciones:

```c
	for (int i = 0; i < RULE_PROP_COUNT; i++) {
		rule_cond_free(&r->conds[i]);
	}
	free(r);
```

- `apply_rules`: sustituye la comparación de los tres campos por el módulo:

```c
	const char *values[RULE_PROP_COUNT] = {
		props.class_name, props.instance_name, props.name,
		props.type, props.role, props.transient,
	};

	rule_t *rule = rule_head;
	while (rule != NULL) {
		rule_t *next = rule->next;
		if (rule_conds_match(rule->conds, values)) {
			char effect[MAXLEN];
			snprintf(effect, sizeof(effect), "%s", rule->effect);
			parse_keys_values(effect, csq);
			if (rule->one_shot) {
				remove_rule(rule);
				break;
			}
		}
		rule = next;
	}
```

- `remove_rule_by_cause`: hoy compara los tres campos de texto. Cámbialo para que use el patrón
  guardado en cada condición:

```c
	    if ((streq(class_name, MATCH_ANY) || streq(rule_cond_pattern(&r->conds[RULE_PROP_CLASS]), class_name)) &&
	        (streq(instance_name, MATCH_ANY) || streq(rule_cond_pattern(&r->conds[RULE_PROP_INSTANCE]), instance_name)) &&
	        (streq(name, MATCH_ANY) || streq(rule_cond_pattern(&r->conds[RULE_PROP_NAME]), name))) {
		    remove_rule(r);
	    }
```

  Mantén el resto de la función igual, incluidas sus comprobaciones de longitud y los `free`.

- `list_rules`: imprime la causa guardada:

```c
void list_rules(FILE *rsp)
{
	for (rule_t *r = rule_head; r != NULL; r = r->next) {
		fprintf(rsp, "%s %c> %s\n", r->cause, r->one_shot?'-':'=', r->effect);
	}
}
```

- [ ] **Step 3: Adaptar `messages.c` (sin cambiar la sintaxis)**

En `cmd_rule`, donde hoy copia `class_name`, `instance_name` y `name` a la regla, compila cada
uno como condición exacta y guarda la causa:

```c
			char err[MAXLEN];
			const char *fields[3] = {class_name, instance_name, name};
			const rule_prop_t props[3] = {RULE_PROP_CLASS, RULE_PROP_INSTANCE, RULE_PROP_NAME};
			bool ok = true;
			for (int f = 0; f < 3 && ok; f++) {
				const char *value = (fields[f][0] == '\0') ? MATCH_ANY : fields[f];
				if (streq(value, MATCH_ANY)) {
					continue;
				}
				if (!rule_cond_compile(&rule->conds[props[f]], props[f], value, err, sizeof(err))) {
					fail(rsp, "rule: %s: %s\n", rule_prop_name(props[f]), err);
					ok = false;
				}
			}
			snprintf(rule->cause, sizeof(rule->cause), "%s:%s:%s",
			         class_name,
			         instance_name[0] == '\0' ? MATCH_ANY : instance_name,
			         name[0] == '\0' ? MATCH_ANY : name);
			free(class_name);
			free(instance_name);
			free(name);
			if (!ok) {
				remove_rule(rule);   /* frees the conditions compiled so far */
				return;
			}
```

Ojo: `remove_rule` sobre una regla que todavía no está en la lista tiene que ser seguro. Mira su
código: si no lo es, libera las condiciones y la regla a mano en ese camino.

- [ ] **Step 4: Adaptar `tree.c`**

En `node_ignores_tile_limits`, sustituye las tres comparaciones por el módulo. La función corre
antes de conocer el título, así que las reglas que dependen de algo distinto de la clase o la
instancia se saltan:

```c
	for (rule_t *r = rule_head; r != NULL; r = r->next) {
		/* The title, the type and the role are not known this early, so only
		 * rules that look at the class and the instance count. */
		if (r->conds[RULE_PROP_NAME].used || r->conds[RULE_PROP_TYPE].used ||
		    r->conds[RULE_PROP_ROLE].used || r->conds[RULE_PROP_TRANSIENT].used) {
			continue;
		}
		if (!rule_cond_matches(&r->conds[RULE_PROP_CLASS], class_name)) {
			continue;
		}
		if (!rule_cond_matches(&r->conds[RULE_PROP_INSTANCE], instance_name)) {
			continue;
		}
		if (effect_has(r->effect, "ignore_tile_limits", "on")) {
			return true;
		}
	}
```

- [ ] **Step 5: Ver que nada cambia**

```bash
make 2>&1 | grep -iE "warning|error"
flock /tmp/bspwm1-make-test.lock make test > /tmp/bspwm1-rulematch-t3.log 2>&1
tail -n 3 /tmp/bspwm1-rulematch-t3.log
```

Expected: ningún aviso y ALL GREEN. Las pruebas de reglas que ya existen usan la sintaxis
antigua, así que son la red de seguridad de esta tarea.

Comprueba además, en un Xvfb propio (display ≥ :230), que `bspc rule -l` sigue mostrando
`clase:instancia:nombre => efecto` para una regla dada de la forma antigua.

- [ ] **Step 6: Commit**

```bash
git add src/types.h src/rule.c src/messages.c src/tree.c
git commit -m "refactor: store rule patterns as compiled conditions" \
  -m "The three text fields become one condition per property, compared through the new module. The old pattern is turned into exact conditions, so the syntax and the behaviour do not change yet. The duplicate matcher in node_ignores_tile_limits now uses the module too."
```

---

### Task 4: La sintaxis nueva en `bspc rule -a`

**Files:**
- Modify: `src/messages.c`
- Create: pruebas en `tests/headless/rule_match.sh` (ya existe desde la tarea 1)

**Interfaces:**
- Consumes: `rule_prop_from_key()`, `rule_cond_compile()`, `rule_cond_print()` y `rule_t.cause`.

- [ ] **Step 1: Escribir las pruebas (rojo)**

Añade al final de `tests/headless/rule_match.sh`:

```sh
# The new form: conditions with a name.
assert_ok "add a rule with conditions" \
	$BSPC rule -a class=Pavucontrol/i state=floating
assert_ok "add a rule with a regular expression" \
	$BSPC rule -a 'class~=^(eog|feh)$' state=floating
assert_ok "add a rule with two conditions" \
	$BSPC rule -a class=Google-chrome instance~=^crx_ center=on
assert_ok "add a rule with a window type" $BSPC rule -a type=dialog center=on
assert_ok "add a rule with a role" $BSPC rule -a role=pop-up state=floating
assert_ok "add a rule for child windows" $BSPC rule -a transient=on state=floating

RULES=$($BSPC rule -l)
assert_eq "the conditions are listed as they were written" "1" \
	"$(printf '%s\n' "$RULES" | grep -c '^class=Google-chrome instance~=\^crx_ =>')"
assert_eq "the old form is still listed the old way" "1" \
	"$(printf '%s\n' "$RULES" | grep -c '^Chromium:\*:\* =>')"

# Everything that must be refused, with the rule never added.
BEFORE=$($BSPC rule -l | wc -l)
assert_fail "reject a broken regular expression" $BSPC rule -a 'class~=^(eog' state=floating
assert_fail "reject an unknown window type" $BSPC rule -a type=popup state=floating
assert_fail "reject an unknown key" $BSPC rule -a clas=kitty state=floating
assert_fail "reject a repeated condition" $BSPC rule -a class=a class=b state=floating
assert_fail "reject an unknown consequence" $BSPC rule -a class=kitty staet=floating
assert_eq "a refused rule is not added" "$BEFORE" "$($BSPC rule -l | wc -l)"

$BSPC rule -r class=Pavucontrol/i || true
$BSPC rule -r 'class~=^(eog|feh)$' || true
$BSPC rule -r class=Google-chrome || true
$BSPC rule -r type=dialog || true
$BSPC rule -r role=pop-up || true
$BSPC rule -r transient=on || true
```

Justo antes de ese bloque, añade la regla de la forma antigua que la prueba busca:

```sh
assert_ok "add a rule the old way" $BSPC rule -a Chromium state=floating
```

Ejecuta `flock /tmp/bspwm1-make-test.lock make test > /tmp/bspwm1-rulematch-t4-red.log 2>&1`.

Expected: fallan las altas con condiciones (`bspc` las toma como patrón antiguo, así que no da
error pero tampoco crea lo que la prueba espera), fallan las comprobaciones del listado y fallan
los rechazos, porque hoy una clave desconocida se ignora en silencio. Anota en el informe qué
falló exactamente.

- [ ] **Step 2: Distinguir las dos formas**

En `cmd_rule`, dentro de la rama `-a`, antes de tokenizar el patrón:

```c
			/* A first argument with an `=` means the new form: a list of
			 * `property=pattern` or `property~=pattern` conditions mixed
			 * with the consequences. */
			bool new_form = (strchr(args[0], '=') != NULL);
```

Si `new_form` es falso, se hace lo de la tarea 3, sin cambios.

Si es verdadero, no se tokeniza ningún patrón: se recorren todos los argumentos y cada uno se
clasifica. Añade también, junto a las demás funciones estáticas de `messages.c`:

```c
/* The keys a rule consequence accepts. */
static bool is_consequence_key(const char *key)
{
	static const char *keys[] = {
		"monitor", "desktop", "node", "split_dir", "split_ratio", "state", "layer",
		"honor_size_hints", "rectangle", "hidden", "sticky", "private", "locked",
		"marked", "center", "follow", "manage", "focus", "border",
		"ignore_tile_limits", NULL,
	};
	for (const char **k = keys; *k != NULL; k++) {
		if (streq(*k, key)) {
			return true;
		}
	}
	return false;
}
```

**Comprueba la lista contra `parse_key_value` (`src/rule.c`) antes de darla por buena:** tiene que
tener exactamente las claves que esa función entiende, ni una más ni una menos. `ignore_tile_limits`
no la trata `parse_key_value`, sino `effect_has` en `tree.c`; compruébalo con
`grep -rn 'ignore_tile_limits' src/` y quítala de la lista si no aparece en ninguna de las dos.

El bucle de la forma nueva:

```c
			size_t i = 0;
			bool ok = true;
			while (num > 0 && ok) {
				if (streq("-o", *args) || streq("--one-shot", *args)) {
					rule->one_shot = true;
					num--, args++;
					continue;
				}
				char *sep = strchr(*args, '=');
				if (sep == NULL) {
					fail(rsp, "rule: Not a key=value argument: '%s'.\n", *args);
					ok = false;
					break;
				}
				/* `~=` asks for a regular expression; `=` compares as written. */
				unsigned int flags = 0;
				size_t key_len = (size_t) (sep - *args);
				if (key_len > 0 && (*args)[key_len - 1] == '~') {
					flags |= RULE_COND_REGEX;
					key_len--;
				}
				char key[MAXLEN];
				if (key_len >= sizeof(key)) {
					fail(rsp, "rule: Key too long: '%s'.\n", *args);
					ok = false;
					break;
				}
				memcpy(key, *args, key_len);
				key[key_len] = '\0';

				/* A trailing `/i` on the value asks to ignore case. */
				char value[MAXLEN];
				if (strlen(sep + 1) >= sizeof(value)) {
					fail(rsp, "rule: Value too long: '%s'.\n", *args);
					ok = false;
					break;
				}
				snprintf(value, sizeof(value), "%s", sep + 1);
				size_t value_len = strlen(value);
				if (value_len >= 2 && streq(value + value_len - 2, "/i")) {
					flags |= RULE_COND_ICASE;
					value[value_len - 2] = '\0';
				}

				rule_prop_t prop;
				if (rule_prop_from_key(key, &prop)) {
					if (rule->conds[prop].used) {
						fail(rsp, "rule: Repeated condition: '%s'.\n", key);
						ok = false;
						break;
					}
					char err[MAXLEN];
					if (!rule_cond_compile(&rule->conds[prop], prop, value, flags, err, sizeof(err))) {
						fail(rsp, "rule: %s: %s\n", key, err);
						ok = false;
						break;
					}
					/* Keep the conditions, in order, for `rule -l`. */
					size_t used = strlen(rule->cause);
					snprintf(rule->cause + used, sizeof(rule->cause) - used,
					         "%s%s=%s", used > 0 ? " " : "", key, value);
				} else if (is_consequence_key(key)) {
					if (flags != 0) {
						fail(rsp, "rule: %s: an effect takes no pattern.\n", key);
						ok = false;
						break;
					}
					for (size_t j = 0; i < sizeof(rule->effect) - 1 && j < strlen(*args); i++, j++) {
						rule->effect[i] = (*args)[j];
					}
					if (num > 1 && i < sizeof(rule->effect)) {
						rule->effect[i++] = ' ';
					}
				} else {
					fail(rsp, "rule: Unknown key: '%s'.\n", key);
					ok = false;
					break;
				}
				num--, args++;
			}
			if (i >= sizeof(rule->effect)) {
				i = sizeof(rule->effect) - 1;
			}
			rule->effect[i] = '\0';
			if (!ok) {
				for (int c = 0; c < RULE_PROP_COUNT; c++) {
					rule_cond_free(&rule->conds[c]);
				}
				free(rule);
				return;
			}
			if (rule->cause[0] == '\0') {
				snprintf(rule->cause, sizeof(rule->cause), "%s", "*:*:*");
			}
			add_rule(rule);
```

**En la forma antigua también hay que validar las consecuencias**, para que
`bspc rule -a kitty staet=floating` falle. Aplica la misma comprobación `is_consequence_key` al
trocear el efecto, saltándote `-o`/`--one-shot`.

- [ ] **Step 3: Ver que pasa**

```bash
make 2>&1 | grep -iE "warning|error"
flock /tmp/bspwm1-make-test.lock make test > /tmp/bspwm1-rulematch-t4-green.log 2>&1
tail -n 3 /tmp/bspwm1-rulematch-t4-green.log
```

Expected: ningún aviso y ALL GREEN.

- [ ] **Step 4: Commits**

```bash
git add src/messages.c
git commit -m "feat: match rules on window properties with patterns" \
  -m "A rule can now be given as a list of property=pattern conditions: class, instance, name, type, role and transient, compared exactly, ignoring case with /i, or as a POSIX extended regular expression with a leading ~. The old CLASS:INSTANCE:NAME form keeps working. An unknown key, a repeated condition, an invalid type and a broken regular expression are refused when the rule is added, instead of being ignored."
git add tests/headless/rule_match.sh
git commit -m "test: check the rule conditions and what is refused"
```

---

### Task 5: Pruebas de extremo a extremo

**Files:**
- Modify: `tests/test_window.c`, `tests/headless/rule_match.sh`

**Interfaces:**
- Produces: `./test_window NAME CLASS [--role ROLE] [--type TYPE] [--transient]`, que usan las
  pruebas de esta tarea.

- [ ] **Step 1: Ampliar `test_window`**

Hoy `main` solo usa `argv[1]` y `argv[2]` para `WM_CLASS`. Añade tres opciones, después de esos
dos argumentos posicionales:

- `--role ROLE`: fija `WM_WINDOW_ROLE` con `xcb_change_property(dpy, XCB_PROP_MODE_REPLACE, win,
  role_atom, XCB_ATOM_STRING, 8, strlen(role), role)`, resolviendo el átomo con
  `xcb_intern_atom`.
- `--type TYPE`: acepta `dialog`, `utility`, `toolbar` y `normal`, y fija
  `_NET_WM_WINDOW_TYPE` con el átomo `_NET_WM_WINDOW_TYPE_<TIPO>`, en mayúsculas.
- `--transient`: fija `WM_TRANSIENT_FOR` apuntando a la ventana raíz, con
  `xcb_icccm_set_wm_transient_for(dpy, win, screen->root)`.

Las tres se fijan **antes** de mapear la ventana, porque bspwm las lee al gestionarla. Sigue el
estilo del fichero: C99, sin avisos con `-pedantic -Wall -Wextra`, y sin romper la forma de
llamarlo que usan las demás pruebas (`./test_window nombre Clase`).

- [ ] **Step 2: Escribir las pruebas (rojo)**

Añade al final de `tests/headless/rule_match.sh`, dentro de un bloque nuevo:

```sh
if [ "$BACKEND" = "x11" ] && [ -f ./test_window ]; then
	# Case: the rule says Pavucontrol, the window says pavucontrol.
	assert_ok "add the case insensitive rule" \
		$BSPC rule -a class=Pavucontrol/i state=floating
	./test_window rm-case pavucontrol >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "a rule with /i matches whatever the case" "floating" "$(rule_state "$W")"
	$BSPC node "$W" -c || true
	sleep 0.3
	$BSPC rule -r class=Pavucontrol/i || true

	# A regular expression on the instance: the web app, not the browser.
	assert_ok "add the web app rule" \
		$BSPC rule -a 'instance~=^crx_' state=floating
	./test_window rm-app crx_abcdef >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "the web app matches the regular expression" "floating" "$(rule_state "$W")"
	$BSPC node "$W" -c || true
	sleep 0.3
	./test_window rm-browser google-chrome >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "the plain browser window does not" "tiled" "$(rule_state "$W")"
	$BSPC node "$W" -c || true
	sleep 0.3
	$BSPC rule -r 'instance~=^crx_' || true

	# The role.
	assert_ok "add the role rule" $BSPC rule -a role=pop-up sticky=on
	./test_window rm-role RmRole --role pop-up >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "a window with that role is sticky" "true" "$(rule_flag "$W" sticky)"
	$BSPC node "$W" -c || true
	sleep 0.3
	$BSPC rule -r role=pop-up || true

	# A child window.
	assert_ok "add the child window rule" $BSPC rule -a transient=on sticky=on
	./test_window rm-child RmChild --transient >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "a child window is sticky" "true" "$(rule_flag "$W" sticky)"
	$BSPC node "$W" -c || true
	sleep 0.3
	./test_window rm-plain RmChild >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "a window with no parent is not" "false" "$(rule_flag "$W" sticky)"
	$BSPC node "$W" -c || true
	sleep 0.3
	$BSPC rule -r transient=on || true
else
	printf "%b\n" "  ${YELLOW}SKIP${NC}: rule conditions against real windows (needs X11 and test_window)"
fi
```

y, al principio del fichero, los dos ayudantes que usan:

```sh
rule_state() {
	$BSPC query -T -n "$1" 2>/dev/null | grep -o '"state":"[a-z_]*"' | head -1 | cut -d'"' -f4
}

rule_flag() {
	$BSPC query -T -n "$1" 2>/dev/null | grep -o "\"$2\":[a-z]*" | head -1 | cut -d: -f2
}
```

**Antes de fijar los valores esperados:** comprueba con una ventana de prueba qué devuelven de
verdad `rule_state` y `rule_flag` (por ejemplo, si el estado de una ventana en mosaico es `tiled`
y si la bandera `sticky` sale como `true`). Ajusta los esperados a lo que veas y explícalo en el
informe.

El caso de `type=dialog` no hace falta probarlo aquí: bspwm ya pone flotantes los diálogos por su
cuenta, así que la prueba no distinguiría. Pruébalo al revés, con una consecuencia que bspwm no
dé por su cuenta:

```sh
	assert_ok "add the dialog rule" $BSPC rule -a type=dialog sticky=on
	./test_window rm-dialog RmDialog --type dialog >/dev/null 2>&1 &
	sleep 0.5
	W=$($BSPC query -N -n focused)
	assert_eq "a dialog is sticky" "true" "$(rule_flag "$W" sticky)"
	$BSPC node "$W" -c || true
	sleep 0.3
	$BSPC rule -r type=dialog || true
```

Ejecuta `flock /tmp/bspwm1-make-test.lock make test > /tmp/bspwm1-rulematch-t5-red.log 2>&1` con
el `test_window` **sin ampliar** para ver el rojo de los casos de rol, tipo y ventana hija.

- [ ] **Step 3: Ver que pasa**

Con `test_window` ya ampliado:

```bash
make -C tests test_window
flock /tmp/bspwm1-make-test.lock make test > /tmp/bspwm1-rulematch-t5-green.log 2>&1
tail -n 3 /tmp/bspwm1-rulematch-t5-green.log
```

Expected: ALL GREEN.

- [ ] **Step 4: Una mutación, para comprobar que la prueba sirve**

Cambia temporalmente `rule_cond_matches` para que la comparación sin mayúsculas use `strcmp` en
vez de `strcasecmp`, recompila y ejecuta la suite: «a rule with /i matches whatever the case»
tiene que fallar. Deshaz el cambio y compruébalo con `git diff`.

- [ ] **Step 5: Commit**

```bash
git add tests/test_window.c tests/headless/rule_match.sh
git commit -m "test: check rule conditions against real windows"
```

---

### Task 6: Manual y autocompletado

**Files:**
- Modify: `doc/bspwm.1.asciidoc`, `doc/bspwm.1`, `contrib/zsh_completion`

- [ ] **Step 1: Manual**

En `doc/bspwm.1.asciidoc`, en la sección `rule`, sustituye la línea de la sintaxis de `-a` por
las dos formas y añade la tabla de propiedades y la de patrones. Texto exacto:

```asciidoc
*rule* -a (<class_name>|*)[:(<instance_name>|*)[:(<name>|*)]]|<condition>... [-o|--one-shot] <effect>...
```

y, debajo de la descripción actual de la orden:

```asciidoc
A rule is given either as the pattern above or as a list of conditions, each one
'<property>=<pattern>'. The properties are 'class', 'instance', 'name' (the title),
'type', 'role' (*WM_WINDOW_ROLE*) and 'transient' (*on* when the window is a child
of another one). A window matches the rule when every condition holds.

A pattern is compared as written, ignoring case when it ends in '/i', or as a POSIX
extended regular expression when it starts with '~' ('~^crx_/i' is both). The
properties 'type' and 'transient' take no regular expression: 'type' is one of
*normal*, *dock*, *desktop*, *notification*, *dialog*, *utility* or *toolbar*, and
'transient' is a boolean.

A rule is refused when a pattern is not a valid regular expression, a condition is
repeated, or a key is neither a property nor an effect.
```

Ejecuta `make doc VERCMD=false`. Si `a2x` no está instalado (`command -v a2x`), edita
`doc/bspwm.1` a mano con el mismo formato roff que la entrada vecina y dilo en el informe.
Comprueba que `man --warnings -E UTF-8 -l doc/bspwm.1 >/dev/null` no da avisos nuevos respecto a
`git show upstream/master:doc/bspwm.1`.

- [ ] **Step 2: Autocompletado de zsh**

En `contrib/zsh_completion`, en el bloque `(rule)` donde se completan las consecuencias
(`_values -w 'add rule' {border,focus,follow,manage,center}': :(on off)'…`), añade las claves de
condición para que se completen igual que las consecuencias: `class`, `instance`, `name`, `type`,
`role` y `transient`. Sigue el estilo del bloque, y para `type` y `transient` ofrece sus valores
(`(normal dock desktop notification dialog utility toolbar)` y `(on off)`).

Comprueba con `zsh -n contrib/zsh_completion` que el fichero sigue siendo válido. Los
autocompletados de bash y fish no listan claves de reglas, así que no se tocan; compruébalo con
`grep -n 'rule' contrib/bash_completion contrib/fish_completion`.

- [ ] **Step 3: Commit**

```bash
git add doc/bspwm.1.asciidoc doc/bspwm.1 contrib/zsh_completion
git commit -m "docs: document the rule conditions"
```

- [ ] **Step 4: Publicar la rama**

```bash
flock /tmp/bspwm1-make-test.lock make test > /tmp/bspwm1-rulematch-final.log 2>&1
tail -n 3 /tmp/bspwm1-rulematch-final.log
git push -u origin rule-match
```

Expected: ALL GREEN y la rama publicada.

---

### Task 7: Fundir, instalar y comprobar que nada se rompe [SESIÓN]

**Files:** ninguno del código; puede haber conflictos al fundir.

- [ ] **Step 1: Fundir en `local`**

```bash
cd /websites/personal/bspwm
git switch local
git merge --no-ff --no-edit rule-match
```

Conflictos probables: `tests/run_headless` (las líneas `. ./headless/…`), `tests/Makefile` (las
líneas `all:` y el `clean`) y quizá `src/rule.c`. En todos, se conservan las inserciones de los
dos lados.

- [ ] **Step 2: Comprobar**

```bash
make clean && make 2>&1 | grep -iE "warning|error"
flock /tmp/bspwm1-make-test.lock make test 2>&1 | tail -n 3
```

Expected: ningún aviso y ALL GREEN.

- [ ] **Step 3: Instalar y verificar con la configuración actual, sin tocarla**

```bash
git push origin local
~/.dotFiles/pkgbuilds/bspwm1-maflorezp-git/build.sh --noconfirm
bspc wm -r
sleep 15
bspc rule -l | wc -l
bspc rule -l | head -5
```

Expected: el paquete instalado con la versión nueva, y **95 reglas**, las mismas que ahora, con
el mismo aspecto: la sintaxis antigua tiene que seguir funcionando sin cambiar el fichero de
reglas. Comprueba también el perfil de subscribers (`all` ×2, `monitor` ×1, `node_focus` ×2 y
`report` ×1) y que polybar y sxhkd conservan `BSPWM_SOCKET`.

---

### Task 8: Migrar la configuración de Mauricio [SESIÓN]

**Files:**
- Modify: `~/.dotFiles/.config/bspwm/bspwm_rules.sh`,
  `~/.dotFiles/.config/bspwm/bspwm_external_rules.sh`

- [ ] **Step 1: Guardar la versión de hoy**

```bash
command cp -f ~/.dotFiles/.config/bspwm/bspwm_rules.sh /tmp/bspwm_rules.sh.antes
bspc rule -l > /tmp/reglas.antes
```

- [ ] **Step 2: Reescribir las reglas**

- Las 34 aplicaciones flotantes pasan a una sola regla, generada por el mismo bucle:

```bash
IFS='|'; bspc rule -a "class~=^(${FLOATING_APPS[*]})$/i" state=floating focus=on follow=on; unset IFS
```

- Las 13 PWA de Chrome pasan a una regla:

```bash
bspc rule -a class=Google-chrome instance~=^crx_ state=floating sticky=on focus=on follow=on center=on
```

  y solo las que necesiten un escritorio propio conservan su regla, ahora con condiciones:
  `bspc rule -a class=Google-chrome instance=crx_<ID> desktop=<escritorio> follow=on`.
- Los cuatro grupos de escritorio (`data`, `code`, `work`, `communication`) pasan a una regla cada
  uno, con la misma alternancia y `/i`.
- Las 20 reglas sueltas de `sticky=on` y `center=on` se funden en la regla de su grupo.
- Se corrigen `pavucontrol`/`Pavucontrol`: con `/i` deja de importar.

- [ ] **Step 3: Comparar antes y después**

```bash
bash ~/.dotFiles/.config/bspwm/bspwm_rules.sh
bspc rule -l > /tmp/reglas.despues
wc -l /tmp/reglas.antes /tmp/reglas.despues
```

Después, con Mauricio delante, abrir una de cada grupo (una flotante, una PWA de Chrome, una de
`code` y una de `communication`) y comprobar que caen donde deben. **Aviso:** `pavucontrol`
empezará a salir flotante, que antes no lo hacía.

- [ ] **Step 4: Adelgazar el script externo**

En `bspwm_external_rules.sh`, quitar lo que ahora hacen las reglas nativas:
- el `case` con globs de flotantes y centrados;
- la lista `ruled_classes`, si deja de hacer falta.

Ejecutar `bash -n` sobre el fichero y abrir unas cuantas ventanas para comprobar que la
asignación a receptáculos y preselecciones sigue igual.

- [ ] **Step 5: Cerrar**

El daemon de dotfiles comitea solo. Si hace falta cerrar antes, parar el servicio, comitear a
mano y volver a arrancarlo.

---
