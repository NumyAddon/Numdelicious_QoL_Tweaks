--- @class NQT_NS
local NQT = select(2, ...);

local Main = NQT.Main;
local L = NQT.L;

local ChatFrame_AddMessageEventFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter

local LSM = LibStub("LibSharedMedia-3.0")
local playerName = UnitNameUnmodified('player');
local DEFAULT_LSM_SOUND = "NQT Alert";

--- @class NQT_KeywordSound: NumyConfig_Module
local Module = Main:NewModule('KeywordSound');

function Module:GetName()
    return L["Keyword Sounds"];
end

function Module:GetDescription()
    return L["Plays a sound when specified keywords are detected in chat messages."];
end

function Module:OnInitialize()
    self.channels = {
        CHAT_MSG_GUILD = true,
        CHAT_MSG_OFFICER = true,
        CHAT_MSG_PARTY = true,
        CHAT_MSG_PARTY_LEADER = true,
        CHAT_MSG_INSTANCE_CHAT = true,
        CHAT_MSG_INSTANCE_CHAT_LEADER = true,
        CHAT_MSG_RAID = true,
        CHAT_MSG_RAID_LEADER = true,
        CHAT_MSG_RAID_WARNING = true,
        CHAT_MSG_BN_WHISPER = true,
        CHAT_MSG_WHISPER = true,
    };
    LSM:Register("sound", DEFAULT_LSM_SOUND, [[Interface\Addons\Numdelicious_QoL_Tweaks\media\Whisper.ogg]]);
end

local FindKeywords;

function Module:OnEnable()
    for event in pairs(self.channels) do
        ChatFrame_AddMessageEventFilter(event, FindKeywords)
    end
end

function Module:OnDisable()
    for event in pairs(self.channels) do
        ChatFrame_RemoveMessageEventFilter(event, FindKeywords)
    end
end

--- @param configBuilder NumyConfigBuilder
--- @param db NQT_KeywordSoundDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class NQT_KeywordSoundDB
    local defaults = {
        sound = DEFAULT_LSM_SOUND,
        master = true,
        ignoreYours = true,
        alwaysOnIncomingWhisper = true,
        triggerOnCharacterName = true,
        keywords = {},
    };
    configBuilder:SetDefaults(defaults, true);

    configBuilder:MakeSoundSelector(
        L["Sound"],
        'sound',
        L["The sound to play when a keyword is detected."],
        function()
            local options = {};
            for _, sound in ipairs(LSM:List("sound")) do
                table.insert(options, {
                    text = sound,
                    value = sound,
                });
            end

            return options;
        end,
        function(sound) PlaySoundFile(LSM:Fetch("sound", sound), db.master and "Master" or nil); end
    );
    configBuilder:MakeCheckbox(
        L["Play on Master volume"],
        'master',
        L["If enabled, the sound will be played on the Master volume channel."]
    );
    configBuilder:MakeCheckbox(
        L["Always play on whispers"],
        'alwaysOnIncomingWhisper',
        L["If enabled, incoming whispers will always play the sound, regardless of keywords."]
    );
    configBuilder:MakeCheckbox(
        L["Ignore your own messages"],
        'ignoreYours',
        L["If enabled, messages sent by you will not trigger keyword sounds."]
    );

    local header = configBuilder:MakeHeader(L["Keywords"], L["Manage the list of keywords that will trigger the sound."], 2);
    configBuilder:MakeCheckbox(
        L["Trigger on character name"],
        'triggerOnCharacterName',
        L["If enabled, your character's name will trigger the sound."]
    ):SetParentInitializer(header);
    local dummyDb = { dummy_remove_keyword = "", dummy_add_keyword = "" };
    configBuilder:MakeInput(
        L["Add keyword"],
        'dummy_add_keyword',
        L["Add a keyword to trigger the sound."],
        --- @param value string
        function(setting, value)
            local lowercaseValue = value:lower();
            if lowercaseValue ~= "" then
                db.keywords[lowercaseValue] = true;
                RunNextFrame(function() setting:SetValue(""); end);
            end
        end,
        "",
        dummyDb
    ):SetParentInitializer(header);
    configBuilder:MakeDropdown(
        L["Remove keyword"],
        'dummy_remove_keyword',
        L["Select a keyword to remove it from the list."],
        function()
            local options = { "" };
            for keyword, _ in pairs(db.keywords) do
                table.insert(options, keyword);
            end
            table.sort(options);

            return options;
        end,
        --- @param value string
        function(_, value)
            db.keywords[value] = nil;
            dummyDb.dummy_remove_keyword = "";
        end,
        "",
        dummyDb
    ):SetParentInitializer(header);
end

FindKeywords = function(_, event, text, author)
    local db = Module.db;
    if not db.sound or db.sound == "None" or not LSM:IsValid("sound", db.sound) then return; end

    if db.alwaysOnIncomingWhisper and (event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_WHISPER") then
        PlaySoundFile(LSM:Fetch("sound", db.sound), db.master and "Master" or nil);

        return;
    end
    if db.ignoreYours and author:lower() == playerName:lower() then return; end

    local splits = { string.split(" ", text:lower()) };
    for _, lowercaseWord in pairs(splits) do
        if not lowercaseWord:find("|") then
            if
                (db.triggerOnCharacterName and lowercaseWord == playerName:lower())
                or db.keywords[lowercaseWord]
            then
                PlaySoundFile(LSM:Fetch("sound", db.sound), db.master and "Master" or nil);

                return;
            end
        end
    end
end
