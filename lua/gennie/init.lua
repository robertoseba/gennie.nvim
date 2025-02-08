local M = {}

-- Store configuration
M.config = {
	default_profile = "default",
	default_model = "sonnet",
	chat_history = {},
}

local function shell_escape(str)
	if not str then
		return nil
	end
	-- Replace any single quotes with quoted single quote
	return "'" .. string.gsub(str, "'", "'\\''") .. "'"
end

-- Parse config command arguments safely
local function parse_command_args(args)
	if not args or #args == 0 then
		return {}
	end

	local valid_options = {
		["-p"] = "profile",
		["-m"] = "model",
	}

	local cmd_opts = {}

	for _, arg in ipairs(args) do
		local flag, value = arg:match("^(-[pm])=(.+)$")

		if flag and valid_options[flag] then
			local key = valid_options[flag]
			cmd_opts[key] = value
		else
			vim.notify(
				string.format("Invalid parameter: %s\nValid options: -p=<profile>, -m=<model>", arg),
				vim.log.levels.ERROR
			)
			return {}
		end
	end

	return cmd_opts
end

-- Input dialog
local function input_dialog(opts, callback)
	local is_followup = ""
	if opts.is_followup then
		is_followup = "(FollowUp)"
	end

	vim.ui.input({
		prompt = "Ask Gennie"
			.. is_followup
			.. " -> "
			.. M.config.default_model
			.. " -> "
			.. M.config.default_profile
			.. ":",
	}, callback)
end

-- Function to build the gennie command with parameters
local function build_command(question, opts)
	if not question or question == "" then
		return {}, "Question cannot be empty"
	end

	local cmd_parts = { "gennie", "ask", "--stream=false" }

	-- Add profile if specified
	if opts.profile or M.config.default_profile then
		local profile = opts.profile or M.config.default_profile
		if profile then
			table.insert(cmd_parts, "-p=" .. profile)
		end
	end

	-- Add model if specified
	if opts.model or M.config.default_model then
		local model = opts.model or M.config.default_model
		if model then
			table.insert(cmd_parts, "-m=" .. model)
		end
	end

	-- Add followup flag if specified
	if opts.is_followup and opts.is_followup == true then
		table.insert(cmd_parts, "-f")
	end

	-- Add the question
	table.insert(cmd_parts, shell_escape(question))

	return cmd_parts, nil
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

local function execute_gennie(q, opts)
	local cmd, err = build_command(q, opts)
	if err then
		vim.notify("Gennie error: " .. err, vim.log.levels.ERROR)
		return
	end

	-- Resets history
	if not opts.is_followup or opts.is_followup == false then
		M.config.chat_history = {}
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
	vim.system(cmd, { text = true }, function(obj)
		if obj.code ~= 0 then
			vim.notify("Gennie command failed with exit code: " .. obj.code, vim.log.levels.ERROR)
			if obj.stderr and #obj.stderr > 0 then
				vim.notify("Gennie error: " .. obj.stderr, vim.log.levels.ERROR)
			end
			return
		end

		if obj.stdout then
			local data = vim.split(obj.stdout, "\n")
			table.insert(M.config.chat_history, { answer = data, question = q })
			-- Check if buffer still exists
			vim.schedule(function()
				M.last_answer(buf, win)
			end)
		end
	end)
end

local function set_config_vars(opts)
	if opts.model then
		M.config.default_model = opts.model
		vim.notify("Gennie Model set to:" .. opts.model, vim.log.levels.INFO)
	end
	if opts.profile then
		M.config.default_profile = opts.profile
		vim.notify("Gennie Profile set to:" .. opts.profile, vim.log.levels.INFO)
	end
end

function M.set_config(args)
	if args then
		local opts = parse_command_args(args.fargs)
		set_config_vars(opts)
		return
	end

	vim.ui.input({
		prompt = "Config Gennie:",
	}, function(iargs)
		if not iargs or iargs == "" then
			return
		end
		local data = vim.split(iargs, " ")
		local opts = parse_command_args(data)
		set_config_vars(opts)
	end)
end

function M.ask_gennie(opts)
	opts = opts or {}
	if opts.is_followup == true and #M.config.chat_history == 0 then
		vim.notify("No chat to follow up", vim.log.levels.ERROR)
		return
	end

	input_dialog(opts, function(q)
		if q and q ~= "" then
			execute_gennie(q, opts)
		end
	end)
end

-- Function to ask gennie about selected text
function M.ask_gennie_visual(opts)
	opts = opts or {}
	-- Get selected text
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

	if #lines == 0 then
		vim.notify("No text selected", vim.log.levels.ERROR)
		return
	end

	local selected_text = table.concat(lines, "\n")

	input_dialog(opts, function(q)
		if q and q ~= "" then
			local full_question = string.format("Regarding this excerpt:\n%s\n\nQuestion: %s", selected_text, q)
			execute_gennie(full_question, opts)
		end
	end)
end

function M.last_answer(buf, win)
	local function parse_history(history)
		local full_text = {}
		local length = #history
		for i = length, 1, -1 do
			table.insert(full_text, "## Question")
			table.insert(full_text, history[i].question)
			table.insert(full_text, "")
			table.insert(full_text, "## Answer")
			for _, a in ipairs(history[i].answer) do
				table.insert(full_text, a)
			end
			table.insert(full_text, "")
			table.insert(full_text, "---")
		end
		return full_text
	end

	if #M.config.chat_history == 0 then
		vim.notify("No previous question", vim.log.levels.INFO)
		return
	end

	if not buf and not win then
		buf, win = create_floating_window()
	end
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, parse_history(M.config.chat_history))
	vim.bo[buf].modifiable = false
end

function M.setup(opts)
	opts = opts or {}
	-- Store default configuration
	M.config.default_profile = opts.default_profile or "default"
	M.config.default_model = opts.default_model or "sonnet"

	vim.api.nvim_create_user_command("Gennie", function()
		M.ask_gennie(opts)
	end, {})

	vim.api.nvim_create_user_command("GennieLast", function()
		M.last_answer()
	end, {})

	vim.api.nvim_create_user_command("GennieVisual", function()
		M.ask_gennie_visual(opts)
	end, {
		range = true,
	})

	vim.api.nvim_create_user_command("GennieConfig", function(args)
		M.set_config(args)
	end, {
		nargs = "*",
	})
end

return M
