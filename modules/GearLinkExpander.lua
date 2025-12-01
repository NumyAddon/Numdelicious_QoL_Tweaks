--- @class NQT_NS
local NQT = select(2, ...);

local Main = NQT.Main;
local L = NQT.L;

local ChatFrame_AddMessageEventFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter or ChatFrame_RemoveMessageEventFilter

local RELIC_TOOLTIP_TYPE_PATTERN = RELIC_TOOLTIP_TYPE:format('(.+)')
local ITEM_LEVEL_PATTERN = ITEM_LEVEL:gsub('%%d', '(%%d+)')

--- @class NQT_GearLinkExpander: NumyConfig_Module, AceHook-3.0
local Module = Main:NewModule('GearLinkExpander', 'AceHook-3.0');

function Module:GetName()
    return L["Gear Link Expander"];
end

function Module:GetDescription()
    return L["Adds itemlevel and other info to item links in chat."];
end

function Module:OnInitialize()
    self.activeEvents = {};
    RunNextFrame(function()
        self:ConfigureChattynator();
    end);
end

function Module:OnEnable()
    self:ReRegisterEvents();
end

function Module:OnDisable()
    self:ReRegisterEvents(true);
end

--- @param configBuilder NumyConfigBuilder
--- @param db NQT_GearLinkExpanderDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class NQT_GearLinkExpanderDB
    local defaults = {
        show_subtype = true,
        subtype_short_format = true,
        show_equiploc = true,
        show_ilevel = true,
        trigger_loots = true,
        trigger_chat = true,
        trigger_quality = 3,
    }
    configBuilder:SetDefaults(defaults, true);

    configBuilder:MakeButton(
        L["Show Example"],
        function()
            local container = ContinuableContainer:Create();
            container:AddContinuables({
                Item:CreateFromItemID(221136),
                Item:CreateFromItemID(185815),
            });
            container:ContinueOnLoad(function()
                local exampleLink = "|cnIQ4:|Hitem:221136::::::::80:250::35:8:10390:6652:10394:10878:10383:12359:3209:10255:1:28:2462:::::|h[Devout Zealot's Ring]|h|r";
                local exampleArmorLink = "|cnIQ4:|Hitem:185815:7397:::::::80:250::54:8:10389:43:12921:12239:10383:12355:10022:10255:1:28:2462:::::|h[Vambraces of Verification]|h|r";
                local message = ("%s - %s"):format(exampleLink, exampleArmorLink);
                print(L["Original Message:"], message);
                print(L["Modified Message:"], (select(2, self:Filter(message))));
            end);
        end,
        L["Show an example of how item links will look after modification."]
    );

    local armorType = configBuilder:MakeCheckbox(
        L["Show Armor Type"],
        "show_subtype",
        L["Display armor/weapon type (Plate, Leather, etc)"]
    );
    configBuilder:MakeCheckbox(
        L["Short Format"],
        "subtype_short_format",
        L["Short format (P for plate, L for leather, etc)"]
    ):SetParentInitializer(armorType);
    configBuilder:MakeCheckbox(
        L["Equip Location"],
        "show_equiploc",
        L["Display equip location (Head, Trinket, etc)"]
    );
    configBuilder:MakeCheckbox(
        STAT_AVERAGE_ITEM_LEVEL,
        "show_ilevel",
        L["Display item level"]
    );
    configBuilder:MakeCheckbox(
        L["Trigger Loots"],
        "trigger_loots",
        L["Rewrite the link when someone loots an item."],
        function() self:ReRegisterEvents() end
    );
    configBuilder:MakeCheckbox(
        L["Trigger Chat"],
        "trigger_chat",
        L["Rewrite the link when someone links an item in chat."],
        function() self:ReRegisterEvents() end
    );
    configBuilder:MakeDropdown(
        QUALITY,
        "trigger_quality",
        L["Filter the minimum quality for links to be rewritten."],
        {
            { text = ITEM_QUALITY0_DESC, value = 0 },
            { text = ITEM_QUALITY1_DESC, value = 1 },
            { text = ITEM_QUALITY2_DESC, value = 2 },
            { text = ITEM_QUALITY3_DESC, value = 3 },
            { text = ITEM_QUALITY4_DESC, value = 4 },
            { text = ITEM_QUALITY5_DESC, value = 5 },
            { text = ITEM_QUALITY6_DESC, value = 6 },
        }
    );
