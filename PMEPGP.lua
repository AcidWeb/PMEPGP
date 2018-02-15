local _G = _G
_G.PMEPGPNamespace = {}
local PM = PMEPGPNamespace
local ST = LibStub("ScrollingTable")
local GUI = LibStub("AceGUI-3.0")

--GLOBALS: RAID_CLASS_COLORS, SLASH_PMEPGP1, SLASH_PMEPGP2
local tonumber, tostring, tinsert, strsplit, strmatch, pairs, foreach, mfloor, wipe = _G.tonumber, _G.tostring, _G.tinsert, _G.strsplit, _G.string.match, _G.pairs, _G.foreach, _G.math.floor, _G.wipe
local CanViewOfficerNote = _G.CanViewOfficerNote
local GetNumGuildMembers = _G.GetNumGuildMembers
local GetGuildRosterInfo = _G.GetGuildRosterInfo
local GetGuildInfoText = _G.GetGuildInfoText
local GuildRoster = _G.GuildRoster
local IsInRaid = _G.IsInRaid
local UnitInRaid = _G.UnitInRaid
-- CanEditOfficerNote()
-- GuildRosterSetOfficerNote(index, "note")

PM.Version = 10
PM.GuildData = {}
PM.TableData = {}
PM.AltCache = {}
PM.Config = {["BaseGP"] = 1, ["Decay"] = 0, ["MinEP"] = 0, ["EAM"] = 100}
PM.SBFilter = "ALL"
PM.IsInRaid = false
SLASH_PMEPGP1 = "/pmepgp"
SLASH_PMEPGP2 = "/ep"

PM.Armors = {
	["CLOTH"] = {["MAGE"] = true, ["PRIEST"] = true, ["WARLOCK"] = true},
	["LEATHER"] = {["DEMONHUNTER"] = true, ["DRUID"] = true, ["MONK"] = true, ["ROGUE"] = true},
	["MAIL"] = {["HUNTER"] = true, ["SHAMAN"] = true},
	["PLATE"] = {["DEATHKNIGHT"] = true, ["PALADIN"] = true, ["WARRIOR"] = true},
}
PM.ScoreBoardStructure = {
	{
		["name"] = "Name",
		["width"] = 150,
		["comparesort"] = function (self, rowa, rowb, sortbycol) return PM:CustomSort(self, rowa, rowb, sortbycol, 5) end,
		["bgcolor"] = {
			["r"] = 0.15,
			["g"] = 0.15,
			["b"] = 0.15,
			["a"] = 1.0
		},
		["align"] = "LEFT"
	},
	{
		["name"] = "EP",
		["width"] = 50,
		["align"] = "CENTER"
	},
	{
		["name"] = "GP",
		["width"] = 50,
		["bgcolor"] = {
			["r"] = 0.15,
			["g"] = 0.15,
			["b"] = 0.15,
			["a"] = 1.0
		},
		["align"] = "CENTER"
	},
	{
		["name"] = "PR",
		["width"] = 50,
		["comparesort"] = function (self, rowa, rowb, sortbycol) return PM:CustomPRSort(self, rowa, rowb, sortbycol) end,
		["color"] = function (self, _, realrow, _, table) return PM:GetPRColor(realrow, table) end,
		["align"] = "CENTER"
	},
}

-- Event functions

