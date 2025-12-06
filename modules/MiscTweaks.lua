local addonName = ...
--- @class NQT_NS
local ns = select(2, ...);

local Main = NQT.Main;
local L = NQT.L;

local isMidnight = select(4, GetBuildInfo()) >= 120000;
local issecretvalue = issecretvalue or function(val) return false; end;
local StripHyperlinks = C_StringUtil and C_StringUtil.StripHyperlinks or StripHyperlinks;
local ChatFrame_AddMessageEventFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter;
local ChatFrame_RemoveMessageEventFilter = ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter or ChatFrame_RemoveMessageEventFilter;

--- @class NQT_MiscTweaks: NumyConfig_Module, AceHook-3.0
local Module = Main:NewModule('MiscTweaks', 'AceHook-3.0');

function Module:GetName()
    return L["Misc Tweaks"];
end

function Module:GetDescription()
    return L["Various small QoL tweaks"];
end

function Module:OnInitialize()
    for dbKey, tweak in pairs(self.tweaks) do
        tweak.enabled = self.db[dbKey] ~= false;
        if tweak.init then
            tweak:init(tweak.enabled, self.db._tweakDB[dbKey]);
        end
    end
end

function Module:OnEnable()
    for dbKey, tweak in pairs(self.tweaks) do
        tweak.enabled = self.db[dbKey] ~= false;
        if tweak.enable and tweak.enabled then
            tweak:enable();
        end
    end
end

function Module:OnDisable()
    for _, tweak in pairs(self.tweaks) do
        tweak.enabled = false;
        if tweak.disable then
            tweak:disable();
        end
    end
end

--- @param db NQT_MiscTweaksDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class NQT_MiscTweaksDB
    local defaults = {
        _tweakDB = {},
    };

    configBuilder:SetDefaults(defaults, true);

    --- @param tweak NQT_MiscTweaks_Tweak
    --- @param enabled boolean
    local function setTweakEnabled(tweak, enabled)
        tweak.enabled = enabled;
        if enabled then
            if tweak.enable then
                tweak:enable();
            end
        else
            if tweak.disable then
                tweak:disable();
            end
        end
    end
    local orderedTweaks = {};
    for dbKey, tweak in pairs(self.tweaks) do
        table.insert(orderedTweaks, { dbKey = dbKey, tweak = tweak, });
    end
    --- @param a { dbKey: string, tweak: NQT_MiscTweaks_Tweak }
    --- @param b { dbKey: string, tweak: NQT_MiscTweaks_Tweak }
    table.sort(orderedTweaks, function(a, b)
        return (a.tweak.order or 0) < (b.tweak.order or 0);
    end);

    for _, entry in ipairs(orderedTweaks) do
        local dbKey, tweak = entry.dbKey, entry.tweak;
        self.db._tweakDB[dbKey] = self.db._tweakDB[dbKey] or {};

        defaults[dbKey] = tweak.defaultEnabled ~= false;
        local checkbox = configBuilder:MakeCheckbox(
            tweak.label,
            dbKey,
            tweak.description,
            function(_, enabled) setTweakEnabled(tweak, enabled); end
        );
        if tweak.shownPredicate then
            checkbox:AddShownPredicate(tweak.shownPredicate);
        end
        if tweak.modifyPredicate then
            checkbox:AddModifyPredicate(tweak.modifyPredicate);
        end
    end
end

function Module:ShowReloadPopup()
    if not self.popupName then
        self.popupName = addonName .. "MiscTweaksReloadPopup";
        StaticPopupDialogs[self.popupName] = {
            text = L["Some changes require a UI reload to take effect. Would you like to reload now?"],
            button1 = YES,
            button2 = NO,
            OnAccept = function() ReloadUI(); end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        };
    end
    StaticPopup_Show(self.popupName);
end

--- @type table<string, NQT_MiscTweaks_Tweak> # dbKey -> logic
Module.tweaks = {};
local tweaks = Module.tweaks;

local function nop() end;
local function setTrue(table, key)
    TextureLoadingGroupMixin.AddTexture({ textures = table }, key);
end
local function setNil(table, key)
    TextureLoadingGroupMixin.RemoveTexture({ textures = table }, key);
end

