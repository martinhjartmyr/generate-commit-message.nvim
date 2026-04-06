local M = {}

function M.get_staged_files()
  local output = vim.fn.systemlist("git diff --staged --name-only")
  local files = {}
  for _, file in ipairs(output) do
    if file ~= "" then
      table.insert(files, file)
    end
  end
  return files
end

function M.get_file_diff(file, max_size)
  local safe_file = vim.fn.shellescape(file)
  local diff = vim.fn.system("git --no-pager diff --staged --unified=3 " .. safe_file)
  if #diff > max_size then
    diff = diff:sub(1, max_size)
  end
  return diff
end

return M
