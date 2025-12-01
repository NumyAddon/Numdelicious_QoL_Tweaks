--- @class NQT_NS
local NQT = select(2, ...);

local Main = NQT.Main;
local L = NQT.L;

local LibDB = LibStub('LibDataBroker-1.1');
local LibAceAddon = LibStub('AceAddon-3.0');

--- @class NQT_AngryAssignmentsBroker: NumyConfig_Module, AceHook-3.0
local Module = Main:NewModule('AngryAssignmentsBroker', 'AceHook-3.0');

local AngryAssign_State;
local AngryAssign_Pages;
local AngryAssign;

Module.initialized = false;

function Module:GetName()
    return L['Angry Assignments databroker'];
end

function Module:GetDescription()
    return L['Creates a data broker for the Angry Assignments addon, allowing quick page switching from broker displays.'];
end

function Module:OnEnable()
    EventUtil.ContinueOnAddOnLoaded('AngryAssignments', function()
        Module:Init();
    end);
end

--- @param configBuilder NumyConfigBuilder
function Module:BuildConfig(configBuilder)
    self.AngryAssignmentsEnabled = not not LibAceAddon:GetAddon('AngryAssignments', true);
    local function angryAssignmentsEnabledPredicate() return self.AngryAssignmentsEnabled; end
    local function angryAssignmentsMissingPredicate() return not self.AngryAssignmentsEnabled; end

    configBuilder.enableInitializer:AddModifyPredicate(angryAssignmentsEnabledPredicate);
    local warning = configBuilder:MakeText(WHITE_FONT_COLOR:WrapTextInColorCode(L['This module requires the Angry Assignments.']), 2);
    warning:AddShownPredicate(angryAssignmentsMissingPredicate);
    configBuilder:MakeText(L['You need a data broker display addon (like Titan Panel, ChocolateBar, etc), and you may need to reload your UI after enabling this module to see the data broker.'], 2);
end

function Module:Init()
    if self.initialized then return; end
    self.initialized = true;

    AngryAssign_State = _G.AngryAssign_State;
    AngryAssign_Pages = _G.AngryAssign_Pages;
    AngryAssign = LibAceAddon:GetAddon("AngryAssignments");

    if not AngryAssign or not AngryAssign_Pages or not AngryAssign_State then return; end

    self.databroker = LibDB:NewDataObject(
        'NQT - Angry Assignments',
        {
            type = 'data source',
            text = 'NQT - Angry Assignments',
            OnClick = function(brokerFrame, button)
                self:OnButtonClick(brokerFrame, button);
            end,
            OnTooltipShow = function(tooltip)
                self:OnTooltipShow(tooltip);
            end,
        }
    );

    self:SecureHook(AngryAssign, 'UpdateDisplayed', function()
        self:OnUpdateDisplayed();
    end);
    self:OnUpdateDisplayed();
end

function Module:OnUpdateDisplayed()
    local currentPage = self:GetCurrentPage();
    if currentPage then
        self.databroker.text = currentPage.Name;
    else
        self.databroker.text = ('<%s>'):format(L['no AA page displayed']);
    end
end

--- @param tooltip GameTooltip
function Module:OnTooltipShow(tooltip)
    local instructionFormat = '|cffeda55f%s|r %s';
    tooltip:AddLine('NQT - AngryAssignments');
    tooltip:AddLine(instructionFormat:format(L['Click'], L['to display next page']));
    tooltip:AddLine(instructionFormat:format(L['Right-Click'], L['to display previous page']));
    tooltip:AddLine(instructionFormat:format(L['Shift + Click'], L['to switch pages']));
    tooltip:AddLine(instructionFormat:format(L['Shift + Right-Click'], L['to toggle the AA pages window']));
    tooltip:AddLine(instructionFormat:format(L['CTRL + Click'], L['to run version check']));
    tooltip:AddLine(instructionFormat:format(L['CTRL + Right-Click'], L['to open config']));
    tooltip:AddLine(instructionFormat:format(L['CTRL + SHIFT + Click'], L['to clear the displayed page']));
end

--- @param button MouseButton
function Module:OnButtonClick(brokerFrame, button)
    local currentPage = self:GetCurrentPage();
    if button == 'LeftButton' then
        if IsShiftKeyDown() and IsControlKeyDown() then
            self:ClearDisplayedPage();
        elseif IsShiftKeyDown() then
            self:ToggleDropDown(brokerFrame);
        elseif IsControlKeyDown() then
            self:RunVersionCheck();
        elseif currentPage then
            self:DisplayPageAtOffset(1);
        else
            self:ToggleDropDown(brokerFrame);
        end
    elseif button == 'RightButton' then
        if IsControlKeyDown() then
            Settings.OpenToCategory('AngryAssign');
        elseif IsShiftKeyDown() then
            AngryAssign_ToggleWindow();
        elseif currentPage then
            self:DisplayPageAtOffset(-1);
        else
            self:ToggleDropDown(brokerFrame);
        end
    end
