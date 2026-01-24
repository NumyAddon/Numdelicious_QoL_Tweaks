--- @class NQT_NS
local NQT = select(2, ...);

local Main = NQT.Main;
local L = NQT.L;

--- @class NQT_EncounterJournalIcons: NumyConfig_Module, AceHook-3.0
local Module = Main:NewModule('EncounterJournalIcons', 'AceHook-3.0');

local ROLES_ATLAS = {
    TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
    HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
};

local ANCHOR_MAP = {
    TOPRIGHT = "TOPLEFT",
    BOTTOMRIGHT = "BOTTOMLEFT",
};

local PADDING_MAP = {
    TOPRIGHT = 1,
    BOTTOMRIGHT = 1,
    TOPLEFT = 1,
    BOTTOMLEFT = -1,
};

--- @enum NQT_EJI_DisplayStyle
local DISPLAY_STYLES = {
    selectedClassOrPlayerClass = 1,
    alwaysShowAll = 2,
    alwaysShowPlayerClass = 3,
}

function Module:GetName()
    return L["Encounter Journal Loot Icons"];
end

function Module:GetDescription()
    return L["Adds class/spec icons to the Encounter Journal. Adapted from %s"]:format('Vlad @ https://wago.io/hunWMLYhd');
end

function Module:OnInitialize()
    self.pendingAddonLoad = false;

    self.playerClassID = select(3, UnitClass("player"));
end

function Module:OnEnable()
    self:InitCache();
    if not self.pendingAddonLoad or C_AddOns.IsAddOnLoaded('Blizzard_EncounterJournal') then
        self.pendingAddonLoad = true;
        EventUtil.ContinueOnAddOnLoaded('Blizzard_EncounterJournal', function()
            self.pendingAddonLoad = false;
            if not self:IsEnabled() then return; end
            self:HookEncounterJournal();
        end);
    end
end

function Module:OnDisable()
    if self.texturePool then
        self.texturePool:ReleaseAll();
    end
    if EncounterJournal then
        EncounterJournal.encounter.info.LootContainer.ScrollBox:UnregisterCallback(ScrollBoxListMixin.Event.OnUpdate, self);
    end
    self:UnhookAll();
end

--- @param configBuilder NumyConfigBuilder
--- @param db NQT_EncounterJournalIconsDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class NQT_EncounterJournalIconsDB
    local defaults = {
        --- @type FramePoint
        anchor = 'BOTTOMRIGHT',
        offsetX = 0,
        offsetY = 0,
        padding = 1,
        --- @type NQT_EJI_DisplayStyle
        displayStyle = DISPLAY_STYLES.selectedClassOrPlayerClass,
        textureScale = 1,
    }
    configBuilder:SetDefaults(defaults, true);
    configBuilder:SetDefaultCallback(function()
        if EncounterJournal then
            self:UpdateLoot();
        end
    end);

    configBuilder:MakeDropdown(
        L["Icon Location"],
        'anchor',
        L["Icon Location."],
        {
            { value = 'TOPRIGHT', text = L["Top Right"] },
            { value = 'BOTTOMRIGHT', text = L["Bottom Right"] },
        }
    );
    local offsetSliderOptions = configBuilder:MakeSliderOptions(-50, 50, 0.1, function(value) return ('%.1f'):format(value); end);
    configBuilder:MakeSlider(
        L["X Offset"],
        'offsetX',
        L["Horizontal offset."],
        offsetSliderOptions
    );
    configBuilder:MakeSlider(
        L["Y Offset"],
        'offsetY',
        L["Vertical offset."],
        offsetSliderOptions
    );
    configBuilder:MakeDropdown(
        L["Display Style"],
        'displayStyle',
        L["Determines which class/spec icons to show on items."],
        {
            { value = DISPLAY_STYLES.selectedClassOrPlayerClass, text = L["Selected Class, or Player's Class when all classes is selected"] },
            { value = DISPLAY_STYLES.alwaysShowAll, text = L["Always Show All"] },
            { value = DISPLAY_STYLES.alwaysShowPlayerClass, text = L["Always Show Player's Class"] },
        }
    );
    configBuilder:MakeSlider(
        L["Texture Scale"],
        'textureScale',
        L["Scale of the class/spec icons."],
        configBuilder.sliderOptions.scale
    );
end

function Module:HookEncounterJournal()
    if not self.texturePool then
        self.texturePool = CreateTexturePool(EncounterJournal.encounter.info.LootContainer.ScrollBox, "OVERLAY", 7);
        EncounterJournal.encounter.info.LootContainer.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnUpdate, self.UpdateLoot, self)
    end
    self:SecureHook('EncounterJournal_LootUpdate', function() self:UpdateLoot(); end);
end

