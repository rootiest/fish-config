#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Wrap code-shaped tokens in inline code spans for the Starlight site.

Section 5 is generated from the `functions/*.fish` comment headers, which
are read as plain text by `config-help`, by `funcsave`, and by anyone
opening the source file. Backticks there would be noise, so the headers
are authored without them -- and the site inherited that, rendering
`-a/--all` and `__fish_config_op_aliases` as ordinary prose.

This module closes that gap at render time: it walks the markdown a page
is about to be written as, finds the tokens whose shape only ever means
"code" (flags, `$vars`, snake_case identifiers, paths, key chords, known
command names) and wraps each one in a code span. The SSOT is never
touched, so the man page and `config-help` keep the plain-text form.

Everything here is conservative by construction: leaving a token alone is
always safe and wrapping the wrong one is not, so every rule bails out the
moment it is unsure. The regions that must never be rewritten -- fenced
blocks, indented code blocks, existing code spans, link targets, URLs, JSX
attributes, `<FileTree>` bodies, headings -- are recognised first and
passed through.
"""

import functools
import re
from pathlib import Path

FENCE_RE = re.compile(r"^\s*(```|~~~)")

# ---------------------------------------------------------------------------
# Vocabulary
# ---------------------------------------------------------------------------

# Commands a reader expects to see typeset as code. This is the *wide* list:
# it decides that a table column holds command lines (see _command_columns),
# where position already proves the name is a command. Wrapping a bare
# mention in running prose is gated on the strict tier below.
STANDARD_COMMANDS = frozenset(
    """
    apk apt awk basename bash bat bg bind brew builtin cargo cat cd chmod
    chown chsh cmp column cp curl cut date dd delta df diff dig dirname dnf
    docker dpkg du echo emacs emerge env eza exec exit export fastfetch fd
    fdisk fg fgrep file find fisher flatpak fzf gh git grep gzip head help
    hexdump host hostname id ifconfig install ip jq jobs journalctl kill
    killall kitten kitty last less ln locale ls lsblk lsd lsof make man
    micro mkdir more mount mpv mv nano nc neofetch neovim netstat nix nl
    nohup npm nproc nvim od open openssl pacman paru paste pgrep ping pip
    pip3 pkill pr printf ps pwd python python3 readlink realpath rg rm rmdir
    rpm rsync scp sed seq sh shutdown sleep snap sort source ssh stat
    strings su sudo sync systemctl tac tail tar tee test time tldr tmux
    touch tr trash tree type udisksctl umount uname uniq unzip uv vdir vi
    vim vlc wait wc wezterm wget which who whoami wl-copy wl-paste xargs
    xbps-install xclip xdg-open xsel yay yum yt-dlp zellij zip zoxide zsh
    zypper
    abbr alias and argparse begin block break case command complete contains
    continue count else emit end eval false for function funcsave functions
    history if math not or random read return set set_color status string
    switch true while
    """.split()
)

# Names that also read as ordinary English (or as this manual's own prose)
# often enough that a bare mention is not evidence of a command. They still
# take part in command-line and list detection, where position disambiguates
# -- they just never get wrapped on their own.
AMBIGUOUS_COMMANDS = frozenset(
    """
    abbr alias all and at basename bat begin bg bind block branch break case
    cat cd cheat cleanup clone column command complete contains continue copy
    count cut date dd df dir dirname do docker du duf dust echo edit else emit
    end env eval exec exit export false fc fg file find fish for free function
    functions git go head help hist history host hostname id if in install ip
    jobs join key kill last less link list ln lock locale log logs look ls make
    man math micro more mount mv next no not note od open or ov p page paste
    pkg poke ports pr ps pwd random read real replay return rm run screen sed
    search seq set sh show sleep sort source spark split stat status string
    strings su switch sync tab tac tail tar tee test time top touch tr trash
    tree true type uniq upgrade view vi wait watch wc which while who write
    yes zip
    builtin fast function vdir
    """.split()
)

# Extensions that make a bare `name.ext` token unambiguously a filename.
PATH_EXTENSIONS = (
    "fish md mdx json jsonc toml yml yaml py sh bash zsh lua conf cfg ini "
    "txt log list service socket desktop css scss ts js astro nix rasi 1"
).split()

# English function words. A candidate command line containing one is prose.
STOPWORDS = frozenset(
    """
    a an the this that these those it its is are was were be been being am
    to of in into on at by for from with without within about across after
    before during over under again then than so such as and or but nor if
    when while where which who whom whose why how all any both each few more
    most other some only own same too very can will just should now via per
    also either neither every no not
    """.split()
)

_CATALOG_ARRAY_RE = re.compile(
    r"set\s+-g\s+_fdc_(?:bins|cargo|pm)\s+((?:[^\n]*\\\n)*[^\n]*)"
)


def dependency_names(repo: Path) -> set[str]:
    """Every tool name in the `fish-deps` catalog (`_fdc_*` arrays).

    `functions/_fish_deps_catalog.fish` is this repo's dependency database;
    reading it here means a tool added there starts rendering as code with
    no second list to keep in sync.
    """
    path = repo / "functions" / "_fish_deps_catalog.fish"
    if not path.exists():
        return set()
    names: set[str] = set()
    for m in _CATALOG_ARRAY_RE.finditer(path.read_text(encoding="utf-8")):
        for token in m.group(1).replace("\\\n", " ").split():
            token = token.strip("\"'")
            if token and re.fullmatch(r"[\w.@+-]+", token):
                names.add(token)
    return names


def function_names(repo: Path) -> set[str]:
    """Public function names, from the `functions/` directory listing.

    Underscore-prefixed internals are skipped only because the snake_case
    rule already covers them, and covers them everywhere -- including the
    ones that have no file of their own.
    """
    directory = repo / "functions"
    if not directory.is_dir():
        return set()
    return {p.stem for p in directory.glob("*.fish") if not p.stem.startswith("_")}


class Vocabulary:
    """The command names the rules recognise, in two tiers.

    `full` is every name we know of, used where position already proves a
    token is a command (a command-line table cell, an arrow chain, a
    comma-separated run). `strict` is the subset safe to wrap on sight in
    running prose: `zoxide` yes, `find` no.
    """

    __slots__ = ("full", "strict")

    def __init__(self, names: set[str]):
        # `and`, `or`, `not`, `if` … are fish builtins, but as vocabulary
        # entries they turn every conjunction into a command name and break
        # list and command-line detection. They are never worth wrapping.
        self.full = frozenset(names) - STOPWORDS
        self.strict = frozenset(
            n
            for n in names
            if n not in AMBIGUOUS_COMMANDS
            and (len(n) >= 3 or any(c.isdigit() for c in n))
        )

    def __eq__(self, other):
        return (
            isinstance(other, Vocabulary)
            and self.full == other.full
            and self.strict == other.strict
        )

    def __hash__(self):
        return hash((self.full, self.strict))


def vocabulary(repo: Path) -> Vocabulary:
    """Build the command vocabulary from the repo plus the standard list."""
    return Vocabulary(
        set(STANDARD_COMMANDS) | dependency_names(repo) | function_names(repo)
    )


EMPTY_VOCABULARY = Vocabulary(set())


# ---------------------------------------------------------------------------
# Token grammar
# ---------------------------------------------------------------------------

# A token may not start inside a word, a path, a code span, a history
# expansion, or a hyphenated compound: `` `zoxide` ``-backed must not see
# `-backed` as a flag, `and/or` must not see `/or` as a path, and `!-N` must
# not see `-N` as one either.
BEFORE = r"(?<![\w`$/\\~.=+!-])"
# Ruling out a trailing `/` keeps a partially-recognised slash run
# (`grep/cp/mv/wget`, where only `grep` is in the vocabulary) from being
# wrapped one limb at a time.
AFTER = r"(?![\w`/])"

_SEG = r"[\w.@+-]+"
# The last segment of a path may not end in `.`, so a sentence-final full
# stop stays outside the span. A segment that is nothing but dots (`..`,
# `...`) is the exception: there the dots are the segment.
_LAST = r"(?:[\w.@+-]*[\w@+-]|\.+)"
_EXT = "|".join(PATH_EXTENSIONS)

# Key chords: `Ctrl-R`, `Ctrl+Alt+F`. Both separators appear in the manual.
_MODIFIER = r"(?:Ctrl|Alt|Shift|Super|Meta|Cmd|Opt)"
_KEY = (
    r"(?:F\d{1,2}|Tab|Enter|Return|Space|Esc|Escape|Backspace|Delete|Insert"
    r"|Home|End|Up|Down|Left|Right|PgUp|PgDn|[A-Za-z0-9])"
)
KEYBIND = rf"{_MODIFIER}(?:[+-]{_MODIFIER})*[+-]{_KEY}"

# `$EDITOR`, `${var}`, `$XDG_CONFIG_HOME/aichat/roles/cli.md`.
VAR = rf"\$\{{?[A-Za-z_]\w*\}}?(?:(?:/{_SEG})*/{_LAST})?"

PATH = (
    rf"(?:~|\.{{1,2}})/(?:{_SEG}/)*(?:{_LAST})?"  # ~/… ./… ../…
    rf"|/(?:{_SEG}/)+(?:{_LAST})?"  # /etc/sudoers.d/nofail-toggle
    rf"|(?:{_SEG}/)+[\w@+-][\w.@+-]*\.(?:{_EXT})"  # conf.d/abbr.fish
    rf"|[\w@+-][\w.@+-]*\.(?:{_EXT})"  # config.fish
    rf"|(?:{_SEG}\.)+{_SEG}/"  # conf.d/
)

# `-a`, `--dry-run`, `--color=auto`. A bare `--` (this manual's ASCII em
# dash) never matches: a letter has to follow. A single-hyphen flag is
# capped at five characters and may not contain a hyphen, so a hyphenated
# compound continued across a conjunction ("filesystem-inspection and
# -modification") is not mistaken for one.
FLAG = r"--[A-Za-z][\w-]*(?:=[\w.,:/@+-]+)?|-[A-Za-z][A-Za-z0-9]{0,4}(?:=[\w.,:/@+-]+)?"

# `XDG_CONFIG_HOME`, `NO_TMUX=1`. An underscore is required, so ordinary
# acronyms (`URL`, `AGPL`, `TCP`) are never touched.
ENVVAR = r"[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+(?:=[\w.,:/@+-]+)?"

# snake_case: `__fish_config_op_aliases`, `_fdc_bins`, `fish_greeting`,
# `prompt_pwd`, `expand_bang_*`. An internal underscore is required, which
# is also what keeps `_emphasised_` markdown out of the match.
IDENT = r"_{0,2}[a-z][a-z0-9]*(?:_(?:[a-z0-9]+|\*))+"

# Regions that are already code, or are markup rather than prose. `url`
# also covers `git@host:owner/repo.git` and `ssh://…`, whose scheme would
# otherwise be read as a bare command name.
PROTECTED = (
    r"(?P<code>``+.+?``+|`[^`\n]*`)"
    r"|(?P<link>\[[^\]\n]*\]\([^)\n]*\))"
    r"|(?P<url>[A-Za-z][\w+.-]*://\S+|[\w.-]+@[\w.-]+(?::\S+)?)"
    r"|(?P<tag></?[A-Za-z][^>\n]*?/?>)"
)

ARROW = r"(?:->|→|=>)"
# Shortest comma run that reads as a list of tools rather than as prose.
MIN_RUN_NAMES = 3
# `, and` must be tried before a bare `,` so the conjunction is a separator
# and not an item.
RUN_SPLIT = r",?\s+(?:and|or)\s+|,\s*"
RUN_SPLIT_RE = re.compile(RUN_SPLIT)
# A command name inside a chain is followed by `->`, so the usual "no
# trailing hyphen" guard has to make room for exactly that.
_CMD_END = r"(?!\w)(?!-(?!>))"


def _alternation(names) -> str:
    """Regex alternation over names, longest first so `rg` can't beat `rga`."""
    if not names:
        return r"(?!)"
    return "|".join(re.escape(n) for n in sorted(names, key=lambda s: (-len(s), s)))


