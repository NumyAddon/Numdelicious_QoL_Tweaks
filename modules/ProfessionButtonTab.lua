--- @class NQT_NS
local NQT = select(2, ...);

local Main = NQT.Main;
local L = NQT.L;

--- @class NQT_ProfessionButtonTab: NumyConfig_Module, AceEvent-3.0, AceHook-3.0
local Module = Main:NewModule('ProfessionButtonTab', 'AceEvent-3.0', 'AceHook-3.0');

function Module:GetName()
    return L["Profession Button Tab"];
end

function Module:GetDescription()
    return L["Adds buttons to the profession UI to switch between professions quickly."];
end

function Module:OnInitialize()
    self.buttons = {};
    self.mainTabs = {};
    self.actionTabs = {};
    self.linkTabs = {};
    --- @type table<number, number> # [spellID] = skillLineID
    self.skillMap = {
        [2018] = 164, -- blacksmithing
        [2108] = 165, -- leatherworking
        [2259] = 171, -- alchemy
        [193290] = 182, -- herb journal
        [2550] = 185, -- cooking
        [2656] = 186, -- mining journal
        [3908] = 197, -- tailoring
        [4036] = 202, -- engineering
        [7411] = 333, -- enchanting
        [8613] = 393, -- skinning
        [25229] = 755, -- jewelcrafting
        [45357] = 773, -- inscription
        [271616] = 356, -- fishing
    };
    self.specials = {
        Runeforging = 53428,
        PickLock = 1804,
        ChefHat = 134020,
        ThermalAnvilSpell = 126462,
        ThermalAnvilItem = 87216,
    };
    self.professionSpellIDs = {
        2018, -- blacksmithing
        2108, -- leatherworking
        2259, -- alchemy
        -- 193290, -- herb journal
        2550, -- cooking
        -- 2656, -- mining journal
        3908, -- tailoring
        4036, -- engineering
        7411, -- enchanting
        -- 8613, -- skinning
        25229, -- jewelcrafting
        45357, -- inscription
        -- 271616, -- fishing
    };
    self.playerClass = select(2, UnitClass('player'));
end

function Module:OnEnable()
    QueryGuildRecipes();
    self:RegisterEvent('TRADE_SKILL_DATA_SOURCE_CHANGED');
    EventUtil.ContinueOnAddOnLoaded('Blizzard_Professions', function()
        if self:IsEnabled() and not self:IsHooked(ProfessionsFrame, 'OnShow') then
            self:SecureHookScript(ProfessionsFrame, 'OnShow', function()
                if not InCombatLockdown() then
                    self:UpdateTabButtons();
                end
            end);
        end
        if self:IsEnabled() and not InCombatLockdown() and ProfessionsFrame:IsShown() then
            self:UpdateTabButtons();
        end
    end);
end

function Module:OnDisable()
    self:UnregisterAllEvents();
    self:UnhookAll();
    self:RemoveTabButtons();
end

--- @param configBuilder NumyConfigBuilder
--- @param db NQT_ProfessionButtonTabDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class NQT_ProfessionButtonTabDB
    local defaults = {
    };
    configBuilder:SetDefaults(defaults, true);
    self.defaults = defaults;
end

function Module:TRADE_SKILL_DATA_SOURCE_CHANGED()
    if not InCombatLockdown() then
        self:UpdateTabButtons();
    end
end

--- @param id number
--- @param index number
--- @param actionType "toy"|"item"|"spell"
--- @param isProfession boolean
--- @param isLink boolean
--- @return nil|NQT_ProfessionButtonTab_ButtonMixin
function Module:MakeTabButton(id, index, actionType, isProfession, isLink)
    local name, icon;
    if actionType == 'toy' then
        name, icon = select(2, C_ToyBox.GetToyInfo(id));
    else
        local spellInfo = C_Spell.GetSpellInfo(id);
        name, icon = spellInfo and spellInfo.name, spellInfo and spellInfo.iconID;
    end
    if not name or not icon then return nil; end

    --- @type NQT_ProfessionButtonTab_ButtonMixin
    local button = Mixin(CreateFrame('CheckButton', 'NQT_ProfessionButtonTab' .. index, ProfessionsFrame, 'InsecureActionButtonTemplate'), self.ButtonMixin);
    button:Init(index, id, actionType, icon, name, isProfession, isLink);

    tinsert(self.buttons, button);

    return button;
end

function Module:RemoveTabButtons()
    for _, button in pairs(self.buttons) do
        button:UnregisterAllEvents();
        button:Hide();
    end
    self.buttons = {};
    self.mainTabs = {};
    self.actionTabs = {};
    self.linkTabs = {};
end

function Module:PositionTabButtons()
    for _, button in pairs(self.buttons) do
        local index = button.index
        local nonProfMult = not button.isProfession and 1 or 0;
        local linkMult = button.isLink and 1 or 0;
        local yOffset = 20 + (-37 * index) + (-15 * nonProfMult) + (-15 * linkMult);
        button:SetPoint('TOPLEFT', ProfessionsFrame, 'TOPRIGHT', 0, yOffset);
        button:Show();
        index = index + 1;
    end
end