function PM:OnLoad(self)
	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
	self:RegisterForDrag("LeftButton")

	tinsert(_G.UISpecialFrames, "PMEPGP")
	_G.PMEPGP_Title:SetText("PM EPGP "..tostring(PM.Version):gsub(".", "%1."):sub(1,-2))
	_G.BINDING_HEADER_PMEPGPB = "|cFFF2E699PM|r EPGP"
	_G.BINDING_NAME_PMEPGPOPEN = "Show main window"

	_G.SlashCmdList["PMEPGP"] = function()
		if not _G.PMEPGP:IsVisible() then
			_G.PMEPGP:Show()
		else
			_G.PMEPGP:Hide()
		end
	end

	PM.ModeButton = GUI:Create("Button")
	PM.ModeButton.frame:SetParent(_G.PMEPGP)
	PM.ModeButton.frame:SetPoint("BOTTOMRIGHT", _G.PMEPGP, "BOTTOMRIGHT", -15, 14)
	PM.ModeButton:SetWidth(100)
	PM.ModeButton:SetCallback("OnClick", function() PM:UpdateGUI(true) end)
	PM.ModeButton.frame:Show()
	PM.MassEPButton = GUI:Create("Button")
	PM.MassEPButton.frame:SetParent(_G.PMEPGP)
	PM.MassEPButton.frame:SetPoint("BOTTOMLEFT", _G.PMEPGP, "BOTTOMLEFT", 15, 14)
	PM.MassEPButton:SetWidth(100)
	PM.MassEPButton:SetText("Mass EP")
	PM.MassEPButton.frame:Show()
	PM.ArmorDropdown = GUI:Create("Dropdown")
	PM.ArmorDropdown.frame:SetParent(_G.PMEPGP)
	PM.ArmorDropdown.frame:SetPoint("BOTTOM", _G.PMEPGP, "BOTTOM", 0, 14)
	PM.ArmorDropdown:SetWidth(100)
	PM.ArmorDropdown:SetList({["ALL"] = "All", ["CLOTH"] = "Cloth", ["LEATHER"] = "Leather", ["MAIL"] = "Mail", ["PLATE"] = "Plate"})
	PM.ArmorDropdown:SetValue("ALL")
	PM.ArmorDropdown:SetCallback("OnValueChanged", PM.OnArmorChange)
	PM.ArmorDropdown.frame:Show()
end

function PM:OnEvent(self, event, name, ...)
	if event == "ADDON_LOADED" and name == "PMEPGP" then
		GuildRoster()
		PM.ScoreBoard = ST:CreateST(PM.ScoreBoardStructure, 30, nil, nil, _G.PMEPGP)
		PM.ScoreBoard.frame:SetPoint("TOPLEFT", _G.PMEPGP, "TOPLEFT", 17, -40)
	elseif event == "GUILD_ROSTER_UPDATE" then
		local guildinfo = {strsplit("\n", GetGuildInfoText())}
		local block = false
		if #guildinfo > 0 then
			for _, line in pairs(guildinfo) do
				if line == "-EPGP-" then
					block = not block
				elseif block then
					line = {strsplit(":", line)}
					line[2] = tonumber(line[2])
					if line[2] then
						if line[1] == "@BASE_GP" then
							PM.Config.BaseGP = line[2]
						elseif line[1] == "@DECAY_P" then
							PM.Config.Decay = line[2]
						elseif line[1] == "@MIN_EP" then
							PM.Config.MinEP = line[2]
						elseif line[1] == "@EXTRAS_P" then
							PM.Config.EAM = line[2]
						end
					end
				end
			end
		end
	end
end

-- Main functions

function PM:UpdateGUI(override)
	if override then
		PM.IsInRaid = not PM.IsInRaid
	else
		PM.IsInRaid = IsInRaid()
	end
	if PM.IsInRaid then
		PM.ModeButton:SetText("Raid")
	else
		PM.ModeButton:SetText("Guild")
	end
	PM:GetGuildData()
	PM:GetScoreBoardData()
	if #PM.ScoreBoard.data == 0 then
		PM.ScoreBoard.cols[4].sort = "asc"
	end
	PM.ScoreBoard:SetData(PM.TableData, true)
	PM.ScoreBoard:SetFilter(PM.ScoreBoardFilter)
end

