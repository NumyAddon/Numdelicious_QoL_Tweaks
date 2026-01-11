--- @class NQT_NS
local NQT = select(2, ...);

local Main = NQT.Main;
local L = NQT.L;

--- @class NQT_WishIcons: NumyConfig_Module
local Module = Main:NewModule('WishIcons');

Module.Container = CreateFrame("Frame", nil, UIParent);

function Module:GetName()
    return L["General Icons"];
end

function Module:GetDescription()
    return L["A few basic icons that can be helpful with the end of WeakAuras."];
end

function Module:OnInitialize()
    local combatFrame = self.CombatTextureFrame;
    do
        --- @param frame NQT_WishIcons_IconFrame
        local function onEvent(frame, event)
            frame:UpdateVisibility(event == "PLAYER_REGEN_DISABLED");
        end
        combatFrame:Init(
            self.defaults.combatTexture.position,
            self.db.combatTexture,
            function()
                combatFrame:SetScript("OnEvent", onEvent);
                combatFrame:UpdateVisibility(InCombatLockdown());
            end,
            function() combatFrame:SetScript("OnEvent", nil); end
        );
        combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
        combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED");

        combatFrame:SetSize(145, 145);

        local texture = combatFrame:CreateTexture(nil, "BACKGROUND");
        texture:SetAllPoints(combatFrame);
        texture:SetTexture(1030393);
        texture:SetTexCoord(0, 1, 0, 1);
        texture:SetRotation(math.rad(260));
    end

    --- @class NQT_WishIcons_RepairIconFrame: NQT_WishIcons_IconFrame
    local repairFrame = self.RepairReminderFrame;
    do
        --- @param frame NQT_WishIcons_RepairIconFrame
        local function onEvent(frame)
            local lowest = 1;
            for i = 1, 18 do
                local cur, max = GetInventoryItemDurability(i);
                if cur and max then
                    local durability = cur / max;
                    if durability < lowest then
                        lowest = durability;
                    end
                end
            end
            frame.Text:SetText(WHITE_FONT_COLOR:WrapTextInColorCode(floor(lowest * 100) .. "%"));
            frame:UpdateVisibility(lowest <= frame.threshold);
        end
        function repairFrame:SetThreshold(threshold)
            self.threshold = threshold;
            onEvent(self);
        end
        repairFrame.threshold = self.db.repairReminder.threshold;

        repairFrame:SetSize(64, 64);
        local texture = repairFrame:CreateTexture(nil, "BACKGROUND");
        repairFrame.Texture = texture;
        texture:SetAllPoints(repairFrame);
        texture:SetTexture([[Interface\Icons\ability_repair]]);
        local text = repairFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
        repairFrame.Text = text;
        text:SetPoint("BOTTOMLEFT", repairFrame, "BOTTOMLEFT", 5, 3);

        repairFrame:Init(
            self.defaults.repairReminder.position,
            self.db.repairReminder,
            function()
                repairFrame:SetScript("OnEvent", onEvent);
                onEvent(repairFrame);
            end,
            function() repairFrame:SetScript("OnEvent", nil); end
        );
        repairFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
        repairFrame:RegisterEvent("PLAYER_DEAD");
        repairFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY");
        repairFrame:RegisterEvent("MERCHANT_CLOSED");
    end
end

function Module:OnEnable()
    self.Container:Show();
    for _, frame in pairs({ self.CombatTextureFrame, self.RepairReminderFrame }) do
        if frame.enabled then
            frame.onEnable(frame);
        end
    end
end

function Module:OnDisable()
    self.Container:Hide();
    for _, frame in pairs({ self.CombatTextureFrame, self.RepairReminderFrame }) do
        if frame.enabled then
            frame.onDisable(frame);
        end
    end
end

