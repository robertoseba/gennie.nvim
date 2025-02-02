local M = {}

-- Store configuration
M.config = {
	default_profile = nil,
	default_model = nil,
}

-- Escape shell arguments properly
local function shell_escape(str)
	if not str then
		return nil
	end
	-- Replace any single quotes with quoted single quote
	return "'" .. string.gsub(str, "'", "'\\''") .. "'"
end

-- Function to build the gennie command with parameters
local function build_command(question, opts)
	if not question or question == "" then
		return nil, "Question cannot be empty"
	end

	local cmd_parts = { "gennie", "ask", "stream=false" }

	-- Add profile if specified
	if opts.profile or M.config.default_profile then
		local profile = shell_escape(opts.profile or M.config.default_profile)
		if profile then
			table.insert(cmd_parts, "-p=" .. profile)
		end
	end

	-- Add model if specified
	if opts.model or M.config.default_model then
		local model = shell_escape(opts.model or M.config.default_model)
		if model then
			table.insert(cmd_parts, "-m=" .. model)
		end
	end

	-- Add followup flag if specified
	if opts.followup then
		table.insert(cmd_parts, "-f")
	end

	-- Add the question
	table.insert(cmd_parts, shell_escape(question))

	return table.concat(cmd_parts, " "), nil
end

-- Create a new buffer with proper cleanup
local function create_floating_window()
	local buf = vim.api.nvim_create_buf(false, true)

	-- Set buffer options
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].ft = "markdown"

	local width = math.min(120, vim.o.columns - 4)
	local height = math.min(30, vim.o.lines - 4)

	local win_opts = {
		relative = "editor",
		width = width,
		height = height,
		col = (vim.o.columns - width) / 2,
		row = (vim.o.lines - height) / 2,
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, win_opts)

	vim.wo[win].wrap = true
	vim.wo[win].cursorline = true

	-- Add keymaps for the buffer
	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })

	return buf, win
end

function M.set_model(model)
	M.config.default_model = model
	vim.notify(model, vim.log.levels.INFO)
end

-- Function to execute gennie and show results in a floating window
function M.ask_gennie(opts, question)
	opts = opts or {}

	local function execute_gennie(q)
		-- Build command
		local cmd, err = build_command(q, opts)
		if err then
			vim.notify("Gennie error: " .. err, vim.log.levels.ERROR)
			return
		end

		-- Create window before starting job
		local buf, win = create_floating_window()
		if not buf or not win then
			vim.notify("Failed to create window", vim.log.levels.ERROR)
			return
		end

		-- Initial buffer content
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Loading..." })

		-- Execute command
		local job_id = vim.fn.jobstart(cmd, {
			stdout_buffered = true,
			on_stdout = function(_, data)
				if not data then
					return
				end
				-- Check if buffer still exists
				if vim.api.nvim_buf_is_valid(buf) then
					vim.schedule(function()
						-- Remove "Loading..." message
						vim.bo[buf].modifiable = true
						vim.api.nvim_buf_set_lines(buf, 0, -2, false, data)
						vim.bo[buf].modifiable = false
					end)
				end
			end,
			on_stderr = function(_, data)
				if data and data[1] ~= "" then
					vim.schedule(function()
						vim.notify("Gennie error: " .. vim.inspect(data), vim.log.levels.ERROR)
					end)
				end
			end,
			on_exit = function(_, exit_code)
				if exit_code ~= 0 then
					vim.schedule(function()
						vim.notify("Gennie command failed with exit code: " .. exit_code, vim.log.levels.ERROR)
					end)
				end
			end,
		})

		if job_id <= 0 then
			vim.notify("Failed to start gennie command", vim.log.levels.ERROR)
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
	end

	-- If question is provided, execute directly
	if question and question ~= "" then
		execute_gennie(question)
	else
		-- Otherwise prompt for question
		vim.ui.input({ prompt = "Ask Gennie: " }, function(q)
			if q and q ~= "" then
				execute_gennie(q)
			end
		end)
	end
end

-- Function to ask gennie about selected text
function M.ask_gennie_visual(opts, question)
	opts = opts or {}

	-- Get selected text
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

	if #lines == 0 then
		vim.notify("No text selected", vim.log.levels.ERROR)
		return
	end

	-- Get the selected text
	local text = table.concat(lines, "\n")

	-- If question is provided, execute directly
	if question and question ~= "" then
		local full_question = string.format("Regarding this text:\n%s\n\nQuestion: %s", text, question)
		M.ask_gennie(opts, full_question)
	else
		-- Otherwise prompt for question
		vim.ui.input({ prompt = "Ask Gennie about selection: " }, function(q)
			if q and q ~= "" then
				local full_question = string.format("Regarding this text:\n%s\n\nQuestion: %s", text, q)
				M.ask_gennie(opts, full_question)
			end
		end)
	end
end

-- Parse command arguments safely
local function parse_command_args(args)
	local cmd_opts = {}
	local question_parts = {}

	for _, arg in ipairs(args) do
		local profile = arg:match("^%-p=(.+)$")
		local model = arg:match("^%-m=(.+)$")
		if profile then
			cmd_opts.profile = profile
		elseif model then
			cmd_opts.model = model
		elseif arg == "-f" then
			cmd_opts.followup = true
		else
			-- Collect remaining args as question
			table.insert(question_parts, arg)
		end
	end

	-- Join question parts if they exist
	local question = #question_parts > 0 and table.concat(question_parts, " ") or nil
	return cmd_opts, question
end

-- Set up the plugin
function M.setup(opts)
	opts = opts or {}

	-- Store default configuration
	M.config.default_profile = opts.default_profile
	M.config.default_model = opts.default_model

	-- Create user commands with parameter support
	vim.api.nvim_create_user_command("Gennie", function(args)
		local cmd_opts, question = parse_command_args(args.fargs)
		M.ask_gennie(cmd_opts, question)
	end, {
		nargs = "*",
		complete = function(ArgLead, CmdLine, CursorPos)
			local completions = { "-p=", "-m=", "-f" }
			return vim.tbl_filter(function(item)
				return item:find(ArgLead, 1, true) == 1
			end, completions)
		end,
	})

	vim.api.nvim_create_user_command("GennieVisual", function(args)
		local cmd_opts, question = parse_command_args(args.fargs)
		M.ask_gennie_visual(cmd_opts, question)
	end, {
		range = true,
		nargs = "*",
		complete = function(ArgLead, CmdLine, CursorPos)
			local completions = { "-p=", "-m=", "-f" }
			return vim.tbl_filter(function(item)
				return item:find(ArgLead, 1, true) == 1
			end, completions)
		end,
	})

	vim.api.nvim_create_user_command("GennieModel", function(arg)
		M.set_model(arg)
	end, {
		nargs = "*",
		complete = function(ArgLead, CmdLine, CursorPos)
			local completions = { "-p=", "-m=", "-f" }
			return vim.tbl_filter(function(item)
				return item:find(ArgLead, 1, true) == 1
			end, completions)
		end,
	})
end

return M
