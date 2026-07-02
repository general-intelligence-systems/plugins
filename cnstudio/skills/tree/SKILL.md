---
description: Show a designed component's layer tree (or list all components) from the running CnStudio
argument-hint: "[component]"
---

Use the cnstudio MCP tools (see the cnstudio skill for connection fallbacks).
Read-only — make no edits. If the studio isn't reachable, say so; do not fall
back to reading .studio/site.json.

If `$ARGUMENTS` is empty: call `getComponents` and present the document's
component names plus its `slots` map, one line each.

Otherwise call `getLayers {"component": "$ARGUMENTS"}` and render the tree
compactly, one node per line, indented:

- component instances by type (strip a registry id `@/path#Export` to `Export`)
- Slot markers as `◇ <name>`
- slotted children annotated `→ slot:<name>`
- text nodes quoted
- suffix every line with its `path` array (e.g. `[0,2]`) so it can be pasted
  straight into insertNode / moveNode / setProps.