end

local function Filter(_, _, message, ...)
    return Module:Filter(message, ...);
end

function Module:ReRegisterEvents(disable)
    for event in pairs(self.activeEvents) do
        ChatFrame_RemoveMessageEventFilter(event, Filter);
    end
    self.activeEvents = {};
    if disable then
        return;
    end
    if self.db.trigger_loots then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", Filter);
        self.activeEvents.CHAT_MSG_LOOT = true;
    end

    if self.db.trigger_chat then
        local events = {
            CHAT_MSG_BATTLEGROUND = true,
            CHAT_MSG_BATTLEGROUND_LEADER = true,
            CHAT_MSG_BN_WHISPER = true,
            CHAT_MSG_BN_WHISPER_INFORM = true,
            CHAT_MSG_CHANNEL = true,
            CHAT_MSG_EMOTE = true,
            CHAT_MSG_GUILD = true,
            CHAT_MSG_INSTANCE_CHAT = true,
            CHAT_MSG_INSTANCE_CHAT_LEADER = true,
            CHAT_MSG_OFFICER = true,
            CHAT_MSG_PARTY = true,
            CHAT_MSG_PARTY_LEADER = true,
            CHAT_MSG_RAID = true,
            CHAT_MSG_RAID_LEADER = true,
            CHAT_MSG_RAID_WARNING = true,
            CHAT_MSG_SAY = true,
            CHAT_MSG_WHISPER = true,
            CHAT_MSG_WHISPER_INFORM = true,
            CHAT_MSG_YELL = true,
        };
        for event in pairs(events) do
            ChatFrame_AddMessageEventFilter(event, Filter);
            self.activeEvents[event] = true;
        end
    end
end

--- Inhibit Regular Expression magic characters ^$()%.[]*+-?)
--- @param str string
--- @return string
function Module:EscapeSearchString(str)
    return (str:gsub("(%W)", "%%%1"));
end

---@param itemLink string?
---@return string?
function Module:GetRelicType(itemLink)
    local relicType = nil;

    local tooltipData = C_TooltipInfo.GetHyperlink(itemLink);
    for _, line in ipairs(tooltipData.lines) do
        if line.leftText then
            relicType = line.leftText:match(RELIC_TOOLTIP_TYPE_PATTERN);
            if relicType then
                break;
            end
        end
    end

    return relicType;
end

---@param itemLink string?
---@return number
function Module:GetRealItemLevel(itemLink)
    local tooltipData = C_TooltipInfo.GetHyperlink(itemLink);

    for _, line in ipairs(tooltipData.lines) do
        if line.type == Enum.TooltipDataLineType.ItemLevel then
            return tonumber(line.leftText:match(ITEM_LEVEL_PATTERN)) or 0;
        end
    end

    return (select(4, C_Item.GetItemInfo(itemLink))) or 0;
end

---@param itemLink string
---@return boolean
function Module:ItemHasSockets(itemLink)
    local stats = C_Item.GetItemStats(itemLink);
    if stats then
        for key, _ in pairs(stats) do
            if (string.find(key, "EMPTY_SOCKET_")) and not (string.find(key, "EMPTY_SOCKET_TINKER")) then
                return true;
            end
        end
    end

    return false;
end