def _atom(vocab: Vocabulary) -> str:
    cmd = rf"(?:{_alternation(vocab.strict)})(?![\w-])"
    return rf"(?:{KEYBIND}|{VAR}|{PATH}|{FLAG}|{ENVVAR}|{IDENT}|{cmd})"


@functools.lru_cache(maxsize=4)
def _scanner(vocab: Vocabulary) -> re.Pattern:
    """The single pass over a line: protected regions plus wrappable tokens."""
    full = rf"(?:{_alternation(vocab.full)})"
    chain_link = rf"(?:{full}{_CMD_END}|{VAR})"
    name = rf"{full}(?![\w-])"
    return re.compile(
        PROTECTED
        # `ls->eza, cat->bat`: a shadow chain. Position makes even an
        # ambiguous name unmistakably a command here.
        + rf"|(?P<chain>{BEFORE}{chain_link}(?:\s*{ARROW}\s*{chain_link})+{AFTER})"
        # `cargo, starship, uv, zoxide`: a run of nothing but tool names.
        + rf"|(?P<run>{BEFORE}{name}(?:,\s*{name})+"
        + rf"(?:,?\s+(?:and|or)\s+{name})?{AFTER})"
        # `-a/--all`: slash-joined atoms, each wrapped on its own.
        + rf"|(?P<group>{BEFORE}{_atom(vocab)}(?:/{_atom(vocab)})*{AFTER})"
    )


