# telescope-lsp-handlers.nvim
## What
An extension for Telescope that registers handlers for
- `textDocument/declaration`
- `textDocument/definition`
- `textDocument/implementation`
- `textDocument/typeDefinition`
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
