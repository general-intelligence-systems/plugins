---
description: Insert a component into the design — into a named slot when the target declares one
argument-hint: "<type> [component] [slot]"
---

Use the cnstudio MCP tools (see the cnstudio skill for connection fallbacks
and the design model).

Arguments in `$ARGUMENTS`: the component `type` to insert (a name from
`getComponents.insertable` or a document component), optionally the design
`component` to insert into (defaults to the current one) and a `slot` name.

1. Call `getComponents` to validate the type (fuzzy-match what the user typed
   against `insertable` — e.g. "button" → `@/components/ui/button#Button`) and
   check the target's declared `slots`.
2. Call `getLayers` for the target component and choose the insertion point:
   the selected node when sensible, else the most specific container. When the
   parent is an instance declaring named slots, pass `slot` (the given one, or
   the only declared slot when unambiguous — ask if several and none given).
3. `insertNode { type, target, slot?, component? }`, then confirm with
   `getLayers` and report the new node's path.