@functools.lru_cache(maxsize=4)
def _atom_re(vocab: Vocabulary) -> re.Pattern:
    return re.compile(_atom(vocab))


# ---------------------------------------------------------------------------
# Table cells that are whole command lines
# ---------------------------------------------------------------------------

# The abbreviation tables' second column is an expansion, not a sentence:
# `sudo -s`, `cd ../..`, `journalctl -p 3 -xb`. Wrapping only the flag would
# leave a bare `sudo` in front of a code span; the cell wants to be one span.
#
# Whether a column holds command lines is decided for the column as a whole
# -- one cell is far too little evidence, as `zoxide frecency-based
# navigation` (prose, in a column of prose) and `docker context ls` (a
# command, in a column of commands) open identically.
CELL_TOKEN_RE = re.compile(r"^[\w$~./=:;@+*?%'\"-]+$")
CELL_NAME_RE = re.compile(r"^[a-z][\w.+-]*$")
CELL_OPERATORS = frozenset((r"\|", "|", "&&", "||", ">", ">>", "<", ";"))
MAX_CELL_TOKENS = 8
COMMAND_COLUMN_RATIO = 0.7
MIN_COMMAND_COLUMN_ROWS = 3


def _cell_tokens(cell: str) -> list[str] | None:
    """Tokenise a cell that could be a command line, or None if it can't be."""
    text = cell.strip()
    if not text or any(c in text for c in "`<([)]"):
        return None
    tokens = text.split()
    if not (1 <= len(tokens) <= MAX_CELL_TOKENS):
        return None
    for token in tokens:
        if token in CELL_OPERATORS:
            continue
        if not CELL_TOKEN_RE.match(token):
            return None
        if token[:1].isupper() or token.lower() in STOPWORDS:
            return None
    return tokens


