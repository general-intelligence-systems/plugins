# General Intelligence Systems — Claude Code Plugins

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) for General Intelligence Systems.

## Install

Add this marketplace in Claude Code:

```
/plugin marketplace add general-intelligence-systems/plugins
```

Then browse and install plugins with `/plugin`.

## Plugins

| Plugin | Description |
| --- | --- |
| `studio` | CnStudio design tools for Claude Code: MCP server connection, design-model skill, and slash commands. Vendored from [cnstudio-io/plugins](https://github.com/cnstudio-io/plugins). |

## Vendoring

External plugins are vendored into this repo by the reusable
[`vendor-plugins.yaml`](.github/workflows/vendor-plugins.yaml) workflow, which runs
daily (and on demand via *Run workflow*). The list of vendored repos lives in
[`vendor-plugins.json`](vendor-plugins.json):

```json
[
  { "repo": "cnstudio-io/plugins", "path": "cnstudio" }
]
```

Each entry clones `repo` and syncs its contents into `path/` (add `"ref"` to pin a
branch or tag). To reuse this in any other marketplace repo, copy the workflow file
and a `vendor-plugins.json` with your own list.

## Recommended marketplaces

We also recommend adding the [CnStudio marketplace](https://github.com/cnstudio-io/plugins) directly:

```
/plugin marketplace add cnstudio-io/plugins
```

## Org rollout (managed settings)

To register both marketplaces across your org and enable plugin suggestions, add this to `managed-settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "general-intelligence-systems": {
      "source": {
        "source": "github",
        "repo": "general-intelligence-systems/plugins"
      }
    },
    "cnstudio-io": {
      "source": {
        "source": "github",
        "repo": "cnstudio-io/plugins"
      }
    }
  },
  "pluginSuggestionMarketplaces": [
    "general-intelligence-systems",
    "cnstudio-io"
  ]
}
```

Plugin entries in this marketplace declare [`relevance` signals](https://code.claude.com/docs/en/plugin-suggestions), so once the marketplace is allowlisted, Claude Code suggests plugins when a user's session matches (e.g. working with `.studio/` files or the `cnstudio` CLI).
