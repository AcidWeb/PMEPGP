local _G = _G
local _, PM = ...

local strsplit, hooksecurefunc, wipe = _G.strsplit, _G.hooksecurefunc, _G.wipe
local IsAddOnLoaded = _G.IsAddOnLoaded

function PM:ExRTParseAttendance(hover, id)
  if hover and _G.PMEPGPFrame:IsVisible() and PM.SBFilter == "CUSTOM" then
    local data = _G.ExRTOptionsFrameRaidAttendance.list.D[id][3]

    wipe(PM.Settings.CustomFilter)
    for i=1, 40 do
      local name = data[i]
      if name then
        name = strsplit("-", name:sub(2))
        name = PM:GetMainName(name)
        if name then
          PM.Settings.CustomFilter[name] = true
        end
      end
    end

    PM:OnArmorValueChange(_, "CUSTOM")
  end
end

function PM:ExRTHook()
  if IsAddOnLoaded("ExRT") then
    hooksecurefunc(_G.GExRT.A.RaidAttendance.options, "Load", function()
      hooksecurefunc(_G.ExRTOptionsFrameRaidAttendance.list, "HoverListValue", PM.ExRTParseAttendance)
    end)
  end
end
