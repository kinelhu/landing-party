-- Chat notices (scripts: shared.notice): off by default. The user (2026-10-17): "nothing is communicated through notices
-- in factorio"; on, for debugging, the corporations' moves are told in chat and with alerts as before.
data:extend{
  {type = "bool-setting", name = "lp-chat-notices", setting_type = "runtime-global", default_value = false, order = "a"},
}
