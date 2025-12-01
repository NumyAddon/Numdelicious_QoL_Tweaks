local name = ...;
--- @class NQT_NS
local ns = select(2, ...);

--@debug@
_G.Numdelicious_QoL_Tweaks = ns;
if not _G.NQT then _G.NQT = ns; end
--@end-debug@

--- @class NQT_Main: AceAddon, AceConsole-3.0, AceHook-3.0, AceEvent-3.0
local Main = LibStub('AceAddon-3.0'):NewAddon(name, 'AceConsole-3.0', 'AceHook-3.0', 'AceEvent-3.0');
if not Main then return; end
ns.Main = Main;
ns.L = LibStub('AceLocale-3.0'):GetLocale(name);

function Main:OnInitialize()
    if NumyProfiler then
        NumyProfiler:WrapModules(name, 'Main', self);
        for moduleName, module in self:IterateModules() do
            NumyProfiler:WrapModules(name, moduleName, module);
        end
    end

    NumyQT_DB = NumyQT_DB or {};
    self.db = NumyQT_DB;
    self:InitDefaults();
    for moduleName, module in self:IterateModules() do
        if self.db.modules[moduleName] == false then
            module:Disable();
        end
    end

    --- @type NumyConfig
    local Config = ns.Config;

    Config:Init("Numdelicious QoL Tweaks", self.db, nil, ns.L, self, {
        'GearLinkExpander',
        'KeywordSound',
        'MiscTweaks',
        'AngryAssignmentsBroker',
    });

    SLASH_NUMDELICIOUS_QOL_TWEAKS1 = '/nqt';
    SLASH_NUMDELICIOUS_QOL_TWEAKS2 = '/nqol';
    SLASH_NUMDELICIOUS_QOL_TWEAKS3 = '/nqoltweaks';
    SLASH_NUMDELICIOUS_QOL_TWEAKS4 = '/numyqt'; -- (✿◠◡◠)
    SlashCmdList['NUMDELICIOUS_QOL_TWEAKS'] = function() Config:OpenSettings(); end
end

function Main:InitDefaults()
    local defaults = {
        modules = {},
        moduleDb = {},
    };

    for key, value in pairs(defaults) do
        if self.db[key] == nil then
            self.db[key] = value;
        end
    end
end

function Main:SetModuleState(moduleName, enabled)
    if enabled then
        self:EnableModule(moduleName);
    else
        self:DisableModule(moduleName);
    end
    self.db.modules[moduleName] = enabled;
end

function Main:IsModuleEnabled(moduleName)
    local module = self:GetModule(moduleName);

    return module and module:IsEnabled() or false;
end
