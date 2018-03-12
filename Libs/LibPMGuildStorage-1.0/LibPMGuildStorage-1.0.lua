-- GetNote(name): Returns the officer note of member 'name'
--
-- SetNote(name, note): Sets the officer note of member 'name' to
-- 'note'
--
-- GetClass(name): Returns the class of member 'name'
--
-- GetRank(name)
--
-- GetOnline(name)
--
-- GetGuildInfo(): Returns the guild info text
--
-- IsCurrentState(): Return true if the state of the library is current.
--
--
-- GuildInfoChanged(info): Fired when guild info has changed since its
--   previous state. The info is the new guild info.
--
-- GuildNoteChanged(name, note): Fired when a guild note changes. The
--   name is the name of the member of which the note changed and the
--   note is the new note.
--
-- StateChanged(): Fired when the state of the guild storage cache has
-- changed.
--
-- GuildNoteDeleted()
--
-- InconsistentNote()

-- GLOBALS: ChatThrottleLib, DEFAULT_CHAT_FRAME, GuildRosterFrame, GuildRosterShowOfflineButton
local pairs, next, mmin = _G.pairs, _G.next, _G.math.min
local Ambiguate = _G.Ambiguate
local IsInGuild = _G.IsInGuild
local GuildRosterSetOfficerNote = _G.GuildRosterSetOfficerNote
local GetNumGuildMembers = _G.GetNumGuildMembers
local GetGuildInfoText = _G.GetGuildInfoText
local GetGuildRosterInfo = _G.GetGuildRosterInfo
local SetGuildRosterShowOffline = _G.SetGuildRosterShowOffline
local GuildRoster = _G.GuildRoster
local UnitName = _G.UnitName
local SendAddonMessage = _G.SendAddonMessage

local MAJOR_VERSION = "LibPMGuildStorage-1.0"
local MINOR_VERSION = 1
local ADDON_MESSAGE_PREFIX = "PMGuildStorage10"
RegisterAddonMessagePrefix(ADDON_MESSAGE_PREFIX)

local lib, oldMinor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

local GUILDFRAMEVISIBLE = false

local CallbackHandler = LibStub("CallbackHandler-1.0")
if not lib.callbacks then
  lib.callbacks = CallbackHandler:New(lib)
end
local callbacks = lib.callbacks

local AceHook = LibStub("AceHook-3.0")
AceHook:Embed(lib)
lib:UnhookAll()

if lib.frame then
  lib.frame:UnregisterAllEvents()
  lib.frame:SetScript("OnEvent", nil)
  lib.frame:SetScript("OnUpdate", nil)
else
  lib.frame = CreateFrame("Frame", MAJOR_VERSION .. "_Frame")
end
local frame = lib.frame
frame:Show()
frame:SetScript("OnEvent",
function(self, event, ...)
  lib[event](lib, ...)
end)

if ChatThrottleLib then
  SendAddonMessage = function(...)
    ChatThrottleLib:SendAddonMessage(
    "ALERT", ADDON_MESSAGE_PREFIX, ...)
  end
end

local SetState
local initialized
local index
local state = "STALE_WAITING_FOR_ROSTER_UPDATE"
local cache = {}
local pending_note = {}
local guild_info = ""

function lib:GetNote(name)
  local e = cache[name]
  if e then return e.note end
end

function lib:SetNote(name, note)
  local e = cache[name]
  if e then
    if not pending_note[name] then
      pending_note[name] = note
      SetState("FLUSHING")
    end
    return e.note
  end
end

function lib:GetClass(name)
  local e = cache[name]
  if e then return e.class end
end

function lib:GetRank(name)
  local e = cache[name]
  if e then return e.rank end
end

function lib:GetOnline(name)
  local e = cache[name]
  if e then return e.online end
end

function lib:GetGuildInfo()
  return guild_info
end

function lib:IsCurrentState()
  return state == "CURRENT"
end

--
-- Event handlers
--
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

function lib:CHAT_MSG_ADDON(prefix, msg, type, sender)
  if prefix ~= MAJOR_VERSION or sender == UnitName("player") then return end
  if msg == "CHANGES_PENDING" then
    SetState("REMOTE_FLUSHING")
  elseif msg == "CHANGES_FLUSHED" then
    SetState("STALE_WAITING_FOR_ROSTER_UPDATE")
  end
end

function lib:PLAYER_GUILD_UPDATE()
  if IsInGuild() then
    frame:Show()
  else
    frame:Hide()
  end
  SetState("STALE_WAITING_FOR_ROSTER_UPDATE")
end

function lib:PLAYER_ENTERING_WORLD()
  lib:PLAYER_GUILD_UPDATE()
end

function lib:GUILD_ROSTER_UPDATE(loc)
  if loc then
    SetState("FLUSHING")
  else
    if state ~= "UNINITIALIZED" then
      SetState("STALE")
      index = nil
    end
  end
end

--
-- Locally defined functions
--

