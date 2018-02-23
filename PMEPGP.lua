local _G = _G
_G.PMEPGPNamespace = {}
local PM = PMEPGPNamespace
local ST = LibStub("ScrollingTable")
local GUI = LibStub("AceGUI-3.0")
local COM = LibStub("AceComm-3.0")
local SER = LibStub("AceSerializer-3.0")
local DIA = LibStub("LibDialog-1.0")
local DUMP = LibStub("LibTextDump-1.0")

--GLOBALS: RAID_CLASS_COLORS, SLASH_PMEPGP1, SLASH_PMEPGP2, PMEPGP_AlertSystemTemplate, PMEPGP_Flogging
local tonumber, tostring, pairs, type, print, date, time, unpack = _G.tonumber, _G.tostring, _G.pairs, _G.type, _G.print, _G.date, _G.time, _G.unpack
local tinsert, tconcat, tsort = _G.table.insert, _G.table.concat, _G.table.sort
local strsplit, strmatch = _G.string.split, _G.string.match
local mfloor = _G.math.floor
local TAfter = _G.C_Timer.After
local CanViewOfficerNote = _G.CanViewOfficerNote
local CanEditOfficerNote = _G.CanEditOfficerNote
local GetNumGuildMembers = _G.GetNumGuildMembers
local GetNumGroupMembers = _G.GetNumGroupMembers
local GetGuildRosterInfo = _G.GetGuildRosterInfo
local GetGuildInfoText = _G.GetGuildInfoText
local GetRaidRosterInfo = _G.GetRaidRosterInfo
local GetZoneText = _G.GetZoneText
local GetServerTime = _G.GetServerTime
local GuildRosterSetOfficerNote = _G.GuildRosterSetOfficerNote
local GuildRoster = _G.GuildRoster
local SendChatMessage = _G.SendChatMessage
local IsInRaid = _G.IsInRaid
local IsAddOnLoaded = _G.IsAddOnLoaded
local UnitName = _G.UnitName
local UnitInRaid = _G.UnitInRaid
local PlaySound = _G.PlaySound

PM.Version = 100
PM.GuildData = {}
PM.TableData = {}
PM.TableIndex = {}
PM.LogIndex = {}
PM.Reserve = {}
PM.Config = {["BaseGP"] = 1, ["Decay"] = 0, ["MinEP"] = 0, ["EAM"] = 100}
PM.DefaultSettings = {["Log"] = {}, ["Backup"] = {}}
PM.SBFilter = "ALL"
PM.ClickedPlayer = ""
PM.DialogSwitch = "EP"
PM.IsInRaid = false
PM.IsOfficer = false
PM.PlayerName = UnitName("player")
SLASH_PMEPGP1 = "/pmepgp"
SLASH_PMEPGP2 = "/ep"

