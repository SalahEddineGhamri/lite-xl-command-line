-- mod-version:3
local core = require "core"
local keymap = require "core.keymap"
local StatusView = require "core.statusview"
local ime = require "core.ime"
local system = require "system"
local style = require "core.style"
local DocView = require "core.docview"
local command = require "core.command"

local M = {}

-- Change log-----------------------------------------------------------------

-- DONE: command input receives SDL2 processed text input
-- DONE: processing keys still going to detect enter and esc and backspace
-- DONE: start working on autocompletion for the commands

-- TODO: check how to handle taking suggestions in
-- TODO: exectute even lite xl commands
-- TODO: clearing status bar shoul accept exceptions
-- TODO: console.log stealing the status bar (test it and see if still happen)

------------------------------------------------------------------------------

M.last_user_input = ""
M.command_prompt_label = ""
M.in_command = false
M.user_input = ""
M.done_callback = nil
M.suggest_callback = nil

-- customize prompt
function M.set_prompt(prompt)
  M.command_prompt_label = string.format("%s:", prompt) 
end
    
function M.start_command(opts)
  M.in_command = true
  M.user_input = ""
  M.done_callback = opts and opts.submit or nil
  M.suggest_callback = opts and opts.suggest or function(_) return {} end
end

-- get last user input
function M.get_last_user_input()
   return M.last_user_input 
end

-- execute_command
function M.execute_or_return_command()
  M.last_user_input = M.user_input
  M.user_input = ""
  M.in_command = false

  -- call if it was provided
  if M.done_callback then
    M.done_callback(M.last_user_input)
    M.done_callback = nil
  end
end

function M.command_string()
  if M.in_command then
    local suggestion_suffix = ""
    if #M.user_input > 0 then
      local suggestions = M.suggest_callback and M.suggest_callback(M.user_input)
      local suggestion = suggestions and suggestions[1] and suggestions[1].text or ""
      if suggestion:sub(1, #M.user_input) == M.user_input and #suggestion > #M.user_input then
        suggestion_suffix = suggestion:sub(#M.user_input + 1)
      end
    end

    return {
      style.accent, M.command_prompt_label,
      style.text, M.user_input,
      style.dim, suggestion_suffix
    }
  end
  return {}
end

-- Add status bar item once
if not core.status_view:get_item("status:command_line") then
  core.status_view:add_item({
    name = "status:command_line",
    alignment = StatusView.Item.LEFT,
    get_item = M.command_string,
    position = 1000, -- after other items
    tooltip = "command line input",
    separator = core.status_view.separator2
  })
end

local original_on_event = core.on_event
function core.on_event(type, ...)
  if type == "textinput" and M.in_command then
    local text = ...
    M.user_input = M.user_input .. text
    return true -- prevent further propagation
  end

  return original_on_event(type, ...)
end

local original_on_key_pressed = keymap.on_key_pressed

function keymap.on_key_pressed(key, ...)
  if PLATFORM ~= "Linux" and ime.editing then
    return false
  end

  if M.in_command then
    if key == "return" then
      M.in_command = false
      M.execute_or_return_command()
    elseif key == "escape" then
      M.in_command = false
      M.user_input = ""
    elseif key == "backspace" then
      M.user_input = M.user_input:sub(1, -2)
    end
  end

  return original_on_key_pressed(key, ...)
end

-- adding a config to clear status bar
local ran = false
local mt = {
  __newindex = function(_, key, value)
    if key == "minimal_status_view" and value == true and not ran then
      ran = true
      core.add_thread(function()
        core.status_view:hide_items()
        core.status_view:show_items(
          "status:command_line"
        )
      end)
    end
    rawset(M, key, value)
  end
}

return setmetatable(M, mt)

