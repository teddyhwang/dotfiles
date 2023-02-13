local tint_status, tint = pcall(require, "tint")
if not tint_status then
  return
end

tint.setup()
