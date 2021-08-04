# telescope-lsp-handlers.nvim
## What
An extension for Telescope that registers handlers for
- `textDocument/declaration`
- `textDocument/definition`
- `textDocument/implementation`
- `textDocument/typeDefinition`
- `textDocument/references`
- `textDocument/documentSymbol`
- `workspace/symbol`
- `callHierarchy/incomingCalls`
- `callHierarchy/outgoingCalls`
- `textDocument/codeAction`

## Why
1. I wanted to learn how to extend Telescope
2. I wanted to learn how to extend Neovim's built-in LSP handlers
3. I wanted to use `vim.lsp.buf.*` commands instead of `Telescope lsp_*` ones so I wouldn't need to
   rely on Telescope replicating utility functions that are already part of Neovim's built-in LSP
4. Telescope's built-in LSP functions do not push items to the tagstack when picked manually, these
   handlers do

## How
Install this plugin with your favorite package manager and then load it with Telescope:
```lua
telescope.load_extension('lsp_handlers')
```

Then proceed to use the built-in API for supported requests.

### Customization
It is possible to customize handlers in Telescope's setup phase. The following configuration is the
default one:
```lua
telescope.setup({
	extensions = {
		lsp_handlers = {
			disable = {},
			location = {
				telescope = {},
				no_results_message = 'No references found',
				jump_type = nil,
			},
			symbol = {
				telescope = {},
				no_results_message = 'No symbols found',
			},
			call_hierarchy = {
				telescope = {},
				no_results_message = 'No calls found',
			},
			code_action = {
				telescope = {},
				no_results_message = 'No code actions available',
				prefix = '',
			},
		},
	}
})
```

I personally like to have the following settings, which gives me a cute dropdown for code actions:
```lua
telescope.setup({
	extensions = {
		lsp_handlers = {
			code_action = {
				telescope = require('telescope.themes').get_dropdown({}),
			},
		},
	},
}
```

By default the `location` handler jumps to the location in the current window if there is only one,
you can change this behavior using option `jump_type`:
- `jump_type = "never"`: show Telescope picker
- `jump_type = "tab"`: jump to location in a new tab
- `jump_type = "split"`: jump to location in a new horizontal split
- `jump_type = "vsplit"`: jump to location in a new vertical split

#### Disabling specific handlers
```lua
telescope.setup({
	extensions = {
		lsp_handlers = {
			disable = {
				['textDocument/codeAction'] = true,
			},
		},
	},
}
```
