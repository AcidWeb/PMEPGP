local _G = _G
local _, PM = ...
local ST = LibStub("ScrollingTable")
local DB = LibStub("LibPMGuildStorage-1.0")
local GUI = LibStub("AceGUI-3.0")
local COM = LibStub("AceComm-3.0")
local SER = LibStub("AceSerializer-3.0")
local DIA = LibStub("LibDialog-1.0")
local DUMP = LibStub("LibTextDump-1.0")
local JSON = LibStub("LibJSON-1.0")
_G.PMEPGP = PM

--GLOBALS: RAID_CLASS_COLORS, CALENDAR_INVITESTATUS_ACCEPTED, CALENDAR_INVITESTATUS_CONFIRMED, SLASH_PMEPGP1, SLASH_PMEPGP2, SLASH_PMEPGP3, PMEPGP_AlertSystemTemplate, PMEPGP_Flogging
local tonumber, tostring, pairs, type, print, date, time, unpack, select, wipe = _G.tonumber, _G.tostring, _G.pairs, _G.type, _G.print, _G.date, _G.time, _G.unpack, _G.select, _G.wipe
local tinsert, tconcat, tsort = _G.table.insert, _G.table.concat, _G.table.sort
local strsplit, strmatch = _G.string.split, _G.string.match
local mfloor = _G.math.floor
local TAfter = _G.C_Timer.After
local CanEditOfficerNote = _G.CanEditOfficerNote
local GetNumGuildMembers = _G.GetNumGuildMembers
local GetNumGroupMembers = _G.GetNumGroupMembers
local GetGuildRosterInfo = _G.GetGuildRosterInfo
local GetRaidRosterInfo = _G.GetRaidRosterInfo
local GetCVar = _G.GetCVar
local GetGameTime = _G.GetGameTime
local GetRealmName = _G.GetRealmName
local GetGuildInfo = _G.GetGuildInfo
local GetZoneText = _G.GetZoneText
local GetServerTime = _G.GetServerTime
local GetItemInfo = _G.GetItemInfo
local GuildRoster = _G.GuildRoster
local SendChatMessage = _G.SendChatMessage
local IsInRaid = _G.IsInRaid
local IsAddOnLoaded = _G.IsAddOnLoaded
local IsShiftKeyDown = _G.IsShiftKeyDown
local UnitName = _G.UnitName
local UnitInRaid = _G.UnitInRaid
local PlaySound = _G.PlaySound
local CalendarEventGetNumInvites = _G.CalendarEventGetNumInvites
local CalendarEventGetInvite = _G.CalendarEventGetInvite
local CalendarGetDate = _G.CalendarGetDate

PM.Version = 141
PM.GuildData = {}
PM.AltData = {}
PM.AltIndex = {}
PM.TableData = {}
PM.TableIndex = {}
PM.LogIndex = {}
PM.Reserve = {}
PM.AwardCache = {}
PM.Config = {["BaseGP"] = 1, ["Decay"] = 0, ["MinEP"] = 0, ["EAM"] = 100}
PM.DefaultSettings = {["Log"] = {}, ["Backup"] = {}, ["CustomFilter"] = {}}
PM.SBFilter = "ALL"
PM.ClickedPlayer = ""
PM.DialogSwitch = "EP"
PM.IsInRaid = false
PM.IsOfficer = nil
PM.PlayerName = UnitName("player")
SLASH_PMEPGP1 = "/pmepgp"
SLASH_PMEPGP2 = "/ep"
SLASH_PMEPGP3 = "/pm"

