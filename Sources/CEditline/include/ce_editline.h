#ifndef CE_EDITLINE_H
#define CE_EDITLINE_H

/// Reads one line with arrow-key editing, history and Tab completion (via libedit).
/// `items` are the completion candidates (case-insensitive prefix match on the whole line).
/// Returns a malloc'd string the caller must free(), or NULL on end of input.
char *ce_readline(const char *prompt, const char *const *items, int count);

#endif
