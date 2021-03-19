local telescope = require('telescope')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local make_entry = require('telescope.make_entry')
local conf = require('telescope.config').values

local lsp_util = vim.lsp.util
local jump_to_location = lsp_util.jump_to_location

local function attach_mappings(prompt_bufnr, map)
	local function jump()
		local selection = action_state.get_selected_entry(prompt_bufnr)

		actions.close(prompt_bufnr)

		local pos = {
			line = selection.lnum,
			character = selection.col,
		}

		jump_to_location({
			uri = vim.uri_from_fname(selection.filename),
			range = {
				start = pos,
				['end'] = pos,
			}
		})
	end
	map('i', '<CR>', jump)
	map('n', '<CR>', jump)

	-- Additional mappings don't push the item to the tagstack.
	return true
end

local function find(prompt_title, items, opts)
	pickers.new({
		prompt_title = prompt_title,
		finder = finders.new_table({
			results = items,
			entry_maker = make_entry.gen_from_quickfix(opts),
		}),
		previewer = conf.qflist_previewer(opts),
		sorter = conf.generic_sorter(opts),
		attach_mappings = attach_mappings,
	}):find()
end

local function location_handler(prompt_title, opts)
	opts = opts or {}

	return function(_, _, result)
		if not result or vim.tbl_isempty(result) then
			print('No reference found')
			return
		end

		if not vim.tbl_islist(result) then
			jump_to_location(result)
			return
		end

		if #result == 1 then
			jump_to_location(result[1])
			return
		end

		local items = lsp_util.locations_to_items(result)
		find(prompt_title, items, opts)
	end
end

local function symbol_handler(prompt_name, opts)
	opts = opts or {}

	return function(_, _, result)
		if not result or vim.tbl_isempty(result) then
			print('No symbol found')
			return
		end

		local items = lsp_util.symbols_to_items(result)
		find(prompt_name, items, opts)
	end
end

return telescope.register_extension({
	setup = function(opts)
		vim.lsp.handlers['textDocument/declaration'] = location_handler('LSP Declarations', opts)
		vim.lsp.handlers['textDocument/definition'] = location_handler('LSP Definitions', opts)
		vim.lsp.handlers['textDocument/implementation'] = location_handler('LSP Implementations', opts)
		vim.lsp.handlers['textDocument/typeDefinition'] = location_handler('LSP Type Definitions', opts)
		vim.lsp.handlers['textDocument/documentSymbol'] =  symbol_handler('LSP Document Symbols', opts)
		vim.lsp.handlers['workspace/symbol'] =  symbol_handler('LSP Workspace Symbols', opts)
	end,
	exports = {},
})