function Module:UpdateTabButtons()
    QueryGuildRecipes();
    local mainProfs, profActions, links = {}, {}, {};
    local specials = self.specials;
    if self.playerClass == 'DEATHKNIGHT' and C_Spell.IsSpellUsable(specials.Runeforging) then
        tinsert(mainProfs, specials.Runeforging);
    elseif self.playerClass == 'ROGUE' and C_Spell.IsSpellUsable(specials.PickLock) then
        tinsert(profActions, { id = specials.PickLock, type = 'spell' });
    end

    if PlayerHasToy(specials.ChefHat) and C_ToyBox.IsToyUsable(specials.ChefHat) then
        tinsert(profActions, { id = specials.ChefHat, type = 'toy' });
    end
    if C_Item.GetItemCount(specials.ThermalAnvilItem) ~= 0 then
        tinsert(profActions, { id = specials.ThermalAnvilSpell, type = 'item' });
    end

    local prof1, prof2, _, _, cooking = GetProfessions();
    for _, prof in pairs({ prof1, prof2, cooking }) do
        local num, offset, line = select(5, GetProfessionInfo(prof));
        for i = 1, num do
            if not C_SpellBook.IsSpellBookItemPassive(offset + i, Enum.SpellBookSpellBank.Player) then
                local spellInfo = C_SpellBook.GetSpellBookItemInfo(offset + i, Enum.SpellBookSpellBank.Player);
                local id = spellInfo and spellInfo.spellID;
                if id then
                    if i == 1 then
                        tinsert(mainProfs, id);
                        self.skillMap[id] = line;
                    else
                        tinsert(profActions, { id = id, type = 'spell' });
                    end
                end
            end
        end
    end

    for _, profSpellID in pairs(self.professionSpellIDs) do
        tinsert(links, profSpellID);
    end

    local tabsChanged = false;
    for _, id in pairs(mainProfs) do
        if not self.mainTabs[id] then
            tabsChanged = true;
        end
    end
    for _, info in pairs(profActions) do
        if not self.actionTabs[info.id] then
            tabsChanged = true;
        end
    end
    for _, id in pairs(links) do
        if not self.linkTabs[id] then
            tabsChanged = true;
        end
    end

    if tabsChanged then
        self:RemoveTabButtons();
        local index = 1;
        for _, id in pairs(mainProfs) do
            local button = self:MakeTabButton(id, index, 'spell', true, false);
            if button then
                self.mainTabs[id] = button;
                index = index + 1;
            end
        end
        for _, info in pairs(profActions) do
            local id = info.id;
            local button = self:MakeTabButton(id, index, info.type, false, false);
            if button then
                self.actionTabs[id] = button;
                index = index + 1;
            end
        end
        for _, id in pairs(links) do
            local button = self:MakeTabButton(id, index, 'spell', false, true);
            if button then
                self.linkTabs[id] = button;
                index = index + 1;
            end
        end
        self:PositionTabButtons();
    end
end

--- @type NQT_ProfessionButtonTab_ButtonMixin
Module.ButtonMixin = {};
do
    local playerGuid = UnitGUID("player");
    local tooltip = CreateFrame("GameTooltip", "NQT_ProfessionButtonTab_Tooltip", nil, "GameTooltipTemplate");

    --- @class NQT_ProfessionButtonTab_ButtonMixin: CheckButton
    local buttonMixin = Module.ButtonMixin;

    function buttonMixin:Init(index, id, actionType, icon, name, isProfession, isLink)
        self.index = index;
        self.id = id;
        self.isLink = isLink;
        self.isProfession = isProfession;
        self:SetSize(35, 35);
        self:SetScript("OnEnter", function()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetText(name, 1, 1, 1);
            GameTooltip:Show();
        end);
        self:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);
        self:SetScript("OnEvent", function()
            self:UpdateCheckedState();
            RunNextFrame(function() self:UpdateCheckedState(); end);
        end);

        local skillID = Module.skillMap[id];
        if not skillID and not isLink then
            self:SetAttribute('type', actionType);
            self:SetAttribute(actionType, (actionType == 'spell' or actionType == 'toy') and id or name);
        else
            self:SetScript("OnClick", function()
                if isLink then
                    QueryGuildRecipes();
                    if CanViewGuildRecipes(skillID) then
                        ViewGuildRecipes(skillID);
                    else
                        local link = "trade:" .. playerGuid .. ":" .. id .. ":333";
                        ProfessionsFrame:Hide();
                        tooltip:SetHyperlink(link);
                    end
                else
                    C_TradeSkillUI.OpenTradeSkill(skillID);
                end
            end);
        end
        if isProfession then
            self:HookScript('OnClick', function()
                self:SetChecked(true);
            end);
        end

        self:RegisterEvent('TRADE_SKILL_SHOW');
        self:RegisterEvent('TRADE_SKILL_LIST_UPDATE');
        self:RegisterEvent('CURRENT_SPELL_CAST_CHANGED');

        local checkedTexture = self:CreateTexture(nil, 'HIGHLIGHT');
        checkedTexture:SetColorTexture(1, 1, 1, 0.3);
        self:SetCheckedTexture(checkedTexture);
        self:SetNormalTexture(icon);
        self:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92); -- inset by 8%

        self:UpdateCheckedState();
    end

    function buttonMixin:UpdateCheckedState()
        local id = self.id;
        local skillID = Module.skillMap[id];
        local activeProfessionID = ProfessionsFrame.professionInfo and (ProfessionsFrame.professionInfo.parentProfessionID or ProfessionsFrame.professionInfo.professionID);
        local isCurrent = C_Spell.IsCurrentSpell(id) or (self.isLink and activeProfessionID == skillID);
        if isCurrent then
            self:SetChecked(true);
            self:RegisterForClicks();
        else
            self:SetChecked(false);
            self:RegisterForClicks('AnyUp', 'AnyDown');
        end
    end
end