--- @param itemLink string
--- @param message string
--- @param onAfterLoadCallback fun(itemLink: string)
--- @return string
function Module:HandleItemlink(itemLink, message, onAfterLoadCallback)
    local itemName, _, quality, _, _, _, itemSubType, _, itemEquipLoc, _, _, itemClassId, itemSubClassId = C_Item.GetItemInfo(itemLink);
    if not itemName then
        Item:CreateFromItemLink(itemLink):ContinueOnItemLoad(function() onAfterLoadCallback(itemLink) end);

        return message;
    end

    if
        quality == nil
        or quality < self.db.trigger_quality
        or not (
            Enum.ItemClass.Weapon == itemClassId
            or Enum.ItemClass.Gem == itemClassId
            or Enum.ItemClass.Armor == itemClassId
        )
    then
        return message;
    end

    local itemString = string.match(itemLink, "item[%-?%d:]+");
    local _, _, color = string.find(itemLink, "|?c([^|]*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*):?(%-?%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?");
    local iLevel = self:GetRealItemLevel(itemLink);

    local attrs = {};
    if (self.db.show_subtype and itemSubType) then
        if (itemClassId == Enum.ItemClass.Armor and itemSubClassId == 0) then
            -- don't display Miscellaneous for rings, necks and trinkets
        elseif (itemClassId == Enum.ItemClass.Armor and itemEquipLoc == "INVTYPE_CLOAK") then
            -- don't display Cloth for cloaks
        else
            if (self.db.subtype_short_format) then
                table.insert(attrs, itemSubType:sub(0, 1));
            else
                table.insert(attrs, itemSubType);
            end
        end
        if (itemClassId == Enum.ItemClass.Gem and itemSubClassId == Enum.ItemGemSubclass.Artifactrelic) then
            local relicType = self:GetRelicType(itemLink);
            table.insert(attrs, relicType);
        end
    end
    if self.db.show_equiploc and itemEquipLoc and _G[itemEquipLoc] then
        table.insert(attrs, _G[itemEquipLoc]);
    end
    if self.db.show_ilevel and iLevel then
        local txt = tostring(iLevel);
        if self:ItemHasSockets(itemLink) then txt = txt .. "+S"; end
        table.insert(attrs, txt);
    end
    local craftedQuality = C_TradeSkillUI.GetItemCraftedQualityByItemInfo(itemLink);
    local qualityAtlas = craftedQuality and (" |A:Professions-ChatIcon-Quality-Tier" .. craftedQuality .. ":17:17::1|a") or "";

    local newItemName = itemName .. qualityAtlas .. " (" .. table.concat(attrs, " ") .. ")";
    local newLink = "|c" .. color .. "|H" .. itemString .. "|h[" .. newItemName .. "]|h|r";

    message = string.gsub(message, self:EscapeSearchString(itemLink), newLink);

    return message;
end

function Module:ConfigureChattynator()
    if not Chattynator or not Chattynator.API then
        return;
    end
    Chattynator.API.AddModifier(function(data)
        if not data.typeInfo or not self.activeEvents[data.typeInfo.event] then
            return;
        end
        for itemLink in data.text:gmatch("|[^|]+|Hitem:.-|h.-|h|r") do
            data.text = self:HandleItemlink(itemLink, data.text, function() Chattynator.API.InvalidateMessage(data.id); end);
        end
    end);
end

function Module:Filter(message, ...)
    for itemLink in message:gmatch("|[^|]+|Hitem:.-|h.-|h|r") do
        message = self:HandleItemlink(itemLink, message, function() self:OnAfterItemLoad(itemLink) end);
    end
    return false, message, ...;
end

do
    local function transform(message, ...)
        return select(2, Module:Filter(message)), ...;
    end
    local predicateItemLink;
    local function predicate(message)
        return message and message.find and message:find(predicateItemLink, 1, true);
    end

    function Module:OnAfterItemLoad(itemLink)
        predicateItemLink = itemLink;
        ChatFrameUtil.ForEachChatFrame(function(chatFrame)
            chatFrame:TransformMessages(predicate, transform);
        end);
    end
end
