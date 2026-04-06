local M = {}

local function check_curl()
  if vim.fn.executable("curl") == 0 then
    vim.notify(
      "curl is required but not installed",
      vim.log.levels.ERROR,
      { title = "generate-commit-message.nvim" }
    )
    return false
  end
  return true
end

local function do_query(ollama_url, model, prompt_text, on_done, api_key, num_ctx, retries)
  if not check_curl() then
    on_done("")
    return
  end

  local is_local = ollama_url:find("localhost")
    or ollama_url:find("127%.0%.0%.1")
    or ollama_url:find("0%.0%.0%.0")
  local is_cloud = not is_local and api_key and api_key ~= ""

  local body
  if is_cloud then
    body = vim.json.encode({
      model = model,
      messages = { { role = "user", content = prompt_text } },
      stream = false,
      options = { num_ctx = num_ctx or 8192 },
    })
  else
    body = vim.json.encode({
      model = model,
      prompt = prompt_text,
      stream = false,
      options = { num_ctx = num_ctx or 8192 },
    })
  end

  local curl_cmd = {
    "curl",
    "-s",
    "-w",
    "\n%{http_code}",
    "-X",
    "POST",
    ollama_url,
    "-H",
    "Content-Type: application/json",
  }

  if is_cloud then
    table.insert(curl_cmd, "-H")
    table.insert(curl_cmd, "Authorization: Bearer " .. api_key)
  end

  table.insert(curl_cmd, "-d")
  table.insert(curl_cmd, body)

  local job
  job = vim.system(curl_cmd, { text = true, timeout = 120000 }, function(result)
    if result.code ~= 0 then
      print("Ollama error: " .. result.stderr)
      on_done("")
      return
    end

    local stdout = result.stdout
    local http_code = stdout:match("\n(%d+)$")
    if http_code then
      stdout = stdout:sub(1, -#http_code - 2)
    end

    if http_code and tonumber(http_code) == 429 then
      if retries > 5 then
        print("Ollama rate limited, giving up after 5 retries")
        on_done("")
        return
      end
      local timer = vim.uv.new_timer()
      timer:start(
        1000,
        0,
        vim.schedule_wrap(function()
          timer:close()
          do_query(ollama_url, model, prompt_text, on_done, api_key, num_ctx, retries + 1)
        end)
      )
      return
    end

    if http_code and tonumber(http_code) ~= 200 then
      print("Ollama API error (HTTP " .. http_code .. "): " .. stdout:sub(1, 500))
      on_done("")
      return
    end

    local ok, data = pcall(vim.json.decode, stdout)
    if not ok then
      print("Failed to parse Ollama response: " .. tostring(stdout):sub(1, 500))
      on_done("")
      return
    end

    if data.error then
      print("Ollama API error: " .. data.error)
      on_done("")
      return
    end

    local text
    if is_cloud then
      text = data.message and data.message.content
    else
      text = data.response
    end

    if not text or text == "" then
      if data.done_reason == "load" then
        if retries > 10 then
          print(
            "Ollama model '"
              .. model
              .. "' failed to load after 10 retries. Run 'ollama pull "
              .. model
              .. "' and try again."
          )
          on_done("")
          return
        end
        local timer = vim.uv.new_timer()
        timer:start(
          5000,
          0,
          vim.schedule_wrap(function()
            timer:close()
            do_query(ollama_url, model, prompt_text, on_done, api_key, num_ctx, retries + 1)
          end)
        )
      else
        print(
          "Failed to parse Ollama response (done_reason: "
            .. tostring(data.done_reason)
            .. ", has_response: "
            .. tostring(text ~= nil)
            .. ")"
        )
        on_done("")
      end
      return
    end

    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    on_done(text)
  end)

  return job
end

function M.query(ollama_url, model, prompt_text, on_done, api_key, num_ctx)
  return do_query(ollama_url, model, prompt_text, on_done, api_key, num_ctx, 0)
end

return M