--- @param configBuilder NumyConfigBuilder
--- @param db NQT_WishIconsDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class NQT_WishIconsDB
    local defaults = {
        --- @type NQT_WishIcons_IconDBTable
        combatTexture = {
            enabled = true,
            locked = true,
            position = {
                anchor = "BOTTOM",
                xOffset = -160,
                yOffset = 155,
            },
            scale = 1.0,
            alpha = 1.0,
        },
        --- @class NQT_WishIcons_RepairIconDBTable: NQT_WishIcons_IconDBTable
        repairReminder = {
            threshold = 0.30,
            enabled = true,
            locked = true,
            position = {
                anchor = "CENTER",
                xOffset = -330,
                yOffset = 180,
            },
            scale = 1.0,
            alpha = 1.0,
        },
    };
    configBuilder:SetDefaults(defaults, true, true);
    self.defaults = defaults;

    local scaleSliderOptions = configBuilder:MakeSliderOptions(0.1, 3.0, 0.1, function(value) return string.format("%.1fx", value); end);
    local alphaSliderOptions = configBuilder:MakeSliderOptions(0.1, 1.0, 0.05, function(value) return string.format("%d%%", value * 100); end);
    --- @param name string
    --- @param tooltip string
    --- @param dbTable NQT_WishIcons_IconDBTable
    --- @param defaultsTable NQT_WishIcons_IconDBTable
    --- @param frame NQT_WishIcons_IconFrame
    --- @return SettingsListElementInitializer
    local function makeConfig(name, tooltip, dbTable, defaultsTable, frame)
        local parentInitializer = configBuilder:MakeCheckbox(
            name,
            "enabled",
            tooltip,
            function(_, enabled) frame:SetEnabled(enabled); end,
            defaultsTable.enabled,
            dbTable
        );
        configBuilder:MakeCheckbox(
            L["Force Show"],
            "forceShow",
            L["Force show the icon."],
            function(_, forceShown) frame:SetForceShown(forceShown); end,
            false,
            { forceShow = false }
        ):SetParentInitializer(parentInitializer);
        configBuilder:MakeCheckbox(
            L["Lock Icon"],
            "locked",
            L["Lock or unlock the icon position to move it."],
            function(_, locked) frame:SetLocked(locked); end,
            defaultsTable.locked,
            dbTable
        ):SetParentInitializer(parentInitializer);
        configBuilder:MakeSlider(
            L["Scale"],
            "scale",
            L["Adjust the scale of the icon."],
            scaleSliderOptions,
            function(_, scale) frame:ApplyNewScale(scale); end,
            defaultsTable.scale,
            dbTable
        ):SetParentInitializer(parentInitializer);
        configBuilder:MakeSlider(
            L["Transparency"],
            "alpha",
            L["Adjust the transparency of the icon."],
            alphaSliderOptions,
            function(_, alpha) frame:SetAlpha(alpha); end,
            defaultsTable.alpha,
            dbTable
        ):SetParentInitializer(parentInitializer);
        configBuilder:MakeButton(
            L["Reset Position"],
            function() frame:ResetPosition(); end,
            L["Reset the icon position to the default location."]
        ):SetParentInitializer(parentInitializer);

        return parentInitializer;
    end

    --- @type NQT_WishIcons_IconFrame
    self.CombatTextureFrame = Mixin(CreateFrame("Frame", nil, self.Container), self.IconFrameMixin);
    makeConfig(
        L["In Combat Texture"],
        L["Shows a texture on screen when in combat."],
        db.combatTexture,
        defaults.combatTexture,
        self.CombatTextureFrame
    );

    --- @type NQT_WishIcons_RepairIconFrame
    self.RepairReminderFrame = Mixin(CreateFrame("Frame", nil, self.Container), self.IconFrameMixin);
    local repairInitializer = makeConfig(
        L["Repair Reminder"],
        L["Shows an icon when your durability is low."],
        db.repairReminder,
        defaults.repairReminder,
        self.RepairReminderFrame
    );
    do
        local thresholdOptions = configBuilder:MakeSliderOptions(0.05, 0.95, 0.05, function(value) return string.format("%d%%", value * 100); end);
        configBuilder:MakeSlider(
            L["Durability Threshold"],
            "threshold",
            L["Set the durability percentage threshold to show the repair reminder."],
            thresholdOptions,
            function(_, threshold)
                self.RepairReminderFrame:SetThreshold(threshold);
            end,
            defaults.repairReminder.threshold,
            db.repairReminder
        ):SetParentInitializer(repairInitializer);
    end
end