function Module:InitCache()
    if self.cache then return; end
    --- @type table<number, NQT_EJI_ClassInfo> # [classID] = ClassInfo
    self.classes = {};
    --- @type table<string, {numSpecs: number, [number]: number}> # [role] = { numSpecs = number, [specID] = classID }
    self.roles = {};
    self.totalNumberOfSpecs = 0;
    self.fakeEveryoneSpec = { { specIcon = 922035 } };
    self.cache = {
        difficulty = -1,
        instanceID = -1,
        encounterID = -1,
        classID = -1,
        specID = -1,
        --- @type table<number, NQT_EJI_ItemCache> # [itemID] = ItemCache
        items = {},
    };
    for classID = 1, GetNumClasses() do
        --- @type NQT_EJI_ClassInfo?
        local classInfo = C_CreatureInfo.GetClassInfo(classID); ---@diagnostic disable-line: assign-type-mismatch
        if classInfo then
            self.classes[classInfo.classID] = classInfo;
            classInfo.numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(classInfo.classID);
            classInfo.specs = {};
            for specIndex = 1, classInfo.numSpecs do
                local specID, name, _, icon, role = GetSpecializationInfoForClassID(classInfo.classID, specIndex);
                classInfo.specs[specID] = { id = specID, name = name, icon = icon, role = role };
                self.totalNumberOfSpecs = self.totalNumberOfSpecs + 1;
                self.roles[role] = self.roles[role] or { numSpecs = 0 };
                self.roles[role].numSpecs = self.roles[role].numSpecs + 1;
                self.roles[role][specID] = classInfo.classID;
            end
        end
    end
end

--- @param specs NQT_EJI_ClassAndSpecInfo[]
function Module:CompressSpecs(specs)
    local compress = {};
    for classID, classInfo in pairs(self.classes) do
        local remainingSpecs = classInfo.numSpecs;
        for specID, _ in pairs(classInfo.specs) do
            for _, info in ipairs(specs) do
                if info.specID == specID then
                    remainingSpecs = remainingSpecs - 1;
                    break;
                end
            end
            if remainingSpecs == 0 then
                break;
            end
        end
        if remainingSpecs == 0 then
            compress[classID] = true;
        end
    end
    if not next(compress) then
        return specs;
    end
    local encountered = {};
    local compressed = {};
    local i = 0;
    for _, info in ipairs(specs) do
        if compress[info.classID] then
            if not encountered[info.classID] then
                encountered[info.classID] = true;
                i = i + 1;
                info = CopyTable(info)
                info.specID = 0;
                info.specName = info.className;
                info.specIcon = true;
                info.specRole = "";
                compressed[i] = info;
            end
        else
            i = i + 1;
            compressed[i] = info;
        end
    end
    return compressed;
end

--- @param specs NQT_EJI_ClassAndSpecInfo[]
function Module:CompressRoles(specs)
    local compress;
    for role, specToClass in pairs(self.roles) do
        local remainingSpecs = specToClass.numSpecs;
        for specID in pairs(specToClass) do
            for _, info in ipairs(specs) do
                if info.specID == specID then
                    remainingSpecs = remainingSpecs - 1;
                    break;
                end
            end
            if remainingSpecs == 0 then
                break;
            end
        end
        if remainingSpecs == 0 then
            if not compress then
                compress = {};
            end
            compress[role] = true;
        end
    end
    if not compress then
        return specs;
    end
    local encountered = {};
    local compressed = {};
    local i = 0;
    for _, info in ipairs(specs) do
        if compress[info.specRole] then
            if not encountered[info.specRole] then
                encountered[info.specRole] = true;
                i = i + 1;
                info.specID = 0;
                info.specName = info.specRole;
                info.specIcon = true;
                info.specRole = true;
                compressed[i] = info;
            end
        else
            i = i + 1;
            compressed[i] = info;
        end
    end
    return compressed;
end

--- @param a NQT_EJI_ClassAndSpecInfo
--- @param b NQT_EJI_ClassAndSpecInfo
local function sortByClassAndSpec(a, b)
    local x = a.className;
    local y = b.className;
    if x == y then
        return a.specName < b.specName;
    end
    return x < y;
end

function Module:GetSpecsForItem(itemButton)
    local itemCache = self.cache.items[itemButton.itemID]
    if not itemCache then
        return;
    end
    if itemCache.everyone then
        return true;
    end

    --- @type NQT_EJI_ClassAndSpecInfo[]
    local specs = {};
    local i = 0;
    for specID, classID in pairs(itemCache.specs) do
        local classInfo = self.classes[classID];
        local specInfo = classInfo.specs[specID];
        i = i + 1;
        specs[i] = {
            classID = classID,
            className = classInfo.className,
            classFile = classInfo.classFile,
            specID = specID,
            specName = specInfo.name,
            specIcon = specInfo.icon,
            specRole = specInfo.role,
        };
    end

    if specs[2] then
        specs = self:CompressSpecs(specs);
    end
    if specs[2] then
        specs = self:CompressRoles(specs);
    end
    if specs[2] then
        table.sort(specs, sortByClassAndSpec);
    end

    return specs;
