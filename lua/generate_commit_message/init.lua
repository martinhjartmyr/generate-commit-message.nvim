local M = {}

M.config = {
  summary_model = "llama3.1",
  commit_model = "llama3.1",
  max_file_diff = 4000,
  auto_trigger = true,
  ollama_url = "http://localhost:11434/api/generate",
  api_key = nil,
  num_ctx = 8192,
}

function M.setup(opts)
  local defaults = vim.tbl_deep_extend("force", M.config, opts or {})
  defaults.api_key = defaults.api_key or os.getenv("OLLAMA_API_KEY")
  M.config = defaults

  vim.api.nvim_create_user_command("GenerateCommitMessage", function()
    require("generate_commit_message.core").run(M.config)
  end, {})

  vim.api.nvim_create_user_command("GenerateCommitMessageCancel", function()
    require("generate_commit_message.core").cancel()
  end, {})

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "gitcommit",
    callback = function()
      if not vim.b.generate_commit_keymap_set then
        vim.keymap.set("n", "<leader>cm", function()
          require("generate_commit_message.core").run(M.config)
        end, { buffer = true, desc = "Generate commit message" })
        vim.b.generate_commit_keymap_set = true
      end

      if M.config.auto_trigger and not vim.b.generate_commit_auto_triggered then
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local has_content = false
        for _, line in ipairs(lines) do
          if line ~= "" and not line:match("^#") then
            has_content = true
            break
          end
        end
        if not has_content then
          vim.b.generate_commit_auto_triggered = true
          require("generate_commit_message.core").run(M.config)
        end
      end
    end,
  })
end

return M
