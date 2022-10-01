local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local conf = require('telescope.config').values

local lsp_util = vim.lsp.util
local jump_to_location = lsp_util.jump_to_location

local M = {}

local function find(items, opts)
  local picker_opts = (opts or {}).picker or {}

  pickers.new(picker_opts, {
    finder = finders.new_table({
      results = items,
      entry_maker = make_entry.gen_from_quickfix(),
    }),
    previewer = conf.qflist_previewer(picker_opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

--- Generates a location handler function to handle multiple LSP methods.
---
--- @param opts (table) configuration options
---        - no_results_message (string) message to display when no locations had been found
---        - picker (table) picker options (see https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md#picker)
local function location_handler(opts)
  --- @param _ (any) not used
  --- @param result (table) result of LSP method; a location or a list of locations.
  --- @param ctx (table) table containing the context of the request, including the method
  return function(_, result, ctx, _)
    if not result or vim.tbl_isempty(result) then
      vim.notify(opts.no_results_message)
      return
    end

    local client = vim.lsp.get_client_by_id(ctx.client_id)

    --- (`textDocument/definition` can return `Location` or `Location[]`
    --- This handles non-table version
    if not vim.tbl_islist(result) then
      jump_to_location(result, client.offset_encoding)
      return
    end

    --- Go to location immediately if there's only one
    if #result == 1 then
      jump_to_location(result[1], client.offset_encoding)
      return
    end

    local items = lsp_util.locations_to_items(result, client.offset_encoding)
    find(items, opts)
  end
end

--- Generates a symbol handler function to handle multiple LSP methods.
---
--- @param opts (table) configuration options
---        - no_results_message (string) message to display when no locations had been found
---        - picker (table) picker options (see https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md#picker)
local function symbol_handler(opts)
  opts = opts or {}

  return function(_, result, _, _)
    if not result or vim.tbl_isempty(result) then
      vim.notify(opts.no_results_message)
      return
    end

    local items = lsp_util.symbols_to_items(result)
    find(items, opts)
  end
end

--- Generates a call hierarchy handler function to handle multiple LSP methods.
---
--- @param direction (string) `"from"` for incoming calls and `"to"` for outgoing calls
--- @param opts (table) configuration options
---        - no_results_message (string) message to display when no locations had been found
---        - picker (table) picker options (see https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md#picker)
local function call_hierarchy_handler(direction, opts)
  return function(_, result)
    if not result or vim.tbl_isempty(result) then
      print(opts.no_results_message)
      return
    end

    local items = {}
    for _, ch_call in pairs(result) do
      local ch_item = ch_call[direction]

      for _, range in pairs(ch_call.fromRanges) do
        table.insert(items, {
          filename = vim.uri_to_fname(ch_item.uri),
          text = ch_item.name,
          lnum = range.start.line + 1,
          col = range.start.character + 1,
        })
      end
    end
    find(items, opts)
  end
end

M.setup = function(opts)
  -- Use default options if needed.
  opts = vim.tbl_deep_extend('keep', opts or {}, {
    declaration = {
      picker = { prompt_title = 'LSP Declarations' },
      no_results_message = 'Declaration not found',
    },
    definition = {
      picker = { prompt_title = 'LSP Definitions' },
      no_results_message = 'Definition not found',
    },
    implementation = {
      picker = { prompt_title = 'LSP Implementations' },
      no_results_message = 'Implementation not found',
    },
    type_definition = {
      picker = { prompt_title = 'LSP Type Definitions' },
      no_results_message = 'Type definition not found',
    },
    reference = {
      picker = { prompt_title = 'LSP References' },
      no_results_message = 'No references found'
    },
    document_symbol = {
      picker = { prompt_title = 'LSP Document Symbols' },
      no_results_message = 'No symbols found',
    },
    workspace_symbol = {
      picker = { prompt_title = 'LSP Workspace Symbols' },
      no_results_message = 'No symbols found',
    },
    incoming_calls = {
      picker = { prompt_title = 'LSP Incoming Calls' },
      no_results_message = 'No calls found',
    },
    outgoing_calls = {
      picker = { prompt_title = 'LSP Outgoing Calls' },
      no_results_message = 'No calls found',
    },
  })

  local handlers = {
    ['textDocument/declaration'] = not opts.declaration.disabled and location_handler(opts.declaration),
    ['textDocument/definition'] = not opts.definition.disabled and location_handler(opts.definition),
    ['textDocument/implementation'] = not opts.implementation.disabled and location_handler(opts.implementation),
    ['textDocument/typeDefinition'] = not opts.type_definition.disabled and location_handler(opts.type_definition),
    ['textDocument/references'] = not opts.reference.disabled and location_handler(opts.reference),
    ['textDocument/documentSymbol'] = not opts.document_symbol.disabled and symbol_handler(opts.document_symbol),
    ['workspace/symbol'] = not opts.workspace_symbol.disabled and symbol_handler(opts.workspace_symbol),
    ['callHierarchy/incomingCalls'] = not opts.incoming_calls.disabled and call_hierarchy_handler('from', opts.incoming_calls),
    ['callHierarchy/outgoingCalls'] = not opts.outgoing_calls.disabled and call_hierarchy_handler('to', opts.outgoing_calls),
  }

  for req, handler in pairs(handlers) do
    if handler then vim.lsp.handlers[req] = handler end
  end
end

return M
