local _G = _G
local _, PM = ...
local DIA = LibStub("LibDialog-1.0")

local strsplit, tostring, hooksecurefunc = _G.strsplit, _G.tostring, _G.hooksecurefunc
local tinsert = _G.table.insert
local TAfter = _G.C_Timer.After
local GetInstanceInfo = _G.GetInstanceInfo

function PM:RCLGetLootData(id, _, _, reason)
  local _, _, difficulty = GetInstanceInfo()
  if difficulty == 16 or PM.Settings.Debug then
    PM.Loot = {PM.RCL:GetModule("RCVotingFrame"):GetLootTable()[id], reason}
    TAfter(0.5, function()
      if not PM.Loot[2] and PM.Loot[1].awarded then
        PM.Loot = PM.Loot[1]
        DIA:Spawn("PMEPGPRewardEdit")
      end
    end)
  end
end

function PM.SetCellPR(_, frame, data, _, _, realrow, column)
  local name = strsplit("-", data[realrow].name)
  local pr = false

  if PM.GuildData[name] and PM.GuildData[name].Main then
    name = PM.GuildData[name].Main
  end

  if PM.GuildData[name] then
    pr = PM:Round(PM.GuildData[name].EP / (PM.GuildData[name].GP + PM.Config.BaseGP), 3)
  end

  if pr then
    if PM.GuildData[name].EP < PM.Config.MinEP then
      frame.text:SetText("|cFF808080"..tostring(pr).."|r")
    else
      frame.text:SetText(tostring(pr))
    end
  else
    frame.text:SetText("?")
  end

  data[realrow].cols[column].value = pr or -1
end

function PM.SortPR(table, rowa, rowb, sortbycol)
  local column = table.cols[sortbycol]
  local direction = column.sort or column.defaultsort or "asc"
  local a, b = table:GetRow(rowa), table:GetRow(rowb)

  local rowA = a.cols[14].value
  local rowB = b.cols[14].value
  local rowAEP = false
  local rowBEP = false
  if rowA ~= -1 then
    local nameA = strsplit("-", a.name)
    rowAEP = PM.GuildData[nameA].EP >= PM.Config.MinEP
  end
  if rowB ~= -1 then
    local nameB = strsplit("-", b.name)
    rowBEP = PM.GuildData[nameB].EP >= PM.Config.MinEP
  end

  if rowA == rowB then
    return false
  else
    if direction:lower() == "asc" then
      if rowAEP and not rowBEP then
        return true
      elseif not rowAEP and rowBEP then
        return false
      else
        return rowA > rowB
      end
    else
      if rowAEP and not rowBEP then
        return false
      elseif not rowAEP and rowBEP then
        return true
      else
        return rowA < rowB
      end
    end
  end
end

function PM:RCLHook()
  PM.RCL = _G.LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil")
  hooksecurefunc(PM.RCL:GetModule("RCLootCouncilML"), "Award", PM.RCLGetLootData)

  PM.RCLVF = PM.RCL:GetModule("RCVotingFrame")
  local pr = {name = "PR", DoCellUpdate = PM.SetCellPR, colName = "pr", width = 50, align = "CENTER", comparesort = PM.SortPR, defaultsort = "dsc"}
  tinsert(PM.RCLVF.scrollCols, pr)
  PM.RCLVF:GetFrame().UpdateSt()
end
