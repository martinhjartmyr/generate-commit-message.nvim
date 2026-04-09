local git = require("generate_commit_message.git")
local prompt = require("generate_commit_message.prompt")
local ollama = require("generate_commit_message.ollama")
local spinner = require("generate_commit_message.spinner")

local M = {}

local active_generation = nil

local function find_insert_row(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for i, line in ipairs(lines) do
    if line:match("^#") then
      return i - 1
    end
  end

  return 0
end

local function is_local_url(url)
  return url:find("localhost") or url:find("127%.0%.0%.1") or url:find("0%.0%.0%.0")
end

function M.run(config)
  local buf = vim.api.nvim_get_current_buf()

  local files = git.get_staged_files()
  if #files == 0 then
    print("No staged files")
    return
  end

  local row = find_insert_row(buf)
  local spinner_handle = spinner.start(buf, 0, "Working...")
  spinner_handle.set_progress("Summarizing " .. #files .. " files...")
  vim.api.nvim_buf_set_lines(buf, 1, 1, false, { "" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  local notif = vim.notify(
    "Generating commit message...",
    vim.log.levels.INFO,
    { title = "generate-commit-message.nvim" }
  )

  local jobs = {}

  active_generation = {
    buf = buf,
    spinner_handle = spinner_handle,
    notif = notif,
    jobs = jobs,
    cancelled = false,
    done = false,
    get_cancelled = function()
      return active_generation.cancelled
    end,
    set_cancelled = function()
      active_generation.cancelled = true
    end,
    get_done = function()
      return active_generation.done
    end,
    set_done = function()
      active_generation.done = true
    end,
  }

  local function cleanup()
    for _, job in ipairs(jobs) do
      if job then
        pcall(function()
          job:kill(1)
        end)
      end
    end
    vim.keymap.del("n", "<C-c>", { buffer = buf })
    active_generation = nil
  end

  local function on_all_summaries_done(summaries)
    if active_generation and active_generation.get_cancelled() then
      return
    end
    if not active_generation then
      return
    end
    active_generation.set_done()

    local combined = table.concat(summaries, "\n")
    local commit_type = prompt.detect_type(combined)

    spinner_handle.set_progress("Generating commit message...")

    local job = ollama.query(
      config.ollama_url,
      config.commit_model,
      config.commit_prompt(combined, commit_type),
      function(result)
        vim.schedule(function()
          cleanup()
          spinner_handle.stop()
          if notif and type(notif) == "table" and notif.close then
            notif:close()
          end
          if result ~= "" then
            vim.api.nvim_buf_set_lines(buf, 0, row, false, vim.split(result, "\n"))
          end
        end)
      end,
      config.api_key,
      config.num_ctx
    )
    if active_generation then
      table.insert(active_generation.jobs, job)
    end
  end

  vim.keymap.set("n", "<C-c>", function()
    M.cancel()
  end, { buffer = buf })

  local function process_files_sequential()
    local summaries = {}
    local index = 1

    local function process_next()
      if active_generation and active_generation.get_cancelled() then
        return
      end
      if index > #files then
        on_all_summaries_done(summaries)
        return
      end

      local i = index
      local filename = vim.fn.fnamemodify(files[i], ":t")
      spinner_handle.set_progress(string.format("Summarizing file %d/%d: %s", i, #files, filename))
      local diff = git.get_file_diff(files[i], config.max_file_diff)
      index = index + 1

      local job = ollama.query(
        config.ollama_url,
        config.summary_model,
        config.summary_prompt(diff),
        function(result)
          summaries[i] = result
          vim.defer_fn(process_next, 500)
        end,
        config.api_key,
        config.num_ctx
      )
      if active_generation then
        table.insert(active_generation.jobs, job)
      end
    end

    process_next()
  end

  local function process_files_parallel()
    local summaries = {}
    local pending = #files

    for i, file in ipairs(files) do
      local diff = git.get_file_diff(file, config.max_file_diff)

      local job = ollama.query(
        config.ollama_url,
        config.summary_model,
        config.summary_prompt(diff),
        function(result)
          summaries[i] = result
          pending = pending - 1
          spinner_handle.set_progress(string.format("Summarizing files (%d remaining)", pending))
          if pending == 0 then
            on_all_summaries_done(summaries)
          end
        end,
        config.api_key,
        config.num_ctx
      )
      if active_generation then
        table.insert(active_generation.jobs, job)
      end
    end
  end

  if is_local_url(config.ollama_url) then
    process_files_sequential()
  else
    process_files_parallel()
  end
end

function M.cancel()
  if not active_generation then
    return
  end
  local gen = active_generation
  if gen.get_cancelled() or gen.get_done() then
    return
  end

  gen.set_cancelled()
  for _, job in ipairs(gen.jobs) do
    if job then
      pcall(function()
        job:kill(1)
      end)
    end
  end
  gen.spinner_handle.cancel()
  if gen.notif and type(gen.notif) == "table" and gen.notif.close then
    gen.notif:close()
  end
  vim.keymap.del("n", "<C-c>", { buffer = gen.buf })
  active_generation = nil
  vim.notify(
    "Generation cancelled",
    vim.log.levels.INFO,
    { title = "generate-commit-message.nvim" }
  )
end

return M
