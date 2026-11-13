#include "ce_editline.h"
#include <editline/readline.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

static const char *const *g_items;
static int g_count;

static char *generator(const char *text, int state) {
    static int index;
    if (state == 0) index = 0;
    size_t len = strlen(text);
    while (index < g_count) {
        const char *item = g_items[index++];
        if (strncasecmp(item, text, len) == 0) return strdup(item);
    }
    return NULL;
}

static char **complete(const char *text, int start, int end) {
    (void)start; (void)end;
    rl_attempted_completion_over = 1;  /* never fall back to filename completion */
    return rl_completion_matches(text, generator);
}

char *ce_readline(const char *prompt, const char *const *items, int count) {
    g_items = items;
    g_count = count;
    rl_attempted_completion_function = complete;
    rl_completer_word_break_characters = (char *)"";  /* complete the whole line, spaces included */
    rl_completion_append_character = '\0';
    char *line = readline(prompt);
    if (line && *line) add_history(line);
    return line;
}