end

--- @param itemButton EncounterItemTemplate
function Module:UpdateItem(itemButton)
    local specs = self:GetSpecsForItem(itemButton);
    if not specs then
        return;
    end
    if specs == true then
        specs = self.fakeEveryoneSpec;
    end
    local anchor = self.db.anchor;
    local anchorFlip = ANCHOR_MAP[anchor];
    local padding = PADDING_MAP[anchor];
    local xPrevOffset = padding;
    local yOffset = (-6 * padding * PADDING_MAP[anchorFlip]) + (self.db.offsetY * padding);
    local prevTexture;
    for _, info in ipairs(specs) do
        --- @type Texture
        local texture = self.texturePool:Acquire();
        texture:SetParent(itemButton);
        if prevTexture then
            texture:SetPoint(anchor, prevTexture, anchorFlip, xPrevOffset, 0);
        else
            texture:SetPoint(anchor, itemButton, anchor, self.db.offsetX * padding, yOffset);
        end
        texture:SetSize(16, 16);
        if info.specRole == true then
            texture:SetAtlas(ROLES_ATLAS[info.specName]);
            texture:SetTexCoord(0, 1, 0, 1);
        elseif info.specIcon == true then
            texture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles");
            texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[info.classFile]));
        else
            texture:SetTexture(info.specIcon);
            texture:SetTexCoord(0, 1, 0, 1);
        end
        texture:SetScale(self.db.textureScale);
        texture:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");
            if info.specID == 0 then
                GameTooltip:SetText(info.className, 1, 1, 1);
            else
                GameTooltip:SetText(info.specName, 1, 1, 1);
            end
            GameTooltip:Show();
        end);
        texture:SetScript("OnLeave", function() GameTooltip:Hide(); end);
        texture:Show();
        prevTexture = texture;
    end
end

function Module:UpdateItems()
    local difficulty = EJ_GetDifficulty();
    local selectedClassID, selectedSpecID = EJ_GetLootFilter();
    if
        self.cache.difficulty == difficulty
        and self.cache.instanceID == EncounterJournal.instanceID
        and self.cache.encounterID == EncounterJournal.encounterID
        and self.cache.classID == selectedClassID
        and self.cache.specID == selectedSpecID
        and self.cache.displayStyle == self.db.displayStyle
    then
        return;
    end

    self.cache.difficulty = difficulty;
    self.cache.instanceID = EncounterJournal.instanceID;
    self.cache.encounterID = EncounterJournal.encounterID;
    self.cache.classID = selectedClassID;
    self.cache.specID = selectedSpecID;
    self.cache.displayStyle = self.db.displayStyle;
    EJ_SelectInstance(self.cache.instanceID);
    wipe(self.cache.items);
    local showAll = self.db.displayStyle == DISPLAY_STYLES.alwaysShowAll;
    local classIDToMatch = nil;
    if self.db.displayStyle == DISPLAY_STYLES.alwaysShowPlayerClass then
        classIDToMatch = self.playerClassID;
    elseif self.db.displayStyle == DISPLAY_STYLES.selectedClassOrPlayerClass then
        classIDToMatch = selectedClassID == 0 and self.playerClassID or selectedClassID;
    end
    for classID, class in pairs(self.classes) do
        if showAll or classIDToMatch == classID then
            for specID, _ in pairs(class.specs) do
                EJ_SetLootFilter(classID, specID);
                for i = 1, EJ_GetNumLoot() do
                    local itemInfo = C_EncounterJournal.GetLootInfoByIndex(i);
                    if itemInfo and itemInfo.itemID then
                        local itemCache = self.cache.items[itemInfo.itemID];
                        if not itemCache then
                            --- @class NQT_EJI_ItemCache
                            itemCache = itemInfo;
                            itemCache.specs = {};
                            self.cache.items[itemInfo.itemID] = itemCache;
                        end
                        itemCache.specs[specID] = classID;
                    end
                end
            end
        end
    end
    if self.cache.encounterID then
        EJ_SelectEncounter(self.cache.encounterID);
    end
    EJ_SetLootFilter(self.cache.classID, self.cache.specID);
    for _, itemCache in pairs(self.cache.items) do
        local count = table.count(itemCache.specs);
        itemCache.everyone = count == self.totalNumberOfSpecs;
    end
end

function Module:UpdateLoot()
    self.texturePool:ReleaseAll();
    local scrollBox = EncounterJournal.encounter.info.LootContainer.ScrollBox;
    --- @type EncounterItemTemplate[]
    local buttons = scrollBox:GetFrames();
    local hasUpdated;
    for _, button in ipairs(buttons) do
        if button:IsVisible() and button.itemID then
            if not hasUpdated then
                hasUpdated = true;
                self:UpdateItems();
            end
            self:UpdateItem(button);
        end
    end
end


