local M = {}

M.config = {
  auto_compile = true,
  compile_delay = 200,
}

function M.update()
  vim.notify("Typst-preview updated!", vim.log.levels.INFO)
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

        vim.fn.jobstart({ "typst", "compile", temp_file}, { on_exit = function() vim.fn.delete(temp_file) end })
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
end

return M
