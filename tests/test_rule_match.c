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
	check_str("printing gives back the condition", "instance=~^crx_/i", printed);
	rule_cond_free(&cond);

	/* Recompiling over a `cond` that still holds a regex leaks it: free it
	 * first. The new condition replaces the old one entirely. */
	rule_cond_compile(&cond, RULE_PROP_INSTANCE, "~^crx_", err, sizeof(err));
	rule_cond_free(&cond);
	rule_cond_compile(&cond, RULE_PROP_INSTANCE, "~^tab_", err, sizeof(err));
	check("the old pattern no longer matches after recompiling", false,
	      rule_cond_matches(&cond, "crx_abc"));
	check("the new pattern matches after recompiling", true,
	      rule_cond_matches(&cond, "tab_abc"));
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
