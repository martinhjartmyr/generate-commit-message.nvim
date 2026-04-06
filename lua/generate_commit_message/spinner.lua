local M = {}
local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function M.start(buf, row, text)
  local frame_idx = 1
  local timer
  local inserted = false
  local cancelled = false
  local progress_text = text

  local stop
  local cancel

  local function render()
    if not vim.api.nvim_buf_is_valid(buf) then
      stop()
      return
    end
    local line = frames[frame_idx] .. " " .. progress_text .. " (ctrl-c to cancel)"
    vim.cmd("silent! undojoin")
    vim.api.nvim_buf_set_lines(buf, row, row + 2, false, { line, "" })
    inserted = true
    frame_idx = (frame_idx % #frames) + 1
  end

  render()

  timer = vim.uv.new_timer()
  timer:start(
    0,
    80,
    vim.schedule_wrap(function()
      render()
    end)
  )

  stop = function()
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
    if inserted and vim.api.nvim_buf_is_valid(buf) then
      local lines = vim.api.nvim_buf_get_lines(buf, row, row + 2, false)
      if #lines > 0 and lines[1]:match("^%S+") then
        vim.cmd("silent! undojoin")
        vim.api.nvim_buf_set_lines(buf, row, row + 2, false, {})
      end
    end
  end

  cancel = function()
    cancelled = true
    stop()
  end

  return {
    stop = stop,
    cancel = cancel,
    is_cancelled = function()
      return cancelled
    end,
    set_progress = function(text)
      progress_text = text
    end,
  }
end

return M