def _is_command_cell(cell: str, vocab: Vocabulary) -> bool:
    """True when a cell in a command column really is one command line."""
    tokens = _cell_tokens(cell)
    if tokens is None:
        return False
    return tokens[0] in vocab.full or bool(CELL_NAME_RE.match(tokens[0]))


def _opens_with_command(cell: str, vocab: Vocabulary) -> bool:
    """The per-cell evidence the column vote is counted from."""
    tokens = _cell_tokens(cell)
    return tokens is not None and tokens[0] in vocab.full


# ---------------------------------------------------------------------------
# Line classification
# ---------------------------------------------------------------------------

HEADING_RE = re.compile(r"^\s{0,3}#{1,6}\s")
TABLE_ROW_RE = re.compile(r"^\s*\|.*\|\s*$")
TABLE_RULE_RE = re.compile(r"^\s*\|[\s:|-]+\|\s*$")
IMPORT_RE = re.compile(r"^\s*import\s")
FILE_TREE_OPEN = "<FileTree"
FILE_TREE_CLOSE = "</FileTree>"
CELL_SPLIT_RE = re.compile(r"(?<!\\)\|")

# A four-space indent is this manual's code block. The site never sees one
# -- prettify() has already turned it into a fence by the time this module
# runs -- but build_concat() keeps the indented form, because that is what
# pandoc and `config-help` want, and its contents are code that must not be
# rewritten: the table of contents alone would otherwise have `ov`, `bat`,
# `less` and `cat` wrapped inside a code block.
INDENTED_CODE = "    "


def _skip_line(line: str) -> bool:
    """True for a line that must be passed through untouched.

    Headings are excluded because Starlight derives anchors -- and this
    pipeline derives `LinkCard` hrefs -- from their text. A line opening
    with `<` is component markup, whose attributes are JSX, not markdown.
    """
    stripped = line.strip()
    return bool(
        not stripped
        or HEADING_RE.match(line)
        or IMPORT_RE.match(line)
        or stripped.startswith("<")
        or TABLE_RULE_RE.match(line)
    )


def _row_cells(line: str) -> list[str]:
    return CELL_SPLIT_RE.split(line)


def _command_columns(rows: list[str], vocab: Vocabulary) -> set[int]:
    """Which column indices of one table hold command lines rather than prose."""
    votes: dict[int, list[int]] = {}
    for line in rows:
        if TABLE_RULE_RE.match(line):
            continue
        for index, cell in enumerate(_row_cells(line)):
            if not cell.strip() or "`" in cell:
                continue
            votes.setdefault(index, []).append(_opens_with_command(cell, vocab))
    return {
        index
        for index, seen in votes.items()
        if len(seen) >= MIN_COMMAND_COLUMN_ROWS
        and sum(seen) / len(seen) >= COMMAND_COLUMN_RATIO
    }


