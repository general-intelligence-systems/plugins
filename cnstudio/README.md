# cnstudio-plugin

Claude Code plugin for [CnStudio](https://github.com/cnstudio-io/cnstudio):
lets Claude drive a studio-designed UI through the extension's MCP tools
instead of hand-editing `.studio/site.json`.

## What's inside

- **MCP server connection** (`.mcp.json`) — `cnstudio` over Streamable HTTP at
  `http://127.0.0.1:4923/mcp`, the port the CnStudio VS Code extension serves
  (setting `cnstudio.mcpPort`). Tools: getComponents, getLayers, insertNode,
  insertSlot, moveNode, removeNode, get/setProps, registries, openInBrowser.
- **`cnstudio` skill** — teaches the design model (nodes, prop expressions,
  named slots + routing/forwarding), endpoint discovery via `.studio/mcp.json`
  when the port differs, and the ground rules (never hand-edit site.json or
  generated files).
- **Slash commands** — `/studio:tree [component]`,
  `/studio:insert <type> [component] [slot]`, `/studio:open [component]`.

## Requirements

- The CnStudio VS Code extension running with the project open (it serves the
  MCP endpoint and writes `.studio/mcp.json`).
- The project uses the cnstudio Vite plugin (a `.studio/` directory exists).

## Install

```bash
claude plugin marketplace add cnstudio-io/plugins
claude plugin install cnstudio@cnstudio-io
```

For local development, add the checkout as the marketplace instead:

```bash
claude plugin marketplace add ~/src/cnstudio-plugin
```

## Layout

```
.claude-plugin/plugin.json        # manifest
.claude-plugin/marketplace.json   # lets this repo act as a marketplace
.mcp.json                         # the cnstudio MCP server
skills/cnstudio/SKILL.md          # design-model knowledge + fallbacks
skills/{tree,insert,open}/        # /studio:* slash commands
```
