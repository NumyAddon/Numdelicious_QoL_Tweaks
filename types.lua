--- @meta _

--- @class NQT_Main: NumyConfig_AceAddon

--- @class NQT_MiscTweaks_Tweak
--- @field label string
--- @field description string
--- @field defaultEnabled nil|boolean # defaults to true
--- @field modifyPredicate nil|fun(self: NQT_MiscTweaks_Tweak): boolean # return false to block the checkbox
--- @field shownPredicate nil|fun(self: NQT_MiscTweaks_Tweak): boolean # return false to hide the checkbox
--- @field init nil|fun(self: NQT_MiscTweaks_Tweak, enabled: boolean, tweakDB: table)
--- @field enable nil|fun(self: NQT_MiscTweaks_Tweak)
--- @field disable nil|fun(self: NQT_MiscTweaks_Tweak)
--- @field order number # order of the settings list
--- @field enabled boolean? # automatically set OnInit and when toggled
