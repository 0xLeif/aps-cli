---
change: CHG-0022-tty-aware-output-under-the-git-porcelain-rule-issue-33
artifact: design
---

# Design

- New `Sources/aps/TTY.swift`: isatty checks, `colorEnabled` (TTY and no
  NO_COLOR), `Style` (bold/red/green, identity when disabled), and a
  column-aligning `table(header:rows:)`.
- `CLIOutput.encodeJSON` and `JSONCoding.encodeAuto`: sortedKeys plus
  withoutEscapingSlashes, inserting prettyPrinted only on TTY. All `--json`
  call sites and `dump` use them (dump keeps the injected dependency).
- `keys`: quiet -> names only; json -> payload; TTY -> aligned table;
  else byte-stable TSV (unchanged).
- `watch`: effective jsonl = `--jsonl || --json`.
- Error paths are untouched; the error contract PR (#50) owns fail styling
  when it lands.
