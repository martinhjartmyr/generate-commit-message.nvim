local M = {}

function M.detect_type(diff)
  if
    diff:match("%f[%a]fix%f[%A]")
    or diff:match("%f[%a]bug%f[%A]")
    or diff:match("%f[%a]repair%f[%A]")
    or diff:match("%f[%a]resolve%f[%A]")
  then
    return "fix"
  end
  if
    diff:match("%f[%a]feat%f[%A]")
    or diff:match("%f[%a]add%s")
    or diff:match("%f[%a]implement%f[%A]")
    or diff:match("%f[%a]new%s")
  then
    return "feat"
  end
  if
    diff:match("%f[%a]refactor%f[%A]")
    or diff:match("%f[%a]restructure%f[%A]")
    or diff:match("%f[%a]reorganize%f[%A]")
  then
    return "refactor"
  end
  return "chore"
end

function M.summary_prompt(diff)
  return "Summarize this diff into key changes.\n\n"
    .. "- Focus on intent\n"
    .. "- Ignore noise\n"
    .. "- Keep concise\n\n"
    .. "Diff:\n"
    .. diff
end

function M.commit_prompt(summary, type)
  return "Return EXACTLY ONE commit message. No alternatives, no variations, no examples.\n"
    .. "No explanations, no intro text, no code fences, no markdown formatting.\n\n"
    .. "First line must be exactly: "
    .. type
    .. ": <short summary>\n"
    .. "Max 72 characters for the first line. Use all lowercase.\n\n"
    .. "Then a blank line followed by bullet points using hyphens (-) for each change.\n\n"
    .. "Synthesize ALL changes into this single message. Do not split into multiple messages.\n\n"
    .. "Summary:\n"
    .. summary
end

return M
