-- Real shortcut selection + watcher and phrase input; no game runtime required.
local passed = 0
local function check(name, fn)
    fn()
    passed = passed + 1
    print("PASS " .. name)
end
local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function noop() end
local function fixture()
    local CK, state = {}, { keys = {}, free = true, combat = false, keyboard = false, wheel = false }
    format = string.format
    GetLocale = function() return "enUS" end
    GetTime = function() return 100 end
    InCombatLockdown = function() return state.combat end
    IsKeyDown = function(key) return state.keys[key] == true end
    DEFAULT_CHAT_FRAME = { AddMessage = noop }
    CreateFrame = function() return { RegisterEvent = noop, SetScript = noop } end
    C_Timer = { After = function(_, fn) fn() end }
    UIParent = {}
    ControllerKeyboardDB = nil
    assert(loadfile("Locales/enUS.lua"))("EasyController", CK)
    assert(loadfile("Core.lua"))("EasyController", CK)
    CK:InitDB()
    CK.ConfigKit = { C = {} }
    CK.IsOpen = function() return state.keyboard end
    CK.GlyphMarkup = function(_, key) return "[" .. key .. "]" end
    assert(loadfile("Phrases.lua"))("EasyController", CK)
    assert(loadfile("ConfigWindow.lua"))("EasyController", CK)
    local P, C = CK.Phrases, CK.Config
    local binds = {}
    ClearOverrideBindings = function() for key in pairs(binds) do binds[key] = nil end end
    SetOverrideBindingClick = function(_, _, key, button) binds[key] = button end
    P.frame = {}
    P.sendButton = { Show = noop, Hide = noop, SetAttribute = noop }
    P.opens = 0
    P.Open = function(self)
        self.opens, self.active = self.opens + 1, true
        self:Bind()
    end
    P.Render = noop
    C.GameIsFree = function() return state.free end
    C.IsOpen = function() return state.panel == true end
    C.Open = function() state.panel = true; state.configOpens = (state.configOpens or 0) + 1 end
    local M = { suspendCalls = 0, resumeCalls = 0 }
    CK.Mapping = M
    function M:IsOurs(key) return key == "PADDLEFT" or key == "PADDDOWN" end
    function M:Suspend(key)
        self.suspended = self.suspended or {}
        self.suspended[key] = true
        self.suspendCalls = self.suspendCalls + 1
    end
    function M:Resume()
        if not self.suspended then return end
        self.suspended = nil
        self.resumeCalls = self.resumeCalls + 1
    end
    ControllerKeyboardWheel = { IsShown = function() return state.wheel end }
    function state:update(keys)
        self.keys = keys or {}
        C:CheckShortcuts()
    end
    function state:close()
        P.active = false
        P:Unbind()
        self.panel = false
    end
    return CK, state, P, C, M, binds
end

check("RB then left opens once; held opening keys cannot navigate or cycle channels", function()
    local CK, s, P, C, M, binds = fixture()
    equal(CK.db.settings.features.phrasesShortcut, true)
    s:update({ PADRSHOULDER = true })
    equal(P.opens, 0)
    assert(M.suspended.PADDLEFT and M.suspended.PADDDOWN)
    s:update({ PADRSHOULDER = true, PADDLEFT = true })
    equal(P.opens, 1)
    assert(P.held.PADRSHOULDER and P.held.PADDLEFT)
    equal(binds.PADRSHOULDER, nil)
    equal(binds.PADDLEFT, nil)
    for _ = 1, 5 do C:CheckShortcuts(); P:OnUpdate() end
    equal(P.opens, 1)
    equal(binds.PADDLEFT, nil)
    s:update({})
    P:OnUpdate()
    equal(binds.PADDLEFT, "ControllerKeyboardPhrasesPadPADDLEFT")
    equal(binds.PADRSHOULDER, "ControllerKeyboardPhrasesPadPADRSHOULDER")
end)

check("closing while chord held never reopens; a fresh left press works", function()
    local _, s, P, C = fixture()
    s:update({ PADRSHOULDER = true, PADDLEFT = true })
    s:close()
    for _ = 1, 5 do C:CheckShortcuts() end
    equal(P.opens, 1)
    s:update({ PADRSHOULDER = true })
    s:update({ PADRSHOULDER = true, PADDLEFT = true })
    equal(P.opens, 2)
end)

check("left alone and pressing RB after an already held left do not open", function()
    local _, s, P = fixture()
    s:update({ PADDLEFT = true })
    equal(P.opens, 0)
    s:update({ PADDLEFT = true, PADRSHOULDER = true })
    equal(P.opens, 0)
end)

check("combat, menus, keyboard, wheels and trigger layers never queue an opening", function()
    for _, blocked in ipairs({ "combat", "menu", "keyboard", "wheel", "LT", "RT" }) do
        local _, s, P, C = fixture()
        s.combat, s.free, s.keyboard, s.wheel = blocked == "combat", blocked ~= "menu", blocked == "keyboard", blocked == "wheel"
        local keys = { PADRSHOULDER = true, PADDLEFT = true }
        if blocked == "LT" then keys.PADLTRIGGER = true end
        if blocked == "RT" then keys.PADRTRIGGER = true end
        s:update(keys)
        equal(P.opens, 0)
        s.combat, s.free, s.keyboard, s.wheel = false, true, false, false
        keys.PADLTRIGGER, keys.PADRTRIGGER = nil, nil
        C:CheckShortcuts()
        equal(P.opens, 0)
        s:update({})
        s:update({ PADRSHOULDER = true, PADDLEFT = true })
        equal(P.opens, 1)
    end
end)

check("shortcuts share suspension without repeatedly restoring each other's keys", function()
    local _, s, P, C, M = fixture()
    s:update({ PADRSHOULDER = true })
    equal(M.suspendCalls, 2)
    for _ = 1, 10 do C:CheckShortcuts() end
    equal(M.suspendCalls, 2)
    equal(M.resumeCalls, 0)
    s:update({})
    equal(M.resumeCalls, 1)
    equal(M.suspended, nil)
    s:update({ PADRSHOULDER = true, PADDDOWN = true })
    equal(s.configOpens, 1)
    equal(P.opens, 0)
end)

check("existing panel shortcut wins a collision; phrase shortcut can be disabled", function()
    local CK, s, P = fixture()
    CK.db.settings.shortcut = { hold = "PADRSHOULDER", press = "PADDLEFT" }
    equal(P:ShortcutEnabled(), false)
    s:update({ PADRSHOULDER = true, PADDLEFT = true })
    equal(s.configOpens, 1)
    equal(P.opens, 0)
    s:close(); s:update({})
    CK.db.settings.features.configShortcut = false
    equal(P:ShortcutEnabled(), true)
    s:update({ PADRSHOULDER = true, PADDLEFT = true })
    equal(P.opens, 1)
    s:close(); s:update({})
    CK.db.settings.features.phrasesShortcut = false
    s:update({ PADRSHOULDER = true, PADDLEFT = true })
    equal(P.opens, 1)
end)

check("default shortcut works with keyboard and mapping modules off", function()
    local CK, s, P = fixture()
    CK.db.settings.modules.keyboard, CK.db.settings.modules.mapping = false, false
    s:update({ PADRSHOULDER = true, PADDLEFT = true })
    equal(P.opens, 1)
    equal(P:ShortcutLabel(), "[RB] + [DPAD_LEFT]")
end)

print(passed .. " phrase shortcut regressions passed")