# ---------------------------------------------------------------------------
# The pass
# ---------------------------------------------------------------------------

# Spans this pass creates are marked, not back-ticked, until the very end:
# adjacent ones are merged (`eza` `-l` `-a` -> `eza -l -a`), and only spans
# this pass created may take part in that.
MARK = "\x01"
MERGE_RE = re.compile(rf"{MARK} {MARK}")


def _mark(text: str) -> str:
    return f"{MARK}{text}{MARK}"


def _wrap_atoms(text: str, atom_re: re.Pattern) -> str:
    """Mark each atom of a slash-joined group, keeping the separators.

    Rescanning the group rather than capturing during the first match keeps
    the grammar readable; the round-trip check makes that shortcut safe --
    if the rescan disagrees with the original match, nothing is changed.
    """
    wrapped = atom_re.sub(lambda m: _mark(m.group(0)), text)
    if wrapped.replace(MARK, "") != text:
        return text
    return wrapped


def _wrap_split(text: str, separator: str) -> str:
    """Mark each item of a separated run, keeping the separators."""
    parts = re.split(rf"({separator})", text)
    return "".join(p if i % 2 else _mark(p) for i, p in enumerate(parts))


def _transform(text: str, scanner: re.Pattern, atom_re: re.Pattern, vocab: Vocabulary) -> str:
    def repl(m: re.Match) -> str:
        group = m.lastgroup
        if group == "chain":
            return _wrap_split(m.group(0), rf"\s*{ARROW}\s*")
        if group == "run":
            # A long run anchored by at least one unambiguous tool name is
            # a list of commands; two names, one of them a word like
            # `function`, is a sentence.
            names = RUN_SPLIT_RE.split(m.group(0))
            if len(names) < MIN_RUN_NAMES or not any(
                n in vocab.strict for n in names
            ):
                # Not a list after all -- hand the text back to the
                # ordinary token rules rather than swallowing it.
                return _wrap_atoms(m.group(0), atom_re)
            return _wrap_split(m.group(0), RUN_SPLIT)
        if group == "group":
            return _wrap_atoms(m.group(0), atom_re)
        return m.group(0)

    return scanner.sub(repl, text)


def _transform_line(
    line: str,
    scanner: re.Pattern,
    atom_re: re.Pattern,
    vocab: Vocabulary,
    command_columns: set[int],
) -> str:
    if not command_columns:
        return _transform(line, scanner, atom_re, vocab)

    out = []
    for index, cell in enumerate(_row_cells(line)):
        if index in command_columns and _is_command_cell(cell, vocab):
            body = cell.strip()
            lead = cell[: len(cell) - len(cell.lstrip())]
            trail = cell[len(cell.rstrip()) :]
            out.append(f"{lead}{_mark(body)}{trail}")
        else:
            out.append(_transform(cell, scanner, atom_re, vocab))
    return "|".join(out)


def _finish(line: str) -> str:
    """Merge abutting new spans, then turn the marks into backticks."""
    return MERGE_RE.sub(" ", line).replace(MARK, "`")


def add_code_spans(text: str, vocab: Vocabulary = EMPTY_VOCABULARY) -> str:
    """Wrap code-shaped tokens in `text` in inline code spans.

    `text` is a rendered page body (no frontmatter). Fenced blocks,
    indented code blocks, `<FileTree>` bodies, headings, component markup,
    existing code spans, link targets and URLs are left exactly as they
    are.
    """
    scanner = _scanner(vocab)
    atom_re = _atom_re(vocab)

    lines = text.split("\n")
    eligible = [False] * len(lines)
    in_fence = False
    in_tree = False
    for i, line in enumerate(lines):
        if FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if FILE_TREE_OPEN in line:
            in_tree = True
        if in_tree:
            if FILE_TREE_CLOSE in line:
                in_tree = False
            continue
        if line.startswith(INDENTED_CODE):
            continue
        eligible[i] = not _skip_line(line)

    # Command columns are a property of a whole table, so the contiguous
    # runs of table rows are resolved before any line is rewritten.
    columns: list[set[int]] = [set() for _ in lines]
    start = None
    for i, line in enumerate(lines + [""]):
        is_row = i < len(lines) and eligible[i] and TABLE_ROW_RE.match(line)
        if is_row and start is None:
            start = i
        elif not is_row and start is not None:
            found = _command_columns(lines[start:i], vocab)
            for j in range(start, i):
                columns[j] = found
            start = None

    return "\n".join(
        _finish(_transform_line(line, scanner, atom_re, vocab, columns[i]))
        if eligible[i]
        else line
        for i, line in enumerate(lines)
    )