PM.OfficerDropDown = {
	{ text = "Mass EP", notCheckable = true, func = function() DIA:Spawn("PMEPGPMassEdit"); _G.L_CloseDropDownMenus() end },
	{ text = "Fill reserve", notCheckable = true, func = function() PM:FillReserve(); _G.L_CloseDropDownMenus() end },
	{ text = "Find deserters", notCheckable = true, func = function() PM:FindDeserters(); _G.L_CloseDropDownMenus() end },
	{ text = "Clear custom filter", notCheckable = true, func = function() PM.Settings.CustomFilter = {}; if PM.SBFilter == "CUSTOM" then PM.ScoreBoard:SetFilter(PM.ScoreBoardFilter) end; _G.L_CloseDropDownMenus() end },
	{ text = "", notCheckable = true, disabled = true },
	{ text = "Logs", notCheckable = true, func = function() PM:ShowLogs(); _G.L_CloseDropDownMenus() end },
	{ text = "Export logs", notCheckable = true, func = function() PM:ExportLogs(); _G.L_CloseDropDownMenus() end },
	{ text = "Decay", notCheckable = true, func = function() DIA:Spawn("PMEPGPDecayWarning"); _G.L_CloseDropDownMenus() end },
	{ text = "", notCheckable = true, disabled = true },
	{ text = "Check notes", notCheckable = true, func = function() PM:CheckNotes(); _G.L_CloseDropDownMenus() end },
	{ text = "Setup notes", notCheckable = true, func = function() PM:SetNotes(); _G.L_CloseDropDownMenus() end },
}
PM.PlayerDropDown = {
	{ text = "Edit points", notCheckable = true, func = function() DIA:Spawn("PMEPGPPlayerEdit", PM.ClickedPlayer); _G.L_CloseDropDownMenus() end },
	{ text = "Toggle reserve status", notCheckable = true, func = function() PM:AddToCustomField(PM.ClickedPlayer, PM.Reserve, "reserve"); _G.L_CloseDropDownMenus() end },
	{ text = "Show logs", notCheckable = true, func = function() PM:ShowLogs(PM.ClickedPlayer); _G.L_CloseDropDownMenus() end },
	{ text = "", notCheckable = true, disabled = true },
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
PM.GPModifiers = {
	[-1] = 0,
	[0] = 50,
	[5] = 50,
	[10] = 125,
	[15] = 225,
	[20] = 350,
	[25] = 500,
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
	_G.SlashCmdList["PMEPGP"] = function()
		if not _G.PMEPGPFrame:IsVisible() then
			_G.PMEPGPFrame:Show()
		else
			_G.PMEPGPFrame:Hide()
		end
	end

	if IsAddOnLoaded("RCLootCouncil_EPGP") or IsAddOnLoaded("epgp_lootmaster") or IsAddOnLoaded("epgp") then
		PM.Unsupported = true
		return
	end

	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:RegisterForDrag("LeftButton")
	tinsert(_G.UISpecialFrames, "PMEPGPFrame")
	_G.PMEPGPFrame_Title:SetText("PM EPGP "..tostring(PM.Version):gsub(".", "%1."):sub(1,-2))
	_G.BINDING_HEADER_PMEPGPB = "|cFFF2E699PM|r EPGP"
	_G.BINDING_NAME_PMEPGPOPEN = "Show main window"
end

function PM:OnEvent(self, event, name)
	if event == "ADDON_LOADED" and name == "PMEPGP" then
		if not _G.PMEPGPDB then _G.PMEPGPDB = PM.DefaultSettings end
		PM.Settings = _G.PMEPGPDB
		for key, value in pairs(PM.DefaultSettings) do
			if PM.Settings[key] == nil then
				PM.Settings[key] = value
			end
		end
		for t, _ in pairs(PM.Settings.Log) do
			tinsert(PM.LogIndex, t)
		end
		if _G.AddOnSkins then
			PM.AS = unpack(_G.AddOnSkins)
		end
		PM.IsInRaid = IsInRaid()

		PM.ModeButton = GUI:Create("Button")
		PM.ModeButton.frame:SetParent(_G.PMEPGPFrame)
		PM.ModeButton.frame:SetPoint("BOTTOMRIGHT", _G.PMEPGPFrame, "BOTTOMRIGHT", -15, 14)
		PM.ModeButton:SetWidth(100)
		PM.ModeButton:SetCallback("OnClick", function() PM:UpdateGUI(true) end)
		PM.ModeButton.frame:Show()
		PM.OfficerButton = GUI:Create("Button")
		PM.OfficerButton.frame:SetParent(_G.PMEPGPFrame)
		PM.OfficerButton.frame:SetPoint("BOTTOMLEFT", _G.PMEPGPFrame, "BOTTOMLEFT", 15, 14)
		PM.OfficerButton:SetWidth(100)
		PM.OfficerButton:SetCallback("OnClick", function() PM:OnClickOfficerButton() end)
		PM.OfficerButton.frame:Show()
		PM.ArmorDropdown = GUI:Create("Dropdown")
		PM.ArmorDropdown.frame:SetParent(_G.PMEPGPFrame)
		PM.ArmorDropdown.frame:SetPoint("BOTTOM", _G.PMEPGPFrame, "BOTTOM", 0, 14)
		PM.ArmorDropdown:SetWidth(100)
		PM.ArmorDropdown:SetList({["ALL"] = "All", ["CLOTH"] = "Cloth", ["LEATHER"] = "Leather", ["MAIL"] = "Mail", ["PLATE"] = "Plate", ["CONQUEROR"] = "Conqueror", ["PROTECTOR"] = "Protector", ["VANQUISHER"] = "Vanquisher", ["CUSTOM"] = "Custom"},
		{"ALL", "CLOTH", "LEATHER", "MAIL", "PLATE", "CONQUEROR", "PROTECTOR", "VANQUISHER", "CUSTOM"})
		PM.ArmorDropdown:SetValue("ALL")
		PM.ArmorDropdown:SetCallback("OnValueChanged", PM.OnArmorValueChange)
		PM.ArmorDropdown.frame:Show()
		PM.ScoreBoard = ST:CreateST(PM.ScoreBoardStructure, 30, nil, nil, _G.PMEPGPFrame)
		PM.ScoreBoard.frame:SetPoint("TOPLEFT", _G.PMEPGPFrame, "TOPLEFT", 17, -40)
		PM.AlertSystem = _G.AlertFrame:AddSimpleAlertFrameSubSystem("PMEPGP_Alert", _G.PMEPGP_AlertSystemTemplate)
		PM.DumpFrame = DUMP:New("PM EPGP - Logs", nil, 540)

		if IsAddOnLoaded("ElvUI") and IsAddOnLoaded("AddOnSkins") then
			PM.AS:SkinFrame(_G.PMEPGPFrame)
			PM.AS:SkinFrame(PM.ScoreBoard.frame, nil, true)
			PM.AS:StripTextures(_G[PM.ScoreBoard.frame:GetName()..'ScrollTrough'], true)
			PM.AS:SkinScrollBar(_G[PM.ScoreBoard.frame:GetName()..'ScrollFrameScrollBar'])
			PM.AS:SkinCloseButton(_G.PMEPGPFrame_CloseButton)
			PM.ArmorDropdown.frame:ClearAllPoints()
			PM.ModeButton.frame:ClearAllPoints()
			PM.OfficerButton.frame:ClearAllPoints()
			PM.ArmorDropdown.frame:SetPoint("BOTTOM", _G.PMEPGPFrame, "BOTTOM", 0, 8)
			PM.ModeButton.frame:SetPoint("BOTTOMRIGHT", _G.PMEPGPFrame, "BOTTOMRIGHT", -15, 10)
			PM.OfficerButton.frame:SetPoint("BOTTOMLEFT", _G.PMEPGPFrame, "BOTTOMLEFT", 15, 10)
			_G.PMEPGPFrame_Title:ClearAllPoints()
			_G.PMEPGPFrame_Title:SetPoint("BOTTOM", _G.PMEPGPFrame, "TOP", 0, -20)
		end

		PM.ScoreBoard:RegisterEvents({
			["OnClick"] = function (_, _, data, _, _, realRow, _, _, button, _)
				if IsShiftKeyDown() and (button == "LeftButton" or button == "RightButton") and realRow ~= nil then
					PM:AddToCustomField(data[realRow][5], PM.Settings.CustomFilter, "custom filter")
					if PM.SBFilter == "CUSTOM" then
						PM.ScoreBoard:SetFilter(PM.ScoreBoardFilter)
					end
				elseif PM.IsOfficer and (button == "LeftButton" or button == "RightButton") and realRow ~= nil then
					if PM.ClickedPlayer == data[realRow][5] then
						PM.ClickedPlayer = ""
						_G.L_CloseDropDownMenus()
					else
						PM.ClickedPlayer = data[realRow][5]
						_G.L_CloseDropDownMenus()
						_G.L_EasyMenu(PM.PlayerDropDown, _G.PMEPGP_DropDown, "cursor", 2, -2, "MENU")
					end
				end
			end,
		})

		DIA:Register("PMEPGPPlayerEdit", {
			static_size = true,
			width = 300,
			height = 175,
			hide_on_escape = true,
			is_exclusive = true,
			show_while_dead = true,
			on_hide = function(self)
				self.text:SetTextColor(1, 1, 1, 1)
			end,
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
					--PM.AS:SkinEditBox(self.editboxes[1], nil, 26)
					--PM.AS:SkinEditBox(self.editboxes[2], nil, 26)
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
			height = 240,
			hide_on_escape = true,
			is_exclusive = true,
			show_while_dead = true,
			text = "All players currently displayed in main window will be affected with this operation.",
			on_show = function(self)
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
					--PM.AS:SkinEditBox(self.editboxes[1], nil, 26)
					--PM.AS:SkinEditBox(self.editboxes[2], nil, 26)
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
			height = 90,
			hide_on_escape = true,
			is_exclusive = true,
			show_while_dead = true,
			no_close_button = true,
			on_show = function(self)
				self.text:SetText("Are you sure you want to execute "..tostring(PM.Config.Decay).."% decay?")
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
		DIA:Register("PMEPGPRewardEdit", {
			static_size = true,
			width = 300,
			height = 115,
			hide_on_escape = true,
			is_exclusive = true,
			show_while_dead = true,
			text = "",
			on_show = function(self)
				local gp, gpdetails = PM:GetGP()
				self.text:SetText("Proposed GP cost: "..gpdetails)
				self.editboxes[1]:SetText(gp)
				if IsAddOnLoaded("ElvUI") and IsAddOnLoaded("AddOnSkins") then
					PM.AS:SkinFrame(self)
					PM.AS:SkinCloseButton(self.close_button)
					PM.AS:SkinButton(self.buttons[1])
					PM.AS:SkinButton(self.buttons[2])
					--PM.AS:SkinEditBox(self.editboxes[1], nil, 26)
				end
			end,
			buttons = {
				{
					text = "Add GP",
					on_click = function(self)
						local value = tonumber(self.editboxes[1]:GetText())
						if value then
							local name = strsplit("-", PM.Loot.awarded)
							local nameprevious = strsplit("-", PM.Loot.previous)
							PM:EditPoints(name, "GP", value, PM.Loot.link)
							PM.AwardCache[name] = value
							if #nameprevious > 0 then
								TAfter(2, function()
									PM:EditPoints(nameprevious, "GP", PM.AwardCache[nameprevious] * -1, PM.Loot.link)
									PM.AwardCache[nameprevious] = nil
								end)
							end
							return false
						else
							print("|cFFF2E699[PM EPGP]|r The value must be a number!")
							return true
						end
					end,
				},
				{
					text = "Give for free",
					on_click = function(_)
						local name = strsplit("-", PM.Loot.awarded)
						local nameprevious = strsplit("-", PM.Loot.previous)
						PM:EditPoints(name, "GP", 0, PM.Loot.link)
						PM.AwardCache[name] = 0
						if #nameprevious > 0 then
							TAfter(2, function()
								PM:EditPoints(nameprevious, "GP", PM.AwardCache[nameprevious] * -1, PM.Loot.link)
								PM.AwardCache[nameprevious] = nil
							end)
						end
						return false
					end,
				},
			},
			editboxes = {
				{
					label = "GP",
					width = 150,
				},
			},
		})

		PM:RCLHook()
		PM:ExRTHook()
		COM:RegisterComm("PMEPGP", PM.OnAddonMsg)
		COM:SendCommMessage("PMEPGP", SER:Serialize("V;"..PM.Version), "GUILD", nil, "NORMAL")
		DB.RegisterCallback(self, "GuildNoteChanged", PM.OnGuildNoteChanged)
		DB.RegisterCallback(self, "GuildNoteDeleted", PM.OnGuildNoteDeleted)
		DB.RegisterCallback(self, "GuildInfoChanged", PM.OnGuildInfoChanged)
		GuildRoster()
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "GUILD_ROSTER_UPDATE" then
		local output = CanEditOfficerNote()
		if PM.IsOfficer ~= output then
			PM.IsOfficer = output
			if PM.IsOfficer then
				PM.OfficerButton:SetText("Tools")
			else
				PM.OfficerButton:SetText("Logs")
			end
		end
	elseif event == "GROUP_ROSTER_UPDATE" then
		local output = IsInRaid()
		if PM.IsInRaid ~= output then
			PM.IsInRaid = output
			if _G.PMEPGPFrame:IsVisible() then
				PM:UpdateGUI()
			end
		end
	end
end

function PM:OnAddonMsg(...)
	local msg, _, sender = ...
	local status, msg = SER:Deserialize(msg)

	if status then
		msg = {strsplit(";", msg)}
		if msg[1] == "A" then
			PM.AlertSystem:AddAlert({msg[3], tonumber(msg[4])})
		elseif msg[1] == "L" and sender ~= PM.PlayerName then
			local t = tonumber(msg[3])
			if not PM.Settings.Log[t] then
				PM.Settings.Log[t] = msg[4]
				tinsert(PM.LogIndex, t)
			end
		end
		if tonumber(msg[2]) > PM.Version then
			print("|cFFF2E699[PM EPGP]|r Addon is out-of-date!")
		end
	end
end

function PM:OnClickOfficerButton()
	if PM.IsOfficer then
		if not _G.L_DropDownList1:IsVisible() then
			_G.L_CloseDropDownMenus()
			_G.L_EasyMenu(PM.OfficerDropDown, _G.PMEPGP_DropDown, "cursor", 0 , 0, "MENU")
		else
			_G.L_CloseDropDownMenus()
		end
	else
		if IsShiftKeyDown() then
			PM:ShowLogs(PM.PlayerName)
		else
			PM:ShowLogs()
		end
	end
end

function PM:OnArmorValueChange(_, armor)
	_G.L_CloseDropDownMenus()
	PM.SBFilter = armor
	PM.ScoreBoard:SetFilter(PM.ScoreBoardFilter)
	if armor == "CUSTOM" then
		PM.ModeButton:SetDisabled(true)
	else
		PM.ModeButton:SetDisabled(false)
	end
end

function PM:OnHyperLinkEnter(linkData, _)
	_G.GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	_G.GameTooltip:SetHyperlink(linkData)
	_G.GameTooltip:Show()
end

function PM:OnHyperLinkLeave()
	_G.GameTooltip:Hide()
end

function PM:OnGuildNoteChanged(name, note)
	local ep, gp = strmatch(note, "^(%d+),(%d+)$")
	if ep then
		if PM.AltData[name] then PM.AltData[name] = nil end
		PM.GuildData[name] = {["Class"] = DB:GetClass(name), ["EP"] = tonumber(ep), ["GP"] = tonumber(gp)}
	elseif note ~= "" then
		if PM.GuildData[name] then PM.GuildData[name] = nil end
		PM.AltData[name] = {["Class"] = DB:GetClass(name), ["Main"] = note}
	end

	if _G.PMEPGPFrame:IsVisible() then
		PM:UpdateGUI()
	end
	if PM.RCLVF.frame and PM.RCLVF.frame:IsVisible() then
		PM.RCLVF.frame.st:Refresh()
	end
end

function PM:OnGuildNoteDeleted(name)
	PM.GuildData[name] = nil
	PM.AltData[name] = nil

	if _G.PMEPGPFrame:IsVisible() then
		PM:UpdateGUI()
	end
	if PM.RCLVF.frame and PM.RCLVF.frame:IsVisible() then
		PM.RCLVF.frame.st:Refresh()
	end
end

function PM:OnGuildInfoChanged(info)
	local guildinfo = {strsplit("\n", info)}
	local block = false
	if #guildinfo > 1 then
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

-- Main functions

function PM:UpdateGUI(override)
	_G.L_CloseDropDownMenus()
	if PM.Unsupported then
		print("|cFFF2E699[PM EPGP]|r Unsupported addon detected!")
		_G.PMEPGPFrame:Hide()
		return
	end
	if override then
		PM.IsInRaid = not PM.IsInRaid
	end
	if PM.IsInRaid then
		PM.ModeButton:SetText("Raid")
	else
		PM.ModeButton:SetText("Guild")
	end
	if #PM.ScoreBoard.data == 0 then
		PM.ScoreBoard.cols[4].sort = "asc"
	end
	PM:GetScoreBoardData()
	PM.ScoreBoard:SetData(PM.TableData, true)
	PM.ScoreBoard:SetFilter(PM.ScoreBoardFilter)
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

function PM:ShowLogs(filtername)
	if PM.DumpFrameInternal and not filtername and PM.DumpFrameInternal:IsVisible() then
		PM.DumpFrameInternal:Hide()
		return
	end

	PM.DumpFrame:Clear()

	tsort(PM.LogIndex, function (a, b) return a > b end)
	for i=1, #PM.LogIndex do
		local status, payload = SER:Deserialize(PM.Settings.Log[PM.LogIndex[i]])
		local t = PM.LogIndex[i]
		local members = ""
		local points = ""
		local from = ""
		local show = false

		if status then
			local name = PM:GetMainName(payload[5])
			if name then
				from = "|c"..RAID_CLASS_COLORS[PM.GuildData[name].Class].colorStr..name.."|r"
			else
				from = payload[5]
			end
			if payload[2] == "DECAY" then
				PM.DumpFrame:AddLine("["..date("%H:%M %d.%m.%y", t).."] |cFFFF0000DECAY "..payload[3].."%|r || "..from)
				PM.DumpFrame:AddLine(" ")
			else
				for i=1, #payload[1] do
					name = PM:GetMainName(payload[1][i])
					if name then
						members = members.."|c"..RAID_CLASS_COLORS[PM.GuildData[name].Class].colorStr..name.."|r, "
					else
						members = members..payload[1][i]..", "
					end
					if filtername == payload[1][i] then
						show = true
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
				if not filtername or show then
					PM.DumpFrame:AddLine("["..date("%H:%M %d.%m.%y", t).."] "..members.." || "..points.." || "..payload[4].." || "..from)
					PM.DumpFrame:AddLine(" ")
				end
			end
		end
	end

	if PM.DumpFrame:Lines() == 0 then
		PM.DumpFrame:AddLine(" ")
	end
	PM.DumpFrame:Display()

	PM.DumpFrameInternal = DUMP.frames[PM.DumpFrame]
	PM.DumpFrameInternal:ClearAllPoints()
	PM.DumpFrameInternal:SetPoint("LEFT", _G.PMEPGPFrame, "RIGHT", 10, 0)
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

function PM:ExportLogs()
	if not PM.IsOfficer then return end
	if not DB:IsCurrentState() then return end

	local timestamp = {}
	timestamp.month = select(2, CalendarGetDate())
	timestamp.day = select(3, CalendarGetDate())
	timestamp.year = select(4, CalendarGetDate())
	timestamp.hour = select(1, GetGameTime())
	timestamp.min = select(2, GetGameTime())

	local d = {}
	d.region = GetCVar("portal")
	d.guild = select(1, GetGuildInfo("player"))
	d.realm = GetRealmName()
	d.base_gp = PM.Config.BaseGP
	d.min_ep = PM.Config.MinEP
	d.decay_p = PM.Config.Decay
	d.extras_p = PM.Config.EAM
	d.timestamp = time(timestamp)

	d.roster = {}
	for name, _ in pairs(PM.GuildData) do
		if PM.GuildData[name].EP > 0 or PM.GuildData[name].GP > 0 then
			tinsert(d.roster, {name, PM.GuildData[name].EP, PM.GuildData[name].GP + PM.Config.BaseGP})
		end
	end

	d.loot = {}
	tsort(PM.LogIndex, function (a, b) return a > b end)
	for i=1, #PM.LogIndex do
		local status, payload = SER:Deserialize(PM.Settings.Log[PM.LogIndex[i]])
		local t = mfloor(PM.LogIndex[i] / 60) * 60
		if status and payload[2] == "GP" then
			local itemString = payload[4]:match("item[%-?%d:]+")
			local name = PM:GetMainName(payload[1][1])
			if name and itemString then
				tinsert(d.loot, {t, name, itemString, tonumber(payload[3])})
			end
		end
	end

	local payload = JSON.Serialize(d):gsub("\124", "\124\124")
	PM.DumpFrame:Clear()
	PM.DumpFrame:AddLine(payload)
	PM.DumpFrame:Display()

	PM.DumpFrameInternal = DUMP.frames[PM.DumpFrame]
	PM.DumpFrameInternal:ClearAllPoints()
	PM.DumpFrameInternal:SetPoint("LEFT", _G.PMEPGPFrame, "RIGHT", 10, 0)
	PM.DumpFrameInternal.edit_box:Enable()
	PM.DumpFrameInternal.edit_box:SetHyperlinksEnabled(false)

	if IsAddOnLoaded("ElvUI") and IsAddOnLoaded("AddOnSkins") then
		PM.AS:SkinFrame(PM.DumpFrameInternal)
		PM.AS:SkinFrame(PM.DumpFrameInternal.Inset)
		PM.AS:SkinCloseButton(PM.DumpFrameInternal.CloseButton)
		PM.AS:SkinScrollBar(PM.DumpFrameInternal.scrollArea.ScrollBar)
	end
end

-- Support functions

function PM:GetMainName(name)
	if PM.GuildData[name] then
		return name
	end
	if PM.AltData[name] and PM.GuildData[PM.AltData[name].Main] then
		return PM.AltData[name].Main
	end
	return false
end

function PM:FindAlts(name)
	wipe(PM.AltIndex)
	for n, d in pairs(PM.AltData) do
		if d.Main == name then
			tinsert(PM.AltIndex, n)
		end
	end
	return PM.AltIndex
end

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
	if not PM.IsOfficer then return end

	local nonote = {}
	local badnote = {}
	local altcache = {}

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
			DB:SetNote(name, "0,0")
			print(name)
		end
	end
end

function PM:WipeNotes()
	if not PM.IsOfficer then return end

	for i=1, GetNumGuildMembers() do
		local name, _, _, _, _, _, _, note = GetGuildRosterInfo(i)
		name = strsplit("-", name)
		local ep, _ = strmatch(note, "^(%d+),(%d+)$")
		if not note or note == "" or ep then
			DB:SetNote(name, "0,0")
		end
	end

	print("|cFFF2E699[PM EPGP]|r Notes wiped.")
end

function PM:ListBackup()
	if not PM.IsOfficer then return end

	print("|cFFF2E699[PM EPGP]|r Available backups:")
	for key, _ in pairs(PM.Settings.Backup) do
		print(date("%H:%M %d.%m.%y", key).." - ID: "..key)
	end
end

function PM:RestoreBackup(id)
	if not PM.IsOfficer then return end

	local status, payload = SER:Deserialize(PM.Settings.Backup[id])
	if status then
		for key, value in pairs(payload) do
			DB:SetNote(key, value)
		end
	end

	print("|cFFF2E699[PM EPGP]|r Backup restored.")
end

function PM:EditPoints(members, mode, value, reason, rewardedid)
	if not PM.IsOfficer then return end
	if not DB:IsCurrentState() then print("|cFFF2E699[PM EPGP]|r Database is not ready. Please try again."); return end

	local success = false
	local rewarded = {}
	local rewardedid = rewardedid or {}

	if type(members) ~= "table" then
		members = {members}
	end

	for i=1, #members do
		local name = PM:GetMainName(members[i])
		if name and not rewardedid[name] then
			local player = PM.GuildData[name]
			if mode == "EP" then
				player.EP = player.EP + value
			elseif mode == "GP" then
				player.GP = player.GP + value
			end
			if player.EP < 0 then player.EP = 0 end
			if player.GP < 0 then player.GP = 0 end
			success = true
			tinsert(rewarded, members[i])
			rewardedid[name] = true
			DB:SetNote(name, player.EP..","..player.GP)
			if DB:GetOnline(name) then
				COM:SendCommMessage("PMEPGP", SER:Serialize("A;"..PM.Version..";"..mode..";"..value), "WHISPER", name, "ALERT")
			else
				for _, alt in pairs(PM:FindAlts(name)) do
					if DB:GetOnline(alt) then
						COM:SendCommMessage("PMEPGP", SER:Serialize("A;"..PM.Version..";"..mode..";"..value), "WHISPER", alt, "ALERT")
						break
					end
				end
			end
		end
	end

	if success or #rewarded > 1 then
		PM:SaveToLog(rewarded, mode, value, reason, PM.PlayerName)
		return rewardedid
	end
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
		TAfter(2, function() PM:EditPoints(reserve, "EP", PM:Round(value * (PM.Config.EAM / 100), 0), reason, rewardedid) end)
		PM.Reserve = {}
	end
end

function PM:EditPointsDecay()
	if not PM.IsOfficer then return end
	if not DB:IsCurrentState() then return end

	local backup = {}
	for name, data in pairs(PM.GuildData) do
		backup[name] = data.EP..","..data.GP
	end
	for name, data in pairs(PM.AltData) do
		backup[name] = data.Main
	end
	PM.Settings.Backup[time(date('!*t', GetServerTime()))] = SER:Serialize(backup)

	for name, data in pairs(PM.GuildData) do
		if data.EP > 0 or data.GP > 0 then
			data.EP = PM:Round(data.EP * (1 - (PM.Config.Decay / 100)), 0)
			data.GP = PM:Round(((data.GP + PM.Config.BaseGP) * (1 - (PM.Config.Decay / 100))) - PM.Config.BaseGP, 0)
			if data.EP < 0 then data.EP = 0 end
			if data.GP < 0 then data.GP = 0 end
			DB:SetNote(name, data.EP..","..data.GP)
		end
	end

	PM:SaveToLog({}, "DECAY", PM.Config.Decay, "", PM.PlayerName)
end

function PM:AddToCustomField(name, field, description)
	local name = PM:GetMainName(name)
	if not name then return end

	if field[name] then
		field[name] = nil
		print("|cFFF2E699[PM EPGP]|r |c"..RAID_CLASS_COLORS[PM.GuildData[name].Class].colorStr..name.."|r removed from "..description..".")
	else
		field[name] = true
		print("|cFFF2E699[PM EPGP]|r |c"..RAID_CLASS_COLORS[PM.GuildData[name].Class].colorStr..name.."|r added to "..description..".")
	end
end

function PM:FillReserve()
	for i=1, GetNumGroupMembers() do
		local name, _, subgroup = GetRaidRosterInfo(i)
		if subgroup > 4 then
			PM:AddToCustomField(name, PM.Reserve, "reserve")
		end
	end
end

function PM:FindDeserters()
	if not PM.IsOfficer then return end
	if not DB:IsCurrentState() then return end
	if not IsInRaid() then
		print("|cFFF2E699[PM EPGP]|r Not in raid!")
		return
	end
	if not _G.CalendarViewEventFrame or not _G.CalendarViewEventFrame:IsVisible() then
		print("|cFFF2E699[PM EPGP]|r Calendar event not selected!")
		return
	end

	local deserters = {}
	local i = 1
	while i <= CalendarEventGetNumInvites() do
		local name, _, _, _, inviteStatus = CalendarEventGetInvite(i)
		name = PM:GetMainName(name)
		if name and (inviteStatus == CALENDAR_INVITESTATUS_ACCEPTED or inviteStatus == CALENDAR_INVITESTATUS_CONFIRMED) then
			deserters[name] = true
		end
		i = i + 1
	end
	for i=1, GetNumGroupMembers() do
		local name = GetRaidRosterInfo(i)
		name = PM:GetMainName(name)
		if name then
			deserters[name] = false
		end
	end

	PM.Settings.CustomFilter = {}
	for name, deserter in pairs(deserters) do
		if deserter then
			PM.Settings.CustomFilter[name] = true
		end
	end

	PM.ArmorDropdown:SetValue("CUSTOM")
	PM:OnArmorValueChange(_, "CUSTOM")
end

function PM:GetNameScoreboard(name)
	local nstr = "|c"..RAID_CLASS_COLORS[PM.GuildData[name].Class].colorStr..name.."|r"
	local foundalt = false
	local alts = PM:FindAlts(name)

	if #alts > 0 then
		nstr = nstr.." |cFF808080(|r"
		for i=1, #alts do
			if alts[i] == PM.PlayerName then foundalt = true end
			nstr = nstr.."|c"..RAID_CLASS_COLORS[PM.AltData[alts[i]].Class].colorStr..alts[i].."|r|cFF808080,|r "
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

	if PM.SBFilter == "CUSTOM" then
		return PM.Settings.CustomFilter[rowdata[5]]
	end

	if PM.IsInRaid then
		if UnitInRaid(rowdata[5]) then
			raidFilter = true
		else
			local alts = PM:FindAlts(rowdata[5])
			for i=1, #alts do
				if UnitInRaid(alts[i]) then
					raidFilter = true
				end
			end
		end
	elseif rowdata[2] == 0 and (DB:GetRankID(rowdata[5]) > 5 or DB:GetRankID(rowdata[5]) < 4) then
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

function PM:GetILvlDiff()
	local diffA, diffABase, diffB, diffBBase = false, 0, false, 0
	local basePrice = 200

	if PM.Loot.equipLoc == "INVTYPE_TRINKET" then
		basePrice = 300
	end

	if PM.Loot.candidates[PM.Loot.awarded].gear1 then
		local g1ilvl = select(4, GetItemInfo(PM.Loot.candidates[PM.Loot.awarded].gear1))
		if g1ilvl < 960 then
			g1ilvl = 960
			diffABase = basePrice
		end
		diffA = PM.Loot.ilvl - g1ilvl
		if diffA < 0 then
			diffA = 0
		end
	end

	if PM.Loot.candidates[PM.Loot.awarded].gear2 then
		local g1ilvl = select(4, GetItemInfo(PM.Loot.candidates[PM.Loot.awarded].gear2))
		if g1ilvl < 960 then
			g1ilvl = 960
			diffBBase = basePrice
		end
		diffB = PM.Loot.ilvl - g1ilvl
		if diffB < 0 then
			diffB = 0
		end
	end

	return diffA, diffABase, diffB, diffBBase
end

function PM:GetGP()
	local gp = 0
	local gpDetails = ""

	if PM.Loot.token then
		gp = 300
		gpDetails = "300"
	else
		local gpA = 0
		local gpB = 0
		local gpDetailsA = ""
		local gpDetailsB = ""
		local diffA, diffABase, diffB, diffBBase = PM:GetILvlDiff()

		if diffA then
			if diffABase > 0 and diffA == 0 then diffA = -1 end
			gpA = diffABase + PM.GPModifiers[diffA]
			gpDetailsA = tostring(diffABase).." + "..tostring(PM.GPModifiers[diffA])
		end
		if diffB then
			if diffBBase > 0 and diffB == 0 then diffB = -1 end
			gpB = diffBBase + PM.GPModifiers[diffB]
			gpDetailsB = tostring(diffBBase).." + "..tostring(PM.GPModifiers[diffB])
		end

		if gpA == 0 and gpB == 0 then
			gp = ""
			gpDetails = "?"
		elseif gpA == gpB or (gpA > 0 and gpB == 0) then
			gp = gpA
			gpDetails = gpDetailsA
		else
			gp = ""
			gpDetails = gpDetailsA.." or "..gpDetailsB
		end
	end

	return tostring(gp), gpDetails
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
	if not PM.IsOfficer then return end
	if not DB:IsCurrentState() then return end
	if not PM:GetMainName(name) then return end
	if not tonumber(value) then return end
	if not reason or reason == "" then reason = "*slap*" end

	PM:EditPoints(name, "EP", value, reason)
end