local valid_transitions = {
  UNINITIALIZED = {
    CURRENT = true,
  },
  STALE = {
    CURRENT = true,
    REMOTE_FLUSHING = true,
    STALE_WAITING_FOR_ROSTER_UPDATE = true,
  },
  STALE_WAITING_FOR_ROSTER_UPDATE = {
    STALE = true,
    FLUSHING = true,
  },
  CURRENT = {
    FLUSHING = true,
    REMOTE_FLUSHING = true,
    STALE = true,
  },
  FLUSHING = {
    STALE_WAITING_FOR_ROSTER_UPDATE = true,
  },
  REMOTE_FLUSHING = {
    STALE_WAITING_FOR_ROSTER_UPDATE = true,
  },
}

function SetState(new_state)
  if state == new_state then return end

  if not valid_transitions[state][new_state] then
    return
  else
    state = new_state
    if new_state == "FLUSHING" then
      SendAddonMessage("CHANGES_PENDING", "GUILD")
    end
    callbacks:Fire("StateChanged")
  end
end

local function ForceShowOffline()
  -- We need to always show offline members in the roster otherwise this
  -- lib won't work.

  if GUILDFRAMEVISIBLE then
    return true
  end

  SetGuildRosterShowOffline(true)

  return false
end

local function Frame_OnUpdate(self, elapsed)
  if ForceShowOffline() then
    return
  end

  if state == "CURRENT" then
    return
  end

  if state == "STALE_WAITING_FOR_ROSTER_UPDATE" then
    GuildRoster()
    return
  end

  local num_guild_members = GetNumGuildMembers()

  -- Sometimes GetNumGuildMembers returns 0. In this case return now,
  -- so that we call it again and get a proper value.
  if num_guild_members == 0 then return end

  if not index or index >= num_guild_members then
    index = 1
  end

  -- Check guild info for changes.
  if index == 1 then
    local new_guild_info = GetGuildInfoText() or ""
    if new_guild_info ~= guild_info then
      guild_info = new_guild_info
      callbacks:Fire("GuildInfoChanged", guild_info)
    end
  end

  -- Read up to 100 members at a time.
  local last_index = mmin(index + 100, num_guild_members)
  if not initialized then last_index = num_guild_members end

  for i = index, last_index do

    local name, rank, _, _, _, _, _, note, online, _, class = GetGuildRosterInfo(i)
    name = Ambiguate(name, "short")

    if name then
      local entry = cache[name]
      local pending = pending_note[name]
      if not entry then
        entry = {}
        cache[name] = entry
      end

      entry.rank = rank
      entry.class = class
      entry.online = online

      -- Mark this note as seen
      entry.seen = true
      if entry.note ~= note then
        entry.note = note
        -- We want to delay all GuildNoteChanged calls until we have a
        -- complete view of the guild, otherwise alts might not be
        -- rejected (we read alts note before we even know about the
        -- main).
        if initialized then
          callbacks:Fire("GuildNoteChanged", name, note)
        end
        if pending then
          callbacks:Fire("InconsistentNote", name, note, entry.note, pending)
        end
      end

      if pending then
        GuildRosterSetOfficerNote(i, pending)
        pending_note[name] = nil
      end
    end
  end
  index = last_index
  if index >= num_guild_members then
    -- We are done, we need to clear the seen marks and delete the
    -- unmarked entries. We also fire events for removed members now.
    for name, t in pairs(cache) do
      if t.seen then
        t.seen = nil
      else
        cache[name] = nil
        callbacks:Fire("GuildNoteDeleted", name)
      end
    end

    if not initialized then
      -- Now make all GuildNoteChanged calls because we have a full
      -- state.
      for name, t in pairs(cache) do
        callbacks:Fire("GuildNoteChanged", name, t.note)
      end
      initialized = true
      callbacks:Fire("StateChanged")
    end
    if state == "STALE" then
      SetState("CURRENT")
    elseif state == "FLUSHING" then
      if not next(pending_note) then
        SetState("STALE_WAITING_FOR_ROSTER_UPDATE")
        SendAddonMessage("CHANGES_FLUSHED", "GUILD")
      end
    end
  end
end

-- Disable updates when the guild roster is open.
-- This is a temporary hack until we get a better location for data storage
lib:RawHook("GuildFrame_LoadUI", function(...)
  SetGuildRosterShowOffline(false)
  lib.hooks.GuildFrame_LoadUI(...)
  lib:RawHookScript(GuildRosterFrame, "OnShow", function(frame, ...)
    GUILDFRAMEVISIBLE = true
    if GuildRosterShowOfflineButton then
      GuildRosterShowOfflineButton:SetChecked(false)
      GuildRosterShowOfflineButton:Enable()
    end
    SetGuildRosterShowOffline(false)
    lib.hooks[frame].OnShow(frame, ...)
  end)
  lib:RawHookScript(GuildRosterFrame, "OnHide", function(frame, ...)
    GUILDFRAMEVISIBLE = false
    lib.hooks[frame].OnHide(frame, ...)
    SetGuildRosterShowOffline(true)
  end)
  lib:Unhook("GuildFrame_LoadUI")

  SetGuildRosterShowOffline(true)
end, true)


ForceShowOffline()
frame:SetScript("OnUpdate", Frame_OnUpdate)
GuildRoster()
