local telescope = require('telescope')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local make_entry = require('telescope.make_entry')
local conf = require('telescope.config').values

local lsp_util = vim.lsp.util
local lsp_buf = vim.lsp.buf
local jump_to_location = lsp_util.jump_to_location

local mapping_actions = {
  ['<C-x>'] = actions.file_split,
  ['<C-v>'] = actions.file_vsplit,
  ['<C-t>'] = actions.file_tab,
}

local function jump_fn(prompt_bufnr, action, offset_encoding)
  return function()
    local selection = action_state.get_selected_entry(prompt_bufnr)
    if not selection then
      return
    end

    if action then
      action(prompt_bufnr)
    else
      actions.close(prompt_bufnr)
    end

    local pos = {
      line = selection.lnum - 1,
      character = selection.col,
    }

    jump_to_location({
      uri = vim.uri_from_fname(selection.filename),
      range = {
        start = pos,
        ['end'] = pos,
      },
    }, offset_encoding)
  end
end

local function attach_location_mappings(offset_encoding)
  return function(prompt_bufnr, map)
    local modes = { 'i', 'n' }
    local keys = { '<CR>', '<C-x>', '<C-v>', '<C-t>' }

    for _, mode in pairs(modes) do
      for _, key in pairs(keys) do
        local action = mapping_actions[key]
        map(mode, key, jump_fn(prompt_bufnr, action, offset_encoding))
      end
    end

    -- Additional mappings don't push the item to the tagstack.
    return true
  end
end

local function apply_edit_fn(prompt_bufnr, offset_encoding)
  return function()
    local selection = action_state.get_selected_entry(prompt_bufnr)
    actions.close(prompt_bufnr)
    if not selection then
      return
    end

    local action = selection.value
    if action.edit or type(action.command) == 'table' then
      if action.edit then
        lsp_util.apply_workspace_edit(action.edit, offset_encoding)
      end
      if type(action.command) == 'table' then
        lsp_buf.execute_command(action.command)
      end
    else
      lsp_buf.execute_command(action)
    end
  end
end

local function attach_code_action_mappings(offset_encoding)
  return function(prompt_bufnr, map)
    map('i', '<CR>', apply_edit_fn(prompt_bufnr, offset_encoding))
    map('n', '<CR>', apply_edit_fn(prompt_bufnr, offset_encoding))

    return true
  end
end

local function find(prompt_title, items, find_opts, offset_encoding)
  local opts = find_opts.opts or {}

  local entry_maker = find_opts.entry_maker or make_entry.gen_from_quickfix(opts)
  local attach_mappings = find_opts.attach_mappings or attach_location_mappings(offset_encoding)
  local previewer = nil
  if not find_opts.hide_preview then
    previewer = conf.qflist_previewer(opts)
  end

  pickers
    .new(opts, {
      prompt_title = prompt_title,
      finder = finders.new_table({
        results = items,
        entry_maker = entry_maker,
      }),
      previewer = previewer,
      sorter = conf.generic_sorter(opts),
      attach_mappings = attach_mappings,
    })
    :find()
end

local function get_correct_result(result1, result2)
  return type(result1) == 'table' and result1 or result2
end

local function location_handler(prompt_title, opts)
  -- Each lsp-handler has this signature: function(err, result, ctx, config)
  return function(_, result, context, _)
    local res = get_correct_result(result, context)
    local client = vim.lsp.get_client_by_id(context.client_id)

    if not res or vim.tbl_isempty(res) then
      print(opts.no_results_message)
      return
    end

    if not vim.tbl_islist(res) then
      jump_to_location(res, client.offset_encoding)
      return
    end

    if #res == 1 then
      jump_to_location(res[1], client.offset_encoding)
      return
    end

    local items = lsp_util.locations_to_items(res, client.offset_encoding)
    find(prompt_title, items, { opts = opts.telescope }, client.offset_encoding)
  end
end

local function symbol_handler(prompt_name, opts)
  opts = opts or {}

  -- Each lsp-handler has this signature: function(err, result, ctx, config)
  return function(_, result, context, _)
    local res = get_correct_result(result, context)
    if not res or vim.tbl_isempty(res) then
      print(opts.no_results_message)
      return
    end

    local items = lsp_util.symbols_to_items(res)
    local client = vim.lsp.get_client_by_id(context.client_id)
    find(prompt_name, items, { opts = opts.telescope }, client.offset_encoding)
  end
end

local function call_hierarchy_handler(prompt_name, direction, opts)
  -- Each lsp-handler has this signature: function(err, result, ctx, config)
  return function(_, result, context, _)
    local res = get_correct_result(result, context)
    if not res or vim.tbl_isempty(res) then
      print(opts.no_results_message)
      return
    end

    local items = {}
    for _, ch_call in pairs(res) do
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
    local client = vim.lsp.get_client_by_id(context.client_id)
    find(prompt_name, items, { opts = opts.telescope }, client.offset_encoding)
  end
end

local function code_action_handler(prompt_title, opts)
  -- Each lsp-handler has this signature: function(err, result, ctx, config)
  return function(_, result, context, _)
    local res = get_correct_result(result, context)
    if not res or vim.tbl_isempty(res) then
      print(opts.no_results_message)
      return
    end

    for idx, value in ipairs(res) do
      value.idx = idx
    end

    local client = vim.lsp.get_client_by_id(context.client_id)
    local find_opts = {
      opts = opts.telescope,
      entry_maker = function(line)
        return {
          valid = line ~= nil,
          value = line,
          ordinal = line.idx .. line.title,
          display = string.format('%s%d: %s', opts.prefix, line.idx, line.title),
        }
      end,
      attach_mappings = attach_code_action_mappings(client.offset_encoding),
      hide_preview = true,
    }
    find(prompt_title, res, find_opts, client.offset_encoding)
  end
end

return telescope.register_extension({
  setup = function(opts)
    -- Use default options if needed.
    opts = vim.tbl_deep_extend('keep', opts, {
      disable = {},
      location = {
        telescope = {},
        no_results_message = 'No references found',
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
    })

    local handlers = {
      ['textDocument/declaration'] = location_handler('LSP Declarations', opts.location),
      ['textDocument/definition'] = location_handler('LSP Definitions', opts.location),
      ['textDocument/implementation'] = location_handler('LSP Implementations', opts.location),
      ['textDocument/typeDefinition'] = location_handler('LSP Type Definitions', opts.location),
      ['textDocument/references'] = location_handler('LSP References', opts.location),
      ['textDocument/documentSymbol'] = symbol_handler('LSP Document Symbols', opts.symbol),
      ['workspace/symbol'] = symbol_handler('LSP Workspace Symbols', opts.symbol),
      ['callHierarchy/incomingCalls'] = call_hierarchy_handler('LSP Incoming Calls', 'from', opts.call_hierarchy),
      ['callHierarchy/outgoingCalls'] = call_hierarchy_handler('LSP Outgoing Calls', 'to', opts.call_hierarchy),
      ['textDocument/codeAction'] = code_action_handler('LSP Code Actions', opts.code_action),
    }

    for req, handler in pairs(handlers) do
      if not opts.disable[req] then
        vim.lsp.handlers[req] = handler
      end
    end
  end,
  exports = {},
})