--- @class NQT_WishIcons_IconFrame: Frame
Module.IconFrameMixin = {};
do
    --- @return nil|FramePoint point
    --- @return nil|number xOffset
    --- @return nil|number yOffset
    local function GetAbsoluteFramePosition(frame)
        -- inspired by LibWindow-1.1 (https://www.wowace.com/projects/libwindow-1-1)

        local scale = frame:GetScale();
        if not scale then return end
        local left, top = frame:GetLeft() * scale, frame:GetTop() * scale
        local right, bottom = frame:GetRight() * scale, frame:GetBottom() * scale
        local parentWidth = GetScreenWidth();
        local parentHeight = GetScreenHeight();

        local horizontalOffsetFromCenter = (left + right) / 2 - parentWidth / 2;
        local verticalOffsetFromCenter = (top + bottom) / 2 - parentHeight / 2;

        local x, y, point = 0, 0, "";
        if (left < (parentWidth - right) and left < abs(horizontalOffsetFromCenter))
        then
            x = left;
            point = "LEFT";
        elseif ((parentWidth - right) < abs(horizontalOffsetFromCenter)) then
            x = right - parentWidth;
            point = "RIGHT";
        else
            x = horizontalOffsetFromCenter;
        end

        if bottom < (parentHeight - top) and bottom < abs(verticalOffsetFromCenter) then
            y = bottom;
            point = "BOTTOM" .. point;
        elseif (parentHeight - top) < abs(verticalOffsetFromCenter) then
            y = top - parentHeight;
            point = "TOP" .. point;
        else
            y = verticalOffsetFromCenter;
        end

        if point == "" then
            point = "CENTER"
        end

        return point, x, y;
    end

    --- @class NQT_WishIcons_IconFrame: Frame
    local iconMixin = Module.IconFrameMixin;

    --- @param defaultPosition { anchor: FramePoint, xOffset: number, yOffset: number }
    --- @param dbTable NQT_WishIcons_IconDBTable
    --- @param onEnable fun(self: NQT_WishIcons_IconFrame) # onEnable should always call self:UpdateVisibility(shouldShow)
    --- @param onDisable fun(self: NQT_WishIcons_IconFrame) # unregister events etc. The frame will be hidden automatically.
    function iconMixin:Init(defaultPosition, dbTable, onEnable, onDisable)
        self.defaultPosition = defaultPosition;
        self.db = dbTable;
        self.onEnable = onEnable;
        self.onDisable = onDisable;

        self:SetMovable(true);
        self:SetScript("OnDragStart", self.OnDragStart);
        self:SetScript("OnDragStop", self.OnDragStop);
        self:RegisterForDrag("LeftButton");
        self:EnableMouse(false);

        local anchor, xOffset, yOffset = dbTable.position.anchor, dbTable.position.xOffset, dbTable.position.yOffset;
        self:SetScale(dbTable.scale);
        self:SetNormalizedPoint(anchor, xOffset, yOffset);
        self:SetAlpha(dbTable.alpha);
        self:SetLocked(dbTable.locked);
        self:SetEnabled(dbTable.enabled);
    end

    function iconMixin:ApplyNewScale(scale)
        local anchor, xOffset, yOffset = GetAbsoluteFramePosition(self);
        self:SetScale(scale);
        self:SetNormalizedPoint(anchor, xOffset, yOffset);
        self.db.position.anchor = anchor;
        self.db.position.xOffset = xOffset;
        self.db.position.yOffset = yOffset;
    end

    --- @param anchor FramePoint
    --- @param xOffset number
    --- @param yOffset number
    function iconMixin:SetNormalizedPoint(anchor, xOffset, yOffset)
        self:ClearAllPoints();
        local scale = self:GetScale();
        self:SetPoint(anchor, UIParent, anchor, xOffset / scale, yOffset / scale);
    end

    function iconMixin:OnDragStart()
        if not self.locked then
            self:StartMoving();
        end
    end

    function iconMixin:OnDragStop()
        if not self.locked then
            self:StopMovingOrSizing();
            local point, xOffset, yOffset = GetAbsoluteFramePosition(self);
            self.db.position.anchor = point;
            self.db.position.xOffset = xOffset;
            self.db.position.yOffset = yOffset;
        end
    end

    --- @param enabled boolean
    function iconMixin:SetEnabled(enabled)
        self.enabled = enabled;
        if not enabled then
            self.onDisable(self);
            self:Hide();
        else
            self.onEnable(self);
        end
    end

    --- @param locked boolean
    function iconMixin:SetLocked(locked)
        self.locked = locked;
        if locked then
            self:EnableMouse(false);
        else
            self:EnableMouse(true);
        end
    end

    --- @param forceShown boolean
    function iconMixin:SetForceShown(forceShown)
        self.forceShown = forceShown;
        self:SetShown(self.enabled and (forceShown or self.shouldShow));
    end

    --- @param shouldShow boolean
    function iconMixin:UpdateVisibility(shouldShow)
        self.shouldShow = shouldShow;
        if not self.enabled then return; end
        if self.forceShown then
            self:Show();
        else
            self:SetShown(shouldShow);
        end
    end

    function iconMixin:ResetPosition()
        local anchor, xOffset, yOffset = self.defaultPosition.anchor, self.defaultPosition.xOffset, self.defaultPosition.yOffset;
        self:ClearAllPoints();
        self:SetNormalizedPoint(anchor, xOffset, yOffset);
    end
end