local increment = CreateCounter();
tweaks.adjustNameplateWidgetScale = {
    order = increment(),
    label = L["Adjust nameplate widget scale"],
    description = L["Allows adjusting the size of nameplate widgets (like progress bars) by Ctrl + Mouse Wheel over them."],
    --- @param self NQT_Misc_AdjustNameplateWidgetScale
    --- @param db { scale?: number }
    init = function(self, enabled, db)
        --- @class NQT_Misc_AdjustNameplateWidgetScale: NQT_MiscTweaks_Tweak
        self = self;
        self.db = db;
        db.scale = db.scale or 1.5;

        self.modifyScale = function(delta, reset)
            local newScale = 1;
            if not reset then
                local oldScale = db.scale;
                newScale = oldScale + (0.1 * delta);
                db.scale = newScale;
            end
            for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
                if plate and plate:IsForbidden() then return end
                if plate and plate.UnitFrame and plate.UnitFrame.WidgetContainer and plate.UnitFrame.WidgetContainer.SetScale then
                    plate.UnitFrame.WidgetContainer:SetScale(newScale);
                end
            end
        end

        local hooked = {};
        local f = CreateFrame("FRAME");
        f:RegisterEvent("NAME_PLATE_UNIT_ADDED");
        f:SetScript("OnEvent", function(_, _, unit)
            local plate = C_NamePlate.GetNamePlateForUnit(unit);
            if plate:IsForbidden() then return; end
            if plate and plate.UnitFrame and plate.UnitFrame.WidgetContainer and plate.UnitFrame.WidgetContainer.SetScale then
                if self.enabled then
                    plate.UnitFrame.WidgetContainer:SetScale(db.scale);
                end
                if not hooked[plate.UnitFrame.WidgetContainer] then
                    hooked[plate.UnitFrame.WidgetContainer] = true;
                    plate.UnitFrame.WidgetContainer:HookScript('OnMouseWheel', function(widgetContainer, delta)
                        if self.enabled and IsControlKeyDown() then
                            self.modifyScale(delta);
                        else
                            if delta < 0 then
                                CameraZoomOut(1);
                            else
                                CameraZoomIn(1);
                            end
                        end
                    end);
                end
                if not plate.UnitFrame.WidgetContainer:IsMouseWheelEnabled() then
                    plate.UnitFrame.WidgetContainer:EnableMouseWheel(true);
                end
            end
        end);
    end,
    --- @param self NQT_Misc_AdjustNameplateWidgetScale
    enable = function(self)
        self.modifyScale(0);
    end,
    --- @param self NQT_Misc_AdjustNameplateWidgetScale
    disable = function(self)
        self.modifyScale(0, true);
    end,
};
tweaks.scrollWheelDropdowns = {
    order = increment(),
    label = L["Scrollwheel dropdowns"],
    description = L["Enables scrolling dropdown menus with the mouse wheel. Only enabled for certain Blizzard dropdowns."],
    --- @param self NQT_Misc_ScrollWheelDropdowns
    init = function(self)
        --- @class NQT_Misc_ScrollWheelDropdowns: NQT_MiscTweaks_Tweak
        self = self;
        self.dropdowns = {};
        self.handleDropdowns = function()
            for dropdown in pairs(self.dropdowns) do
                if dropdown and dropdown.Decrement then
                    dropdown:EnableMouseWheel(self.enabled);
                end
            end
        end

        EventUtil.ContinueOnAddOnLoaded('Blizzard_GroupFinder', function()
            self.dropdowns[LFDQueueFrameTypeDropdown] = true;
            self.dropdowns[RaidFinderQueueFrameSelectionDropdown] = true;
            self.handleDropdowns();
        end);
        EventUtil.ContinueOnAddOnLoaded('Blizzard_DelvesDifficultyPicker', function()
            self.dropdowns[DelvesDifficultyPickerFrame.Dropdown] = true;
            self.handleDropdowns();
        end);
    end,
    --- @param self NQT_Misc_ScrollWheelDropdowns
    enable = function(self)
        self.handleDropdowns();
    end,
    --- @param self NQT_Misc_ScrollWheelDropdowns
    disable = function(self)
        self.handleDropdowns();
    end,
};
tweaks.easyDelete = {
    order = increment(),
    label = L["Easy Delete"],
    description = (L["Automatically adds %s to various deletion confirmations."]):format(DELETE_ITEM_CONFIRM_STRING),
    init = function(self)
        local popups = {
            StaticPopupDialogs.DELETE_GOOD_QUEST_ITEM,
            StaticPopupDialogs.DELETE_GOOD_ITEM,
            StaticPopupDialogs.CONFIRM_DESTROY_COMMUNITY,
        };
        for _, popup in pairs(popups) do
            --- @param dialog StaticPopupTemplate
            hooksecurefunc(popup, "OnShow", function(dialog)
                if not self.enabled then return; end
                --- @type StaticPopupTemplate_EditBox
                local editBox = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox; --- @diagnostic disable-line: undefined-field
                editBox:SetText(DELETE_ITEM_CONFIRM_STRING);
            end);
        end
    end,
};
tweaks.ginvCommand = {
    order = increment(),
    label = L["/ginv command"],
    description = L["Adds a /ginv command as an alias for /ginvite."],
    enable = function()
        SlashCmdList["NUMY_QOL_GUILD_INVITE"] = SlashCmdList.GUILD_INVITE;
        SLASH_NUMY_QOL_GUILD_INVITE1 = "/ginv"
        AUTOCOMPLETE_LIST["NUMY_QOL_GUILD_INVITE"] = AUTOCOMPLETE_LIST.GUILD_INVITE;
    end,
    disable = function()
        SlashCmdList["NUMY_QOL_GUILD_INVITE"] = nil;
        SLASH_NUMY_QOL_GUILD_INVITE1 = nil; --- @diagnostic disable-line: assign-type-mismatch
        AUTOCOMPLETE_LIST["NUMY_QOL_GUILD_INVITE"] = nil;
    end,
};
tweaks.copyChat = {
    order = increment(),
    label = L["Make chat copyable"],
    description = L["Allows copying text from chat frames by enabling text selection."] .. (
        C_AddOns.IsAddOnLoaded('Chattynator') and ("\n" .. L["Not compatible with Chattynator."]) or ""
    ),
    modifyPredicate = function() return not C_AddOns.IsAddOnLoaded('Chattynator'); end,
    --- @param self NQT_Misc_CopyChat
    init = function(self, enabled)
        --- @class NQT_Misc_CopyChat: NQT_MiscTweaks_Tweak
        self = self;
        --- @param chatFrame FloatingChatFrameTemplate
        self.makeCopyable = function(chatFrame)
            if chatFrame:IsForbidden() then return end
            chatFrame:SetTextCopyable(true);
            chatFrame:EnableMouse(true);
        end
        --- @param chatFrame FloatingChatFrameTemplate
        hooksecurefunc('FloatingChatFrame_SetupScrolling', function(chatFrame)
            if not self.enabled then return; end
            self.makeCopyable(chatFrame);
        end);
    end,
    --- @param self NQT_Misc_CopyChat
    enable = function(self)
        for _, frameName in pairs(CHAT_FRAMES) do
            self.makeCopyable(_G[frameName]);
        end
    end,
    --- @param self NQT_Misc_CopyChat
    disable = function(self)
        for _, frameName in pairs(CHAT_FRAMES) do
            local frame = _G[frameName];
            if frame and not frame:IsForbidden() then
                frame:SetTextCopyable(false);
                frame:EnableMouse(false);
            end
        end
    end,
};
tweaks.chatCursor = {
    order = increment(),
    label = L["Constant chat cursor"],
    description = L["Shows a constant red cursor line in chat edit boxes while typing."],
    --- @param self NQT_Misc_ChatCursor
    init = function(self, enabled)
        --- @class NQT_Misc_ChatCursor: NQT_MiscTweaks_Tweak
        self = self;
        self.editBoxLines = {};
        self.replaceCursor = function(editBox)
            if not editBox or self.editBoxLines[editBox] then return end
            local line = editBox:CreateLine();
            self.editBoxLines[editBox] = line;
            line:SetColorTexture(1, 0, 0);
            line:SetThickness(2);
            line:Hide();

            local relativeTo;
            for _, region in ipairs({ editBox:GetRegions(), }) do
                if region.GetObjectType and region:GetObjectType() == 'FontString' then
                    relativeTo = region;
                    break;
                end
            end

            editBox:SetBlinkSpeed(0);
            editBox:HookScript('OnCursorChanged', function(_, posX, posY, _, lineHeight)
                if not self.enabled then return; end
                line:SetStartPoint('TOPLEFT', relativeTo, posX, posY - 2);
                line:SetEndPoint('TOPLEFT', relativeTo, posX, posY - 2 - lineHeight);
                line:Show();
            end);
            editBox:HookScript('OnEditFocusLost', function()
                line:Hide();
            end);
        end;
    end,
    --- @param self NQT_Misc_ChatCursor
    enable = function(self)
        self.replaceCursor(ChatFrame1EditBox);
        EventUtil.ContinueOnAddOnLoaded('WowLua', function()
            RunNextFrame(function()
                self.replaceCursor(WowLuaFrameEditBox);
            end);
        end);
    end,
    --- @param self NQT_Misc_ChatCursor
    disable = function(self)
        for _, line in pairs(self.editBoxLines) do
            line:Hide();
        end
    end,
};
tweaks.nukeCombatLog = {
    order = increment(),
    defaultEnabled = false,
    label = L["Nuke Combat Log"],
    description = L["Completely removes the combat log tab from your chat frame."],
    enable = function()
        C_Timer.After(1, function()
            FCF_UnDockFrame(COMBATLOG)
            COMBATLOG:ClearAllPoints()
            COMBATLOG:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
            COMBATLOG:UnregisterAllEvents()
            local hiddenParent = CreateFrame('FRAME')
            hiddenParent:Hide()
            hiddenParent.SetParent(COMBATLOG, hiddenParent)
            local tab = COMBATLOG.tab or (_G[COMBATLOG:GetName() .. 'Tab'])
            if tab then
                hiddenParent.SetParent(tab, hiddenParent)
                tab.SetParent = nop
            end
            COMBATLOG.SetParent = nop
        end)
    end,
    disable = function()
        Module:ShowReloadPopup();
    end,
};
tweaks.breakUpLargeNumbersInTooltips = {
    order = increment(),
    label = L["Break up large tooltip numbers"],
    description = L["Adds thousands separators to large numbers in tooltips."],
    init = function(self)
        local format = '%d%d%d%d%d+';
        local function breakUpText(text)
            if not text then return text end
            local cleanText = StripHyperlinks(text);
            for num in cleanText:gmatch(format) do
                local formatted = BreakUpLargeNumbers(tonumber(num)):gsub(',', ' ');
                text = text:gsub(num, formatted);
            end

            return text;
        end
        TooltipDataProcessor.AddLinePreCall(TooltipDataProcessor.AllTypes, function(_, info)
            if not self.enabled then return; end
            if info.leftText and not issecretvalue(info.leftText) and info.leftText:match(format) then
                info.leftText = breakUpText(info.leftText);
            end
            if info.rightText and not issecretvalue(info.rightText) and info.rightText:match(format) then
                info.rightText = breakUpText(info.rightText);
            end
        end);
    end,
};
tweaks.disableHandyNotesNewNote = {
    order = increment(),
    label = L["Disable HandyNotes new note"],
    description = L["Removes HandyNotes' New Note option when ALT + Right-clicking on the map. Which is TomTom's default keybind too."],
    modifyPredicate = function()
        return C_AddOns.IsAddOnLoaded('HandyNotes') and LibStub("AceAddon-3.0"):GetAddon("HandyNotes");
    end,
    --- @param self NQT_Misc_DisableHandyNotesNewNote
    enable = function(self)
        --- @class NQT_Misc_DisableHandyNotesNewNote: NQT_MiscTweaks_Tweak
        self = self;
        if not self:modifyPredicate() then return; end
        self.hiddenParent = self.hiddenParent or CreateFrame('Frame');
        self.hiddenParent:Hide();
        --- @type Frame
        self.clickHandler = LibStub("AceAddon-3.0"):GetAddon("HandyNotes"):GetModule('HandyNotes').ClickHandlerFrame; --- @diagnostic disable-line: undefined-field
        local currentParent = self.clickHandler:GetParent();
        if currentParent ~= self.hiddenParent then
            self.originalParent = currentParent;
            self.clickHandler:SetParent(self.hiddenParent);
        end
    end,
    --- @param self NQT_Misc_DisableHandyNotesNewNote
    disable = function(self)
        if not self:modifyPredicate() or not self.originalParent or not self.clickHandler then return; end
        self.clickHandler:SetParent(self.originalParent);
        self.clickHandler:Show();
    end,
};
tweaks.classNameItemTooltips = {
    order = increment(),
    label = L["Class names in item tooltips"],
    description = L["Shows the classes that a transmog set is for (according to blizzard) in item tooltips."],
    init = function(self)
        --- @param classMask number
        --- @return string[] classList
        local function ConvertClassMaskToClassList(classMask)
            local classList = {};
            for classID = 1, GetNumClasses() do
                local classAllowed = FlagsUtil.IsSet(classMask, bit.lshift(1, (classID - 1)));
                local allowedClassInfo = classAllowed and C_CreatureInfo.GetClassInfo(classID);
                if allowedClassInfo then
                    table.insert(classList, allowedClassInfo.className);
                end
            end

            return classList;
        end

        --- @param tooltip GameTooltip
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            if not self.enabled or tooltip ~= GameTooltip and tooltip ~= GameTooltip.ItemTooltip.Tooltip then
                return;
            end
            local itemLink = select(2, TooltipUtil.GetDisplayedItem(tooltip));
            if not itemLink then return; end

            local itemID = tonumber(itemLink:match("item:(%d+)"));
            if not itemID or not C_Item.IsDressableItemByID(itemID) then return; end
            local _, sourceID = C_TransmogCollection.GetItemInfo(itemID);
            local setIDs = sourceID and C_TransmogSets.GetSetsContainingSourceID(sourceID);
            if setIDs and #setIDs > 0 then
                for _, setID in ipairs(setIDs) do
                    local setInfo = C_TransmogSets.GetSetInfo(setID);

                    local classNamelist = ConvertClassMaskToClassList(setInfo.classMask);
                    tooltip:AddLine(L["Class Set:"] .. " " .. table.concat(classNamelist, ", "));
                end
            end
        end)
    end,
};
-- @todo: check midnight compatibility
tweaks.courtOfStarsItemTooltips = {
    order = increment(),
    label = L["Court of Stars item tooltips"],
    description = L["Adds information about Court of Stars items to their tooltips."],
    init = function(self)
        local map = {
            [105117] = "Alchemist, Rogue [kills Gerdo]", -- Flask of the Solemn Night
            [105157] = "Engineer, Goblin, Gnome [disable Constructs]", -- Arcane Power Conduit
            [106110] = "Shaman, Skinner, Scribe [move speed]", -- Waterlogged Scroll
            [105160] = "Demon Hunter, Warlock, Priest, Paladin [crit bonus]", -- Fel Orb
            [105340] = "Druid, Herbalist [haste bonus]", -- Umbral Bloom
            [106018] = "Rogue, Warrior, Leatherworker [pulls Emissary]", -- Bazaar Goods
            [106112] = "Healers, Tailors [pulls Emissary]", -- Wounded Nightborne Civilian
            [106113] = "Jewelcrafter, Miner [pulls Emissary]", -- Lifesized Nightborne Statue
            [105831] = "Paladin, Priest, Demon Hunter [damage reduction]", -- Infernal Tome
            [105249] = "Cooking, Pandaren, Herbalist [health bonus]", -- Nightshade Refreshments
            [105215] = "Hunter, Blacksmith [kills Emissary]", -- Discarded Junk
            [106024] = "Mage, Enchanter, Elf [damage bonus]", -- Magical Lantern
            [106108] = "Death Knight, Monk [regen bonus]", -- Starlight Rose Brew
        };
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            if not self.enabled or not tooltip.GetUnit then return; end

            local _, unit = tooltip:GetUnit();
            if not unit then return; end
            local guid = UnitGUID(unit);
            if issecretvalue and issecretvalue(guid) then return; end
            local npcid = string.sub(guid, -17, -12);
            if not npcid or not map[tonumber(npcid)] then return; end
            local text = map[tonumber(npcid)];
            tooltip:AddLine('CoS: |cffffffff' .. text .. '|r');
        end);
    end,
};
tweaks.hideTimePlayedUnlessManuallyRequested = {
    order = increment(),
    label = L["Hide addon /played messages"],
    description = L["Hides /played messages unless you manually typed /played"],
    --- @param self NQT_Misc_HideTimePlayedUnlessManuallyRequested
    init = function(self)
        --- @class NQT_Misc_HideTimePlayedUnlessManuallyRequested: NQT_MiscTweaks_Tweak
        self = self;
        self.originalSlashFunction = SlashCmdList["PLAYED"];
        self.originalDisplayFunction = (ChatFrameUtil and ChatFrameUtil.DisplayTimePlayed) or ChatFrame_DisplayTimePlayed;
        self.replacement = function(chatFrame, totalTime, ...)
            if self.showNext then
                self.originalDisplayFunction(chatFrame, totalTime, ...);
                RunNextFrame(function() self.showNext = false; end);
            end
        end;
    end,
    --- @param self NQT_Misc_HideTimePlayedUnlessManuallyRequested
    enable = function(self)
        SlashCmdList["PLAYED"] = function(...)
            self.showNext = true;
            self.originalSlashFunction(...);
        end
        if ChatFrameUtil and ChatFrameUtil.DisplayTimePlayed then
            ChatFrameUtil.DisplayTimePlayed = self.replacement;
        else
            ChatFrame_DisplayTimePlayed = self.replacement;
        end
    end,
    --- @param self NQT_Misc_HideTimePlayedUnlessManuallyRequested
    disable = function(self)
        SlashCmdList["PLAYED"] = self.originalSlashFunction;
        if ChatFrameUtil and ChatFrameUtil.DisplayTimePlayed then
            ChatFrameUtil.DisplayTimePlayed = self.originalDisplayFunction;
        else
            ChatFrame_DisplayTimePlayed = self.originalDisplayFunction;
        end
    end,
};
tweaks.autoMaxZoom = {
    order = increment(),
    label = L["Auto max zoom"],
    description = L["Automatically set the maximum zoom as large as possible on login."],
    enable = function()
        C_CVar.SetCVar('cameraDistanceMaxZoomFactor', 2.6);
    end,
    disable = function()
        local name = 'cameraDistanceMaxZoomFactor';
        C_CVar.SetCVar(name, C_CVar.GetCVarDefault(name));
    end,
};
tweaks.escToCancelLogout = {
    order = increment(),
    label = L["Esc to cancel logout"],
    description = L["Allows cancelling the logout timer by pressing the escape key."],
    enable = function()
        setTrue(StaticPopupDialogs.CAMP, 'hideOnEscape');
    end,
    disable = function()
        setNil(StaticPopupDialogs.CAMP, 'hideOnEscape');
    end,
};
-- english only atm
tweaks.hideOutgoingDBMAutoReply = {
    order = increment(),
    defaultEnabled = false,
    label = L["Hide outgoing DBM auto-reply"],
    description = L["Hides outgoing whispers sent by DBM when you are in a boss fight. They are still sent."],
    --- @param self NQT_Misc_HideOutgoingDBMAutoReply
    init = function(self)
        --- @class NQT_Misc_HideOutgoingDBMAutoReply: NQT_MiscTweaks_Tweak
        self = self;
        local playername = UnitName("player");
        self.filter = function(_, _, msg, _, _)
            if string.find(msg, playername .. " is busy fighting against ") or string.find(msg, playername .. " has defeated ") or string.find(msg, playername .. " has wiped on ") then
                return true;
            end
        end;
    end,
    --- @param self NQT_Misc_HideOutgoingDBMAutoReply
    enable = function(self)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", self.filter);
        ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", self.filter);
        ChatFrame_AddMessageEventFilter("CHAT_MSG_COMMUNITIES_CHANNEL", self.filter);
    end,
    --- @param self NQT_Misc_HideOutgoingDBMAutoReply
    disable = function(self)
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", self.filter);
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", self.filter);
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_COMMUNITIES_CHANNEL", self.filter);
    end,
};
tweaks.muteElitismHelper = {
    order = increment(),
    defaultEnabled = false,
    label = L["Mute Elitism Helper messages"],
    description = L["Hides Elitism Helper messages in party chat."],
    --- @param self NQT_Misc_MuteElitismHelper
    init = function(self)
        --- @class NQT_Misc_MuteElitismHelper: NQT_MiscTweaks_Tweak
        self = self;
        -- example:
        -- <EH> Player-Realm got hit by [x] for 36.9k (52%).
        self.filter = function(_, _, msg, _, _)
            if (string.sub(msg, 1, 4) == '<EH>') then
                return true;
            end
        end;
    end,
    --- @param self NQT_Misc_MuteElitismHelper
    enable = function(self)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", self.filter);
        ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", self.filter);
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", self.filter)
    end,
    --- @param self NQT_Misc_MuteElitismHelper
    disable = function(self)
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_PARTY", self.filter);
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_PARTY_LEADER", self.filter);
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SAY", self.filter)
    end,
};
tweaks.additionalEtraceInfo = {
    order = increment(),
    label = L["Improve /etrace"],
    description = L["Adds extra info to Combat Log and Unit Aura events in /etrace."],
    shownPredicate = function() return not isMidnight; end,
    --- @param self NQT_Misc_AdditionalEtraceInfo
    init = function(self)
        --- @class NQT_Misc_AdditionalEtraceInfo: NQT_MiscTweaks_Tweak
        self = self;
        if not self:shownPredicate() then return; end
        --- @param EventTrace EventTrace
        self.logEvent = function(EventTrace, event, ...)
            if event == "COMBAT_LOG_EVENT_UNFILTERED" or event == "COMBAT_LOG_EVENT" then
                self.originalLogEvent(EventTrace, event, CombatLogGetCurrentEventInfo());
            elseif event == "COMBAT_TEXT_UPDATE" then
                self.originalLogEvent(EventTrace, event, (...), GetCurrentCombatTextEventInfo());
            elseif event == "UNIT_AURA" then
                local _, auras = ...;
                local info = {};
                for _, aura in pairs(auras.addedAuras or {}) do
                    table.insert(info, aura.name);
                    table.insert(info, aura.duration);
                    table.insert(info, aura.spellId);
                    table.insert(info, '---');
                end
                self.originalLogEvent(EventTrace, event, ..., #info, unpack(info));
            else
                self.originalLogEvent(EventTrace, event, ...);
            end
        end;
    end,
    --- @param self NQT_Misc_AdditionalEtraceInfo
    enable = function(self)
        --- @class NQT_Misc_AdditionalEtraceInfo: NQT_MiscTweaks_Tweak
        self = self;
        if not self:shownPredicate() then return; end
        EventUtil.ContinueOnAddOnLoaded("Blizzard_EventTrace", function()
            if not self.enabled then return; end
            if not self.originalLogEvent then
                self.originalLogEvent = EventTrace.LogEvent;
            end
            EventTrace.LogEvent = self.logEvent;
        end);
    end,
    --- @param self NQT_Misc_AdditionalEtraceInfo
    disable = function(self)
        if not self:shownPredicate() then return; end
        if EventTrace and self.originalLogEvent then
            EventTrace.LogEvent = self.originalLogEvent;
        end
    end,
};
tweaks.removeCallingNotificationFromMinimap = {
    order = increment(),
    label = L["Hide covenant calling"],
    description = L["Removes the Shadowlands covenant calling notification on the minimap."],
    --- @param self NQT_Misc_RemoveCallingNotificationFromMinimap
    init = function(self)
        --- @class NQT_Misc_RemoveCallingNotificationFromMinimap: NQT_MiscTweaks_Tweak
        self = self;
        self.originalFunction = GarrisonMinimap_ShowCovenantCallingsNotification;
    end,
    enable = function()
        GarrisonMinimap_ShowCovenantCallingsNotification = nop;
    end,
    --- @param self NQT_Misc_RemoveCallingNotificationFromMinimap
    disable = function(self)
        GarrisonMinimap_ShowCovenantCallingsNotification = self.originalFunction;
    end,
};
tweaks.ignoreWebTicket = {
    order = increment(),
    label = L["Ignore web ticket surveys"],
    description = L["Hides blizzard's annoying \"You've been chosen to fill in a survey\" popup."],
    --- @param self NQT_Misc_IgnoreWebTicket
    init = function(self)
        --- @class NQT_Misc_IgnoreWebTicket: NQT_MiscTweaks_Tweak
        self = self;
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, _, hasTicket, _, ticketStatus)
            if hasTicket and ticketStatus ~= LE_TICKET_STATUS_OPEN then
                if ticketStatus == LE_TICKET_STATUS_SURVEY then --survey is ready
                    RunNextFrame(function()
                        TicketStatusFrame.haveWebSurvey = false;
                        TicketStatusFrame:Hide();
                    end);
                end
            end
        end);
    end,
    --- @param self NQT_Misc_IgnoreWebTicket
    enable = function(self)
        self.frame:RegisterEvent("UPDATE_WEB_TICKET");
    end,
    --- @param self NQT_Misc_IgnoreWebTicket
    disable = function(self)
        self.frame:UnregisterEvent("UPDATE_WEB_TICKET");
    end,
};