function PM:GetGuildData()
	wipe(PM.GuildData)
	wipe(PM.AltCache)

	if not CanViewOfficerNote() then
		return
	end

	for i=1, GetNumGuildMembers() do
		local name, _, _, _, _, _, _, note, _, _, class = GetGuildRosterInfo(i)
		local ep, gp = strmatch(note, "^(%d+),(%d+)$")
		name = strsplit("-", name)
		if ep then
			PM.GuildData[name] = {["Class"] = class, ["EP"] = tonumber(ep), ["GP"] = tonumber(gp), ["Alts"] = {}}
		elseif note ~= "" then
			tinsert(PM.AltCache, {name, note, class})
		end
	end

	for i=1, #PM.AltCache do
		if PM.GuildData[PM.AltCache[i][2]] then
			tinsert(PM.GuildData[PM.AltCache[i][2]].Alts, PM.AltCache[i][1])
			PM.GuildData[PM.AltCache[i][1]] = {["Class"] = PM.AltCache[i][3], ["Main"] = PM.AltCache[i][2]}
		end
	end
end

function PM:GetScoreBoardData()
	wipe(PM.TableData)

	foreach(PM.GuildData, function(n, d)
		if not d.Main and d.EP > 0 then
			tinsert(PM.TableData, {PM:GetNameScoreboard(n),
			d.EP,
			d.GP + PM.Config.BaseGP,
			PM:Round(d.EP / (d.GP + PM.Config.BaseGP), 2),
			n,
			d.Class})
		end
	end)
end

-- Support functions

function PM:GetNameScoreboard(name)
	local nstr = "|c"..RAID_CLASS_COLORS[PM.GuildData[name].Class].colorStr..name.."|r"
	if #PM.GuildData[name].Alts > 0 then
		nstr = nstr.." |cFF808080(|r"
		for i=1, #PM.GuildData[name].Alts do
			nstr = nstr.."|c"..RAID_CLASS_COLORS[PM.GuildData[PM.GuildData[name].Alts[i]].Class].colorStr..PM.GuildData[name].Alts[i].."|r|cFF808080,|r "
		end
		nstr = nstr:sub(1, -15).."|cFF808080)|r"
	end
	return nstr
end

function PM:GetPRColor(realrow, table)
	if PM.GuildData[table.data[realrow][5]].EP < PM.Config.MinEP then
		return {["r"] = 0.5,
		["g"] = 0.5,
		["b"] = 0.5,
		["a"] = 1.0}
	else
		return {["r"] = 1.0,
		["g"] = 1.0,
		["b"] = 1.0,
		["a"] = 1}
	end
end

function PM:ScoreBoardFilter(rowdata)
	local raidFilter = false
	if PM.IsInRaid then
		if UnitInRaid(rowdata[5]) then
			raidFilter = true
		else
			foreach(PM.GuildData[rowdata[5]].Alts, function(_, alt)
				if UnitInRaid(alt) then
					raidFilter = true
				end
			end)
		end
	else
		raidFilter = true
	end
	if PM.SBFilter == "ALL" or PM.Armors[PM.SBFilter][rowdata[6]] then
		return raidFilter and true
	else
		return false
	end
end

function PM:CustomSort(obj, rowa, rowb, sortbycol, inside)
	local column = obj.cols[sortbycol]
	local direction = column.sort or column.defaultsort or "asc"
	local rowA = obj.data[rowa][inside]
	local rowB = obj.data[rowb][inside]
	if rowA == rowB then
		return false
	else
		if direction:lower() == "asc" then
			return rowA > rowB
		else
			return rowA < rowB
		end
	end
end

function PM:CustomPRSort(obj, rowa, rowb, sortbycol)
	local column = obj.cols[sortbycol]
	local direction = column.sort or column.defaultsort or "asc"
	local rowA = obj.data[rowa][4]
	local rowB = obj.data[rowb][4]
	local rowAEP = obj.data[rowa][2] >= PM.Config.MinEP
	local rowBEP = obj.data[rowb][2] >= PM.Config.MinEP
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

function PM:OnArmorChange(_, armor)
	PM.SBFilter = armor
	PM.ScoreBoard:SetFilter(PM.ScoreBoardFilter)
end

function PM:Round(num, idp)
	local mult = 10^(idp or 0)
	return mfloor(num * mult + 0.5) / mult
end