end

local function isSelected(data)
    return data.selected;
end
local function setSelected(data)
    AngryAssign:DisplayPage(data.value);
end
local function nop() end

--- @param elementDescription RootMenuDescriptionProxy|ElementMenuDescriptionProxy
--- @param tree table
--- @param currentPagePath table<string, number> # [pageId/catId] = 0-based-index, where 0 is the page, 1 is the parent category, 2 is the grandparent category, etc.
function Module:BuildMenuChildren(elementDescription, tree, currentPagePath)
    for _, item in ipairs(tree) do
        local hasChildren = item.children and #item.children > 0;
        local isCategory = item.value < 0;
        local childDescription = elementDescription:CreateRadio(item.text, isSelected, isCategory and nop or setSelected, {
            value = item.value,
            selected = not not currentPagePath[tostring(abs(item.value))],
        });
        if hasChildren then
            self:BuildMenuChildren(childDescription, item.children, currentPagePath);
        elseif isCategory then
            childDescription:SetCanSelect(false);
        end
    end
end

--- @param rootDescription RootMenuDescriptionProxy
function Module:GenerateMenu(rootDescription)
    local currentPagePath = self:GetCurrentPagePath() or {};
    local tree = AngryAssign:GetTree();
    local lastCategoryId = self:GetLastCategoryIdFromTree(tree);
    local currentPageCategoryPages = self:GetCurrentPageCategoryPages();

    if lastCategoryId then
        table.insert(tree, 1, {
            text = ('_%s_'):format(L['last category']),
            value = lastCategoryId,
            children = self:GetCategoryPages(lastCategoryId),
        });
    end

    if currentPageCategoryPages then
        local currentPage = self:GetCurrentPage();
        table.insert(tree, 1, {
            text = ('_%s_'):format(L['current category']),
            value = currentPage and currentPage.CategoryId or -1,
            children = currentPageCategoryPages,
        });
    end

    self:BuildMenuChildren(rootDescription, tree, currentPagePath);
end

function Module:ToggleDropDown(brokerFrame)
    if not brokerFrame then return; end

    MenuUtil.CreateContextMenu(brokerFrame, function(_, rootDescription)
        self:GenerateMenu(rootDescription);
    end);
end

function Module:GetLastCategoryIdFromTree(tree)
    for i = #tree, 1, -1 do
        local item = tree[i];
        if item.value < 0 then
            if item.children and #item.children > 0 then
                return self:GetLastCategoryIdFromTree(item.children) or item.value;
            else
                return item.value;
            end
        end
    end
end

function Module:RunVersionCheck()
    local configRegistry = LibStub('AceConfigRegistry-3.0');
    if not configRegistry then return; end
    local options = configRegistry:GetOptionsTable('AngryAssign', 'cmd', 'Numdelicious_QoL_Tweaks');
    local versionCheck = options and options.args and options.args.version;
    if not versionCheck then return; end
    versionCheck.func();
end

function Module:GetCurrentPagePath()
    local page = self:GetCurrentPage();
    if not page then return; end

    local path = { [tostring(page.Id)] = 0 };
    if not page.CategoryId then return path; end

    local i = 1;
    local cat = AngryAssign:GetCat(page.CategoryId);
    while cat do
        path[tostring(cat.Id)] = i;
        i = i + 1;
        if cat.CategoryId then
            cat = AngryAssign:GetCat(cat.CategoryId);
        else
            break;
        end
    end

    return path;
end

function Module:GetCurrentPageCategoryPages()
    local currentlyDisplayedPage = self:GetCurrentPage();
    if not currentlyDisplayedPage or not currentlyDisplayedPage.CategoryId then return nil; end

    return self:GetCategoryPages(currentlyDisplayedPage.CategoryId);
end

function Module:GetCategoryPages(categoryId)
    categoryId = tonumber(abs(categoryId));
    local pages = {};
    for _, page in pairs(AngryAssign_Pages) do
        if categoryId == page.CategoryId then
            table.insert(pages, { text = page.Name, value = page.Id, selected = AngryAssign_State.displayed == page.Id or nil });
        end
    end

    table.sort(pages, function(a, b) return a.text < b.text; end);

    return pages;
end

function Module:GetCurrentPage()
    return AngryAssign_State.displayed and AngryAssign:Get(AngryAssign_State.displayed);
end

function Module:ClearDisplayedPage()
    AngryAssign:ClearDisplayed();
    AngryAssign:SendDisplay(nil, true);
end

function Module:GetPageAtOffset(offset)
    local orderedPages = self:GetCurrentPageCategoryPages();
    if not orderedPages then return; end

    for i, page in ipairs(orderedPages) do
        if page.selected then
            return orderedPages[i + offset];
        end
    end
end

function Module:DisplayPageAtOffset(offset)
    local pageToDisplay = self:GetPageAtOffset(offset);
    if not pageToDisplay then return; end

    AngryAssign:DisplayPage(pageToDisplay.value);
end
