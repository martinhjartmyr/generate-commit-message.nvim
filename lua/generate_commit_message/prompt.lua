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
  return "Analyze this diff and produce a concise technical summary.\n\n"
    .. "For each logical change, describe:\n"
    .. "- What changed and why\n"
    .. "- Any breaking changes, migration needs, or side effects\n\n"
    .. "Skip: formatting noise, boilerplate, mechanical refactors.\n\n"
    .. "Diff:\n"
    .. diff
end

function M.commit_prompt(summary, type)
  return "Generate a conventional commit message.\n\n"
    .. "Detected type: "
    .. type
    .. "\n"
    .. "Format: type(scope): imperative summary (max 72 chars for subject)\n"
    .. "Use lowercase for type and summary, but preserve acronyms/caps in scope.\n\n"
    .. "Then a blank line followed by body explaining WHY this change was made.\n"
    .. "Use bullet points (-) for specific changes.\n"
    .. "If there are breaking changes, add 'BREAKING CHANGE:' in the body.\n\n"
    .. "Summary:\n"
    .. summary
end

return M
