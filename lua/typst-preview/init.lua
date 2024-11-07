local M = {}

M.config = {
  auto_compile = true,
  compile_delay = 200,
  window_height = 10,
}

function M.update()
  vim.notify("Typst-preview updated!", vim.log.levels.INFO)
end

M.output_bufnr = nil
M.output_winnr = nil

local function create_output_window()
  if M.output_bufnr and vim.api.nvim_buf_is_valid(M.output_bufnr) then
    if not M.output_winnr or not vim.api.nvim_win_is_valid(M.output_winnr) then
      vim.cmd("botright" .. M.config.window_height .. "split")
      M.output_winnr = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(M.output_winnr, M.output_bufnr)
    end
  else
    vim.cmd("botright" .. M.config.window_height .. "split")
    M.output_winnr = vim.api.nvim_get_current_win()
    M.output_bufnr = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_option(M.output_bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(M.output_bufnr, "swapfile", false)
    vim.api.nvim_buf_set_option(M.output_bufnr, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(M.output_bufnr, "filetype", "typst-output")
    vim.api.nvim_buf_set_name(M.output_bufnr, "Typst Output")

    vim.api.nvim_win_set_buf(M.output_winnr, M.output_bufnr)

    vim.api.nvim_buf_set_option(M.output_bufnr, "buflisted", false)
    vim.api.nvim_win_set_option(M.output_winnr, "winfixheight", true)
  end

  vim.cmd("wincmd p")
end

local function update_output(lines)
  if not M.output_bufnr or not vim.api.nvim_buf_is_valid(M.output_bufnr) then
    return
  end

  local current_win = api.nvim_get_current_win()

  vim.api.nvim_buf_set_lines(M.output_bufnr, 0, -1, false, { "Typst Compilation Output:", string.rep("-", 30), "" })
  vim.api.nvim_buf_set_lines(M.output_bufnr, -1, -1, false, lines)

  api.nvim_set_current_win(current_win)
end

local function setup_autocommands()
  local group = vim.api.nvim_create_augroup("TypstPreview", { clear = true })

  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI" }, {
    group = group,
    pattern = "*.typst",
    callback = function()
      if not M.config.auto_compile then return end

      if M.timer then
        M.timer:stop()
      end

      M.timer = vim.defer_fn(function()
        local bufnr = vim.api.nvim_get_current_buf()
        local filepath = vim.api.nvim_buf_get_name(bufnr)

        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local temp_file = filepath .. ".tmp"
        vim.fn.writefile(lines, temp_file)

        create_output_window()

        local output = {}
        vim.fn.jobstart({ "typst", "compile", temp_file}, {
          stdout_buffered = true,
          stderr_buffered = true,
          on_stdout = function(_, data)
            if data then
              vim.list_extend(output, data)
            end
          end,
          on_stderr = function(_, data)
            if data then
              vim.list_extend(output, data)
            end
          end,
          on_exit = function(_, code)
            output = vim.tbl_filter(function(line)
              return line ~= ""
            end, output)

            table.insert(output, "")
            table.insert(output, "Exit code: " .. code)
            vim.schedule(function()
              update_output(output)
            end)

            vim.fn.delete(temp_file)
          end
        })
      end, M.config.compile_delay)
    end
  })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  setup_autocommands()

  vim.api.nvim_create_user_command("TypstPreviewToggle", function()
    M.config.auto_compile = not M.config.auto_compile
    vim.notify("Typst preview " .. (M.config.auto_compile and "enabled" or "disabled"))
  end, {})

  vim.api.nvim_create_user_command("TypstOutputToggle", function()
    if M.output_winnr and vim.api.nvim_win_is_valid(M.output_winnr) then
      vim.api.nvim_win_close(M.output_winnr, true)
      M.output_winnr = nil
    else
      create_output_window()
    end
  end, {})
end

return M