PM.OfficerDropDown = {
	{ text = "Mass EP", notCheckable = true, func = function() DIA:Spawn("PMEPGPMassEdit"); _G.L_CloseDropDownMenus() end },
	{ text = "Decay", notCheckable = true, func = function() DIA:Spawn("PMEPGPDecayWarning"); _G.L_CloseDropDownMenus() end },
	{ text = "Logs", notCheckable = true, func = function() PM:ShowLogs(); _G.L_CloseDropDownMenus() end },
	{ text = "Fill reserve", notCheckable = true, func = function() PM:FillReserve(); _G.L_CloseDropDownMenus() end },
	{ text = "Check notes", notCheckable = true, func = function() PM:CheckNotes(); _G.L_CloseDropDownMenus() end },
	{ text = "Setup notes", notCheckable = true, func = function() PM:SetNotes(); _G.L_CloseDropDownMenus() end },
}
PM.PlayerDropDown = {
	{ text = "Edit points", notCheckable = true, func = function() DIA:Spawn("PMEPGPPlayerEdit", PM.ClickedPlayer); _G.L_CloseDropDownMenus() end },
	{ text = "Toggle reserve status", notCheckable = true, func = function() PM:AddToReserve(PM.ClickedPlayer); _G.L_CloseDropDownMenus() end },
	{ text = "Slap", notCheckable = true, func = function() PM:EditPoints(PM.ClickedPlayer, "EP", -50, "*slap*"); _G.L_CloseDropDownMenus() end },
}
PM.Armors = {
	["CLOTH"] = {["MAGE"] = true, ["PRIEST"] = true, ["WARLOCK"] = true},
	["LEATHER"] = {["DEMONHUNTER"] = true, ["DRUID"] = true, ["MONK"] = true, ["ROGUE"] = true},
	["MAIL"] = {["HUNTER"] = true, ["SHAMAN"] = true},
	["PLATE"] = {["DEATHKNIGHT"] = true, ["PALADIN"] = true, ["WARRIOR"] = true},
	["CONQUEROR"] = {["DEMONHUNTER"] = true, ["PRIEST"] = true, ["PALADIN"] = true, ["WARLOCK"] = true},
	["PROTECTOR"] = {["WARRIOR"] = true, ["HUNTER"] = true, ["SHAMAN"] = true, ["MONK"] = true},
	["VANQUISHER"] = {["MAGE"] = true, ["ROGUE"] = true, ["DEATHKNIGHT"] = true, ["DRUID"] = true},
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
		["color"] = function (_, _, realrow, _, table) return PM:GetPRColor(realrow, table) end,
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
end

function PM:OnEvent(self, event, name)
	if event == "ADDON_LOADED" and name == "PMEPGP" then
		if not _G.PMEPGPDB then _G.PMEPGPDB = PM.DefaultSettings end
		PM.Settings = _G.PMEPGPDB
		PM.IsOfficer = PM.Settings.Debug or CanEditOfficerNote()
		PM.AS = unpack(_G.AddOnSkins)
		for key, value in pairs(PM.DefaultSettings) do
			if PM.Settings[key] == nil then
				PM.Settings[key] = value
			end
		end
		for t, _ in pairs(PM.Settings.Log) do
			tinsert(PM.LogIndex, t)
		end
		GuildRoster()

		PM.ModeButton = GUI:Create("Button")
		PM.ModeButton.frame:SetParent(_G.PMEPGP)
		PM.ModeButton.frame:SetPoint("BOTTOMRIGHT", _G.PMEPGP, "BOTTOMRIGHT", -15, 14)
		PM.ModeButton:SetWidth(100)
		PM.ModeButton:SetCallback("OnClick", function() PM:UpdateGUI(true) end)
		PM.ModeButton.frame:Show()
		PM.OfficerButton = GUI:Create("Button")
		PM.OfficerButton.frame:SetParent(_G.PMEPGP)
		PM.OfficerButton.frame:SetPoint("BOTTOMLEFT", _G.PMEPGP, "BOTTOMLEFT", 15, 14)
		PM.OfficerButton:SetWidth(100)
		PM.OfficerButton:SetCallback("OnClick", function() PM:OnClickOfficerButton() end)
		PM.OfficerButton.frame:Show()
		PM.ArmorDropdown = GUI:Create("Dropdown")
		PM.ArmorDropdown.frame:SetParent(_G.PMEPGP)
		PM.ArmorDropdown.frame:SetPoint("BOTTOM", _G.PMEPGP, "BOTTOM", 0, 14)
		PM.ArmorDropdown:SetWidth(100)
		PM.ArmorDropdown:SetList({["ALL"] = "All", ["CLOTH"] = "Cloth", ["LEATHER"] = "Leather", ["MAIL"] = "Mail", ["PLATE"] = "Plate", ["CONQUEROR"] = "Conqueror", ["PROTECTOR"] = "Protector", ["VANQUISHER"] = "Vanquisher"},
		{"ALL", "CLOTH", "LEATHER", "MAIL", "PLATE", "CONQUEROR", "PROTECTOR", "VANQUISHER"})
		PM.ArmorDropdown:SetValue("ALL")
		PM.ArmorDropdown:SetCallback("OnValueChanged", PM.OnArmorValueChange)
		PM.ArmorDropdown.frame:Show()
		PM.ScoreBoard = ST:CreateST(PM.ScoreBoardStructure, 30, nil, nil, _G.PMEPGP)
		PM.ScoreBoard.frame:SetPoint("TOPLEFT", _G.PMEPGP, "TOPLEFT", 17, -40)
		PM.AlertSystem = _G.AlertFrame:AddSimpleAlertFrameSubSystem("PMEPGP_Alert", _G.PMEPGP_AlertSystemTemplate)
		PM.DumpFrame = DUMP:New("PM EPGP - Logs", nil, 540)
		if PM.IsOfficer then
			PM.OfficerButton:SetText("Officer tools")
		else
			PM.OfficerButton:SetText("Logs")
		end

		if IsAddOnLoaded("ElvUI") and IsAddOnLoaded("AddOnSkins") then
			PM.AS:SkinFrame(_G.PMEPGP)
			PM.AS:SkinFrame(PM.ScoreBoard.frame, nil, true)
			PM.AS:StripTextures(_G[PM.ScoreBoard.frame:GetName()..'ScrollTrough'], true)
			PM.AS:SkinScrollBar(_G[PM.ScoreBoard.frame:GetName()..'ScrollFrameScrollBar'])
			PM.AS:SkinCloseButton(_G.PMEPGP_CloseButton)
			PM.ArmorDropdown.frame:ClearAllPoints()
			PM.ModeButton.frame:ClearAllPoints()
			PM.OfficerButton.frame:ClearAllPoints()
			PM.ArmorDropdown.frame:SetPoint("BOTTOM", _G.PMEPGP, "BOTTOM", 0, 8)
			PM.ModeButton.frame:SetPoint("BOTTOMRIGHT", _G.PMEPGP, "BOTTOMRIGHT", -15, 10)
			PM.OfficerButton.frame:SetPoint("BOTTOMLEFT", _G.PMEPGP, "BOTTOMLEFT", 15, 10)
			_G.PMEPGP_Title:ClearAllPoints()
			_G.PMEPGP_Title:SetPoint("BOTTOM", _G.PMEPGP, "TOP", 0, -20)
		end

		PM.ScoreBoard:RegisterEvents({
			["OnClick"] = function (_, _, data, _, _, realRow, _, _, button, _)
				if PM.IsOfficer and (button == "LeftButton" or button == "RightButton") and realRow ~= nil then
					PM.ClickedPlayer = data[realRow][5]
					_G.L_CloseDropDownMenus()
					_G.L_EasyMenu(PM.PlayerDropDown, _G.PMEPGP_DropDown, "cursor", 0 , 0, "MENU")
				end
			end,
		})

		DIA:Register("PMEPGPPlayerEdit", {
			static_size = true,
			width = 300,
			height = 175,
			hide_on_escape = true,
			is_exclusive = true,
			on_show = function(self)
				local classcolor = RAID_CLASS_COLORS[PM.GuildData[self.data].Class]
				self.text:SetText(self.data)
				self.text:SetTextColor(classcolor.r, classcolor.g, classcolor.b, 1)
				self.checkboxes[2]:ClearAllPoints()
				self.checkboxes[2]:SetPoint("TOPRIGHT", self.editboxes[2], "BOTTOMRIGHT", -4, 0)
				self.editboxes[1]:SetText(GetZoneText())
				if IsAddOnLoaded("ElvUI") and IsAddOnLoaded("AddOnSkins") then
					PM.AS:SkinFrame(self)
					PM.AS:SkinCloseButton(self.close_button)
					PM.AS:SkinButton(self.buttons[1])
					PM.AS:SkinButton(self.buttons[2])
					PM.AS:SkinCheckBox(self.checkboxes[1])
					PM.AS:SkinCheckBox(self.checkboxes[2])
					PM.AS:SkinFrame(self.editboxes[1])
					PM.AS:SkinFrame(self.editboxes[2])
				end
			end,
			buttons = {
				{
					text = "Save",
					on_click = function(self)
						local member = self.data
						local value = tonumber(self.editboxes[2]:GetText())
						local reason = self.editboxes[1]:GetText()
						local mode = PM.DialogSwitch
						if value then
							PM:EditPoints(member, mode, value, reason)
							return false
						else
							print("|cFFF2E699[PM EPGP]|r The value must be a number!")
							return true
						end
					end,
				},
				{
					text = "Cancel",
				},
			},
			editboxes = {
				{
					label = "Reason",
					width = 150,
				},
				{
					label = "Value",
					width = 150,
				},
			},
			checkboxes = {
				{
					label = "EP",
					set_value = function(self)
						if PM.DialogSwitch ~= "EP" then
							self:GetParent():GetParent().checkboxes[2]:SetChecked(not self:GetParent():GetParent().checkboxes[2]:GetChecked())
						end
						PM.DialogSwitch = "EP"
					end,
					get_value = function(_)
						return PM.DialogSwitch == "EP"
					end,
				},
				{
					label = "GP",
					set_value = function(self)
						if PM.DialogSwitch ~= "GP" then
							self:GetParent():GetParent().checkboxes[1]:SetChecked(not self:GetParent():GetParent().checkboxes[1]:GetChecked())
						end
						PM.DialogSwitch = "GP"
					end,
					get_value = function(_)
						return PM.DialogSwitch == "GP"
					end,
				},
			},
		})
		DIA:Register("PMEPGPMassEdit", {
			static_size = true,
			width = 300,
			height = 225,
			hide_on_escape = true,
			is_exclusive = true,
			text = "All players currently displayed in main window will be affected with this operation.",
			on_show = function(self)
				self.text:SetTextColor(1, 1, 1, 1)
				self.editboxes[1]:SetText(GetZoneText())
				self.checkboxes[1]:SetChecked(false)
				self.checkboxes[2]:SetChecked(false)
				if IsAddOnLoaded("ElvUI") and IsAddOnLoaded("AddOnSkins") then
					PM.AS:SkinFrame(self)
					PM.AS:SkinCloseButton(self.close_button)
					PM.AS:SkinButton(self.buttons[1])
					PM.AS:SkinButton(self.buttons[2])
					PM.AS:SkinCheckBox(self.checkboxes[1])
					PM.AS:SkinCheckBox(self.checkboxes[2])
					PM.AS:SkinFrame(self.editboxes[1])
					PM.AS:SkinFrame(self.editboxes[2])
				end
			end,
			buttons = {
				{
					text = "Save",
					on_click = function(self)
						local value = tonumber(self.editboxes[2]:GetText())
						local reason = self.editboxes[1]:GetText()
						local fill = self.checkboxes[1]:GetChecked()
						local award = self.checkboxes[2]:GetChecked()
						if value then
							PM:EditMassPoints(value, reason, fill, award)
							self.checkboxes[1]:SetChecked(false)
							self.checkboxes[2]:SetChecked(false)
							return false
						else
							print("|cFFF2E699[PM EPGP]|r The value must be a number!")
							return true
						end
					end,
				},
				{
					text = "Cancel",
				},
			},
			editboxes = {
				{
					label = "Reason",
					width = 150,
				},
				{
					label = "Value",
					width = 150,
				},
			},
			checkboxes = {
				{
					label = "Automatically fill reserve list",
					get_value = function(self)
						if self:GetParent():GetParent().checkboxes[2] and self:GetChecked() then
							self:GetParent():GetParent().checkboxes[2]:SetChecked(false)
						end
						return not not self:GetChecked()
					end,
				},
				{
					label = "Award players on reserve list",
					get_value = function(self)
						if self:GetParent():GetParent().checkboxes[1] and self:GetChecked() then
							self:GetParent():GetParent().checkboxes[1]:SetChecked(false)
						end
						return not not self:GetChecked()
					end,
				},
			},
		})
		DIA:Register("PMEPGPDecayWarning", {
			static_size = true,
			width = 300,
			height = 75,
			hide_on_escape = true,
			is_exclusive = true,
			no_close_button = true,
			on_show = function(self)
				self.text:SetText("Are you sure you want to execute "..tostring(PM.Config.Decay).."% decay?")
				self.text:SetTextColor(1, 1, 1, 1)
				if IsAddOnLoaded("ElvUI") and IsAddOnLoaded("AddOnSkins") then
					PM.AS:SkinFrame(self)
					PM.AS:SkinButton(self.buttons[1])
					PM.AS:SkinButton(self.buttons[2])
				end
			end,
			buttons = {
				{
					text = "Yes",
					on_click = function(_)
						PM:EditPointsDecay()
					end,
				},
				{
					text = "No",
				},
			},
		})

		COM:RegisterComm("PMEPGP", PM.OnAddonMsg)
		COM:SendCommMessage("PMEPGP", SER:Serialize("V;"..PM.Version), "GUILD", nil, "NORMAL")
		self:UnregisterEvent("ADDON_LOADED")
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

function PM:OnAddonMsg(...)
	local msg, _, sender = ...
	local status, msg = SER:Deserialize(msg)

	if status then
		msg = {strsplit(";", msg)}
		if tonumber(msg[2]) == PM.Version then
			if msg[1] == "A" then
				PM.AlertSystem:AddAlert({msg[3], tonumber(msg[4])})
			elseif msg[1] == "L" and sender ~= PM.PlayerName then
				local t = tonumber(msg[3]) + 10
				if not PM.Settings.Log[t] then
					PM.Settings.Log[t] = msg[4]
					tinsert(PM.LogIndex, t)
					if _G.PMEPGP:IsVisible() then PM:UpdateGUI() end
				end
			end
		elseif tonumber(msg[2]) > PM.Version then
			print("|cFFF2E699[PM EPGP]|r Addon is out-of-date!")
		end
	end
end

function PM:OnClickOfficerButton()
	_G.L_CloseDropDownMenus()
	if PM.IsOfficer then
		_G.L_EasyMenu(PM.OfficerDropDown, _G.PMEPGP_DropDown, "cursor", 0 , 0, "MENU")
	else
		PM:ShowLogs()
	end
end

function PM:OnArmorValueChange(_, armor)
	_G.L_CloseDropDownMenus()
	PM.SBFilter = armor
	PM.ScoreBoard:SetFilter(PM.ScoreBoardFilter)
end

function PM:OnHyperLinkEnter(linkData, _)
	_G.GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	_G.GameTooltip:SetHyperlink(linkData)
	_G.GameTooltip:Show()
end

function PM:OnHyperLinkLeave()
	_G.GameTooltip:Hide()
end

-- Main functions

function PM:UpdateGUI(override)
	_G.L_CloseDropDownMenus()
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
	if not CanViewOfficerNote() then return end

	local altcache = {}
	for n, _ in pairs(PM.GuildData) do
		PM.GuildData[n].Active = false
	end

	for i=1, GetNumGuildMembers() do
		local name, _, _, _, _, _, _, note, online, _, class = GetGuildRosterInfo(i)
		local ep, gp = strmatch(note, "^(%d+),(%d+)$")
		name = strsplit("-", name)
		if ep then
			if PM.GuildData[name] then
				local entry = PM.GuildData[name]
				entry.EP = tonumber(ep)
				entry.GP = tonumber(gp)
				entry.Alts = {}
				entry.ID = i
				entry.Online = online
				entry.Active = true
			else
				PM.GuildData[name] = {["Class"] = class, ["EP"] = tonumber(ep), ["GP"] = tonumber(gp), ["Alts"] = {}, ["ID"] = i, ["Online"] = online, ["Active"] = true}
			end
		elseif note ~= "" then
			tinsert(altcache, {name, note, class})
		end
	end

	for i=1, #altcache do
		if PM.GuildData[altcache[i][2]] and PM.GuildData[altcache[i][2]].Active then
			tinsert(PM.GuildData[altcache[i][2]].Alts, altcache[i][1])
			if PM.GuildData[altcache[i][1]] then
				PM.GuildData[altcache[i][1]].Main = altcache[i][2]
				PM.GuildData[altcache[i][1]].Active = true
			else
				PM.GuildData[altcache[i][1]] = {["Class"] = altcache[i][3], ["Main"] = altcache[i][2], ["Active"] = true}
			end
		end
	end
end

function PM:GetScoreBoardData()
	for i=1, #PM.TableData do
		local entry = PM.TableIndex[PM.TableData[i][5]]
		if not entry then
			PM.TableIndex[PM.TableData[i][5]] = i
		end
		PM.TableData[i][7] = false
	end

	for n, d in pairs(PM.GuildData) do
		if d.Active and not d.Main then
			if PM.TableIndex[n] then
				local entry = PM.TableData[PM.TableIndex[n]]
				entry[1] = PM:GetNameScoreboard(n)
				entry[2] = d.EP
				entry[3] = d.GP + PM.Config.BaseGP
				entry[4] = PM:Round(d.EP / (d.GP + PM.Config.BaseGP), 2)
				entry[7] = true
			else
				tinsert(PM.TableData, {PM:GetNameScoreboard(n),
				d.EP,
				d.GP + PM.Config.BaseGP,
				PM:Round(d.EP / (d.GP + PM.Config.BaseGP), 2),
				n,
				d.Class,
				true})
			end
		end
	end
end

function PM:ShowLogs()
	PM.DumpFrame:Clear()

	tsort(PM.LogIndex, function (a, b) return a > b end)
	for i=1, #PM.LogIndex do
		local status, payload = SER:Deserialize(PM.Settings.Log[PM.LogIndex[i]])
		local t = PM.LogIndex[i]
		local members = ""
		local points = ""
		local from = ""

		if status then
			if PM.GuildData[payload[5]] then
				from = "|c"..RAID_CLASS_COLORS[PM.GuildData[payload[5]].Class].colorStr..payload[5].."|r"
			else
				from = payload[5]
			end
			if payload[2] == "DECAY" then
				PM.DumpFrame:AddLine("["..date("%H:%M %d.%m.%y", t).."] |cFFFF0000DECAY "..payload[3].."%|r || "..from)
				PM.DumpFrame:AddLine(" ")
			else
				for i=1, #payload[1] do
					if PM.GuildData[payload[1][i]] then
						members = members.."|c"..RAID_CLASS_COLORS[PM.GuildData[payload[1][i]].Class].colorStr..payload[1][i].."|r, "
					else
						members = members..payload[1][i]..", "
					end
				end
				members = members:sub(1, -3)
				if payload[2] == "GP" then
					if tonumber(payload[3]) > 0 then
						points = "|cFFFF0000+"..payload[3].." "..payload[2].."|r"
					else
						points = "|cFF00FF00"..payload[3].." "..payload[2].."|r"
					end
				else
					if tonumber(payload[3]) > 0 then
						points = "|cFF00FF00+"..payload[3].." "..payload[2].."|r"
					else
						points = "|cFFFF0000"..payload[3].." "..payload[2].."|r"
					end
				end
				PM.DumpFrame:AddLine("["..date("%H:%M %d.%m.%y", t).."] "..members.." || "..points.." || "..payload[4].." || "..from)
				PM.DumpFrame:AddLine(" ")
			end
		end
	end

	if PM.DumpFrame:Lines() == 0 then
		PM.DumpFrame:AddLine(" ")
	end
	PM.DumpFrame:Display()

	PM.DumpFrameInternal = DUMP.frames[PM.DumpFrame]
	PM.DumpFrameInternal:ClearAllPoints()
	PM.DumpFrameInternal:SetPoint("LEFT", _G.PMEPGP, "RIGHT", 10, 0)
	PM.DumpFrameInternal.edit_box:Disable()
	PM.DumpFrameInternal.edit_box:SetHyperlinksEnabled(true)
	PM.DumpFrameInternal.edit_box:SetScript("OnHyperlinkEnter", PM.OnHyperLinkEnter)
	PM.DumpFrameInternal.edit_box:SetScript("OnHyperlinkLeave", PM.OnHyperLinkLeave)

	if IsAddOnLoaded("ElvUI") and IsAddOnLoaded("AddOnSkins") then
		PM.AS:SkinFrame(PM.DumpFrameInternal)
		PM.AS:SkinFrame(PM.DumpFrameInternal.Inset)
		PM.AS:SkinCloseButton(PM.DumpFrameInternal.CloseButton)
		PM.AS:SkinScrollBar(PM.DumpFrameInternal.scrollArea.ScrollBar)
	end
end

-- Support functions

function PM:SaveToLog(members, mode, value, reason, who)
	if not PM.IsOfficer then return end

	local t = time(date('!*t', GetServerTime()))
	if type(members) ~= "table" then
		members = {members}
	end

	local cmembers = members[1]
	local cvalue = value
	if #members > 1 then cmembers = #members.." players" end
	if cvalue > 0 then cvalue = "+"..cvalue end
	if mode == "DECAY" then
		SendChatMessage("[PM EPGP] "..PM.Config.Decay.."% Decay", "GUILD")
	else
		SendChatMessage("[PM EPGP] "..cmembers.." || "..cvalue.." "..mode.." || "..reason, "GUILD")
	end

	local payload = SER:Serialize({members, mode, value, reason, who})
	COM:SendCommMessage("PMEPGP", SER:Serialize("L;"..PM.Version..";"..t..";"..payload), "GUILD", nil, "BULK")
	PM.Settings.Log[t] = payload
	tinsert(PM.LogIndex, t)
end

function PM:CheckNotes()
	local nonote = {}
	local badnote = {}
	local altcache = {}

	if not PM.IsOfficer then return end

	for i=1, GetNumGuildMembers() do
		local name, _, _, _, _, _, _, note = GetGuildRosterInfo(i)
		local ep, _ = strmatch(note, "^(%d+),(%d+)$")
		name = strsplit("-", name)
		if not note or note == "" then
			tinsert(nonote, name)
		elseif note ~= "" and not ep then
			tinsert(altcache, {name, note})
		end
	end

	for i=1, #altcache do
		if not PM.GuildData[altcache[i][2]] then
			tinsert(badnote, altcache[i][1])
		end
	end

	print("|cFFF2E699[PM EPGP]|r Empty note:")
	print(tconcat(nonote, ", "))
	print("|cFFF2E699[PM EPGP]|r Corrupted note:")
	print(tconcat(badnote, ", "))
end

function PM:SetNotes()
	if not PM.IsOfficer then return end

	print("|cFFF2E699[PM EPGP]|r Added note:")
	for i=1, GetNumGuildMembers() do
		local name, _, _, _, _, _, _, note = GetGuildRosterInfo(i)
		name = strsplit("-", name)
		if not note or note == "" then
			GuildRosterSetOfficerNote(i, "0,0")
			print(name)
		end
	end
end

function PM:EditPoints(members, mode, value, reason, rewardedid)
	if not PM.IsOfficer then return end
	local success = false
	local rewarded = {}
	local rewardedid = rewardedid or {}

	if type(members) ~= "table" then
		members = {members}
	end
	PM:GetGuildData()

	for i=1, #members do
		if PM.GuildData[members[i]] and PM.GuildData[members[i]].Active then
			local player = PM.GuildData[members[i]]
			local wtarget = members[i]
			if player.Main then
				player = PM.GuildData[player.Main]
			end
			if player and player.Active and not rewardedid[player.ID] then
				if mode == "EP" then
					player.EP = player.EP + value
				elseif mode == "GP" then
					player.GP = player.GP + value
				end
				if player.EP < 0 then player.EP = 0 end
				if player.GP < 0 then player.GP = 0 end
				success = true
				tinsert(rewarded, members[i])
				rewardedid[player.ID] = true
				GuildRosterSetOfficerNote(player.ID, player.EP..","..player.GP)
				if player.Online then
					COM:SendCommMessage("PMEPGP", SER:Serialize("A;"..PM.Version..";"..mode..";"..value), "WHISPER", wtarget, "ALERT")
				end
			end
		end
	end

	if success or #rewarded > 1 then
		PM:SaveToLog(rewarded, mode, value, reason, PM.PlayerName)
		return rewardedid
	end
	if _G.PMEPGP:IsVisible() then PM:UpdateGUI() end
end

function PM:EditMassPoints(value, reason, fillreserve, awardreserve)
	if not PM.IsOfficer then return end

	local members = {}
	local rewardedid = {}
	for i=1, #PM.ScoreBoard.filtered do
		tinsert(members, PM.ScoreBoard.data[PM.ScoreBoard.filtered[i]][5])
	end
	rewardedid = PM:EditPoints(members, "EP", value, reason)

	if fillreserve then
		PM:FillReserve()
	end

	if awardreserve then
		local reserve = {}
		for n, _ in pairs(PM.Reserve) do
			tinsert(reserve, n)
		end
		TAfter(1, function() PM:EditPoints(reserve, "EP", PM:Round(value * (PM.Config.EAM / 100), 0), reason, rewardedid) end)
		PM.Reserve = {}
	end

	if _G.PMEPGP:IsVisible() then PM:UpdateGUI() end
end

function PM:EditPointsDecay()
	if not PM.IsOfficer then return end

	PM:GetGuildData()
	local backup = {}
	for name, data in pairs(PM.GuildData) do
		if data.Active and not data.Main then
			backup[name] = data.EP..","..data.GP
		elseif data.Active and data.Main then
			backup[name] = data.Main
		end
	end
	PM.Settings.Backup[time(date('!*t', GetServerTime()))] = SER:Serialize(backup)

	for _, data in pairs(PM.GuildData) do
		if data.Active and not data.Main and (data.EP > 0 or data.GP > 0) then
			data.EP = PM:Round(data.EP * (1 - (PM.Config.Decay / 100)), 0)
			data.GP = PM:Round(data.GP - ((data.GP + PM.Config.BaseGP) * (1 - (PM.Config.Decay / 100))), 0)
			if data.EP < 0 then data.EP = 0 end
			if data.GP < 0 then data.GP = 0 end
			GuildRosterSetOfficerNote(data.ID, data.EP..","..data.GP)
		end
	end

	PM:SaveToLog({}, "DECAY", PM.Config.Decay, "", PM.PlayerName)

	if _G.PMEPGP:IsVisible() then PM:UpdateGUI() end
end

function PM:AddToReserve(name)
	if not PM.GuildData[name] and not PM.GuildData[name].Active then return end

	if PM.Reserve[name] then
		PM.Reserve[name] = nil
		print("|cFFF2E699[PM EPGP]|r |c"..RAID_CLASS_COLORS[PM.GuildData[name].Class].colorStr..name.."|r removed from reserve.")
	else
		PM.Reserve[name] = true
		print("|cFFF2E699[PM EPGP]|r |c"..RAID_CLASS_COLORS[PM.GuildData[name].Class].colorStr..name.."|r added to reserve.")
	end
end

function PM:FillReserve()
	for i=1, GetNumGroupMembers() do
		local name, _, subgroup = GetRaidRosterInfo(i)
		if subgroup > 4 then
			PM:AddToReserve(name)
		end
	end
end

function PM:GetNameScoreboard(name)
	local nstr = "|c"..RAID_CLASS_COLORS[PM.GuildData[name].Class].colorStr..name.."|r"
	local foundalt = false

	if #PM.GuildData[name].Alts > 0 then
		nstr = nstr.." |cFF808080(|r"
		for i=1, #PM.GuildData[name].Alts do
			if PM.GuildData[name].Alts[i] == PM.PlayerName then foundalt = true end
			nstr = nstr.."|c"..RAID_CLASS_COLORS[PM.GuildData[PM.GuildData[name].Alts[i]].Class].colorStr..PM.GuildData[name].Alts[i].."|r|cFF808080,|r "
		end
		nstr = nstr:sub(1, -15).."|cFF808080)|r"
	end
	if name == PM.PlayerName or foundalt then
		nstr = "|TInterface\\GROUPFRAME\\UI-Group-LeaderIcon:0|t"..nstr
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
			for _, alt in pairs(PM.GuildData[rowdata[5]].Alts) do
				if UnitInRaid(alt) then
					raidFilter = true
				end
			end
		end
	elseif rowdata[2] == 0 then
		raidFilter = false
	else
		raidFilter = true
	end
	if PM.SBFilter == "ALL" or PM.Armors[PM.SBFilter][rowdata[6]] then
		return rowdata[7] and raidFilter
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
		if direction:lower() == "dsc" then
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

function PM:Round(num, idp)
	local mult = 10^(idp or 0)
	return mfloor(num * mult + 0.5) / mult
end

function PMEPGP_AlertSystemTemplate(frame, payload)
	if payload[1] == "GP" then
		if tonumber(payload[2]) > 0 then
			frame.Data:SetText(payload[1]..": |cFFFF0000+"..payload[2].."|r")
		else
			frame.Data:SetText(payload[1]..": |cFF00FF00"..payload[2].."|r")
		end
	else
		if tonumber(payload[2]) > 0 then
			frame.Data:SetText(payload[1]..": |cFF00FF00+"..payload[2].."|r")
		else
			frame.Data:SetText(payload[1]..": |cFFFF0000"..payload[2].."|r")
		end
	end
	PlaySound(44294)
end

-- API

function PMEPGP_Flogging(name, value, reason)
	if PM.GuildData == {} then PM:GetGuildData() end
	if not PM.GuildData[name] then return end
	if not PM.GuildData[name].Active then return end
	if not tonumber(value) then return end
	if not reason or reason == "" then reason = "*slap*" end

	PM:EditPoints(name, "EP", value, reason)
end
