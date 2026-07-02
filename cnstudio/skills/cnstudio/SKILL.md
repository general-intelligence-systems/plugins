---
name: cnstudio
description: Edit a CnStudio-designed UI (components, pages, slots, props) through the studio's MCP tools instead of hand-editing .studio/site.json. Use in any project with a .studio/ directory whenever asked to add/move/remove components, fill slots, change props, or create design pages.
---

# CnStudio design edits

A CnStudio project's UI is a **design document** (`.studio/site.json`)
rendered live on the studio canvas and codegen'd into real `.tsx` page modules
(the `pages` dir in the project's `studio.config.js` / vite `cnstudio()`
options). Do NOT hand-edit `.studio/site.json` or generated page files — drive
the studio's MCP tools. Their edits are live on the canvas, undoable,
autosaved, and page modules regenerate automatically.

## Connecting

This plugin registers the `cnstudio` MCP server at `http://127.0.0.1:4923/mcp`
— the port the CnStudio VS Code extension listens on (setting
`cnstudio.mcpPort`, default 4923). Prefer the registered `mcp__cnstudio__*`
tools.

If they fail to connect:

1. Read `.studio/mcp.json` — the extension writes the CURRENT URL there when a
   project opens (it falls back to an ephemeral port when 4923 is taken). If
   the URL differs from the registered server's, talk to it directly with the
   curl recipe below.
2. No `.studio/mcp.json` / connection refused ⇒ the studio isn't running. Ask
   the user to open the project in VS Code with the CnStudio extension. Only
   if they explicitly decline, fall back to careful `.studio/site.json` edits
   (the extension watches the file and reloads external changes when it
   starts) followed by the project's generate script (`npx cnstudio generate`).

### Curl fallback (non-default port)

MCP JSON-RPC over Streamable HTTP; initialize once and keep the session id:

```bash
URL=$(jq -r .url .studio/mcp.json)
SID=$(curl -si "$URL" -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"claude-code","version":"1.0"}}}' \
  | tr -d '\r' | awk -F': ' 'tolower($1)=="mcp-session-id"{print $2}')
curl -s "$URL" -H "mcp-session-id: $SID" -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' > /dev/null
mcp() { curl -sN "$URL" -H "mcp-session-id: $SID" -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"$1\",\"arguments\":$2}}" \
  | sed -n 's/^data: //p' | jq -r '.result.content[0].text'; }
```

## The design model

- A **node** is `{ type, props, children }`. `type` names either a design
  component (bare name, may be path-like: `page/calendar`) or a registered
  code component (registry id: `@/components/ui/button#Button`).
- **Prop values are JS expression source strings**: `"'ghost'"` is the literal
  string ghost, `"$props.title"` / `"$ctx.menu"` are bindings, plain `42` /
  `true` are literals. Event props (`onX`) follow the same rule — the
  expression must evaluate to a function: `"$ctx.save"` binds the handler
  itself; inline logic is an arrow, `"(e) => $ctx.setId(e.target.value)"`.
- **Slots**: a component declares where instance children render with Slot
  markers — `{ "type": "Slot", "props": { "name": "main" } }`. Every slot is
  NAMED. An instance's children route to a slot via the reserved `slot` prop.
  `slot` and a marker's `name` are RAW literal strings (`"main"`, NOT
  `"'main'"`) — the one exception to the expression rule.
- Slot **forwarding**: a marker that is itself a fill
  (`{ name: "outer", slot: "inner" }`) declares one slot and routes it onward.

## Tools

Discover current schemas via the tool list — summary:

- `getComponents {}` — document components, `insertable` code components, and
  `slots`: the named slots each design component declares.
- `openComponent { name }` / `createComponent { name }` / `removeComponent { name }`
- `getLayers { component? }` — node tree with paths; markers carry `name`,
  fills carry `slot`, instances list their `slots`.
- `insertNode { type, target?, slot?, component? }` — pass `slot` to route the
  child into a named slot of the parent instance.
- `insertSlot { name?, target?, component? }` — auto-names `slot-N` when
  `name` is omitted; names are unique per component.
- `moveNode { from, parent, index?, slot? }` / `removeNode { path }`
- `getProps { path? }` / `setProps { path, props }` (`null` removes a prop)
- `getRegistries {}` / `addComponent { item }` — install shadcn registry items.
- `openInBrowser { component? }` — the live rendered page.

## Conventions

Check the project's own CLAUDE.md / skills for its conventions (page naming,
shell composition, routing wiring for new pages). Verify edits with
`getLayers` and, for pages, by fetching the generated module through the dev
server.

## Component architecture is the user's decision

Do NOT create new components, files, or splits — design-document components
or code components — unless the user explicitly asks for them. "Separation
of concerns" is not a license to restructure: where something lives, whether
it is split out, and what it is called are the user's calls, not yours.

If what the user specified cannot work as specified (a rendering blocker, a
framework limitation), STOP and report why — with options if useful — and
let the user choose. Never restructure their architecture to work around a
blocker. When placement or naming of something new is unspecified, ask, or
take the most literal interpretation of the user's words.
