# kora_vehiclekeys agent guide

`kora_vehiclekeys` is a Kora FiveM resource for server-authoritative vehicle keys, locks, ignition checks and lockpick/hotwiring, and it `provide`s `qb-vehiclekeys`. Layout: `fxmanifest.lua`, `config.lua` (shared config), `server/main.lua` (access, callbacks, stock events, commands), `client/main.lua` (lock state, ignition monitor, lockpick flow, keybinds, bike guard), `client/compat.lua` and `client/stock.lua` (qb-vehiclekeys client surface), `client/feedback.lua` (lock feedback), `test/smoke/` (offline Lua tests) and `tests/` (kora_qa feature files). It has no database tables, locales or NUI.

## Documentation

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first for an overview of features, configuration, commands, exports and events.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.
