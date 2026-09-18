// .pragma library
// YOUR emojis/symbols. This file is yours: add, remove, reorder freely.
// It loads FIRST (top priority) in the emoji menu (`.`), before everything
// generated at runtime by scripts/emoji-dump.py (library `emoji` +
// stdlib `unicodedata`, see EmojiService.qml).
// Duplicates by `ch` are skipped downstream, so anything here wins.
//
// Shape per entry (all strings):
//   { ch: "→", name: "rightwards arrow", kw: "arrow right", group: "symbols" }
//   ch    = the character to copy (emoji or unicode symbol)
//   name  = short ENGLISH name shown next to the char (keep it English:
//           the full catalog is English, mixing languages breaks search)
//   kw    = space-separated ENGLISH keywords for FuzzySearch
//   group = category tag, also searchable (broad buckets, keep them:
//           "caras" (faces), "gente" (gestures/hearts), "cosas" (objects,
//           food, tech, nature, travel...), "simbolos" (symbols/arrows))
//
// Tips:
// - Keep it short: this list shows first when the query is empty.
// - Symbols you type a lot (→ ← ⇒ ≠ ✓ …) belong here.
// - After editing, just reopen the launcher. No regen, no rebuild.

.pragma library

function getEmojis() {
    return [
        // Examples (uncomment / edit / delete). Groups are the broad
        // buckets (caras/gente/cosas/simbolos); old ids still work as
        // aliases (see EmojiService.normGroup).
        // { ch: "⇒", name: "rightwards double arrow", kw: "arrow double imply", group: "simbolos" },
        // { ch: "¯\\_(ツ)_/¯", name: "shrug", kw: "shrug shruggy idk", group: "caras" },
    ];
}
