-- The addon's own interface language (Look › Interface language, /ec uilang):
-- picked in the saved variables, put over English when the files load, on any
-- client; Chinese controls bring the Chinese input with them.
-- Run from the addon root with Lua 5.1 or tools/run_lua_tests.py.
format = format or string.format
CreateFrame = function() error("unexpected frame creation") end

local englishResource = {}
assert(loadfile("Locales/enUS.lua"))("EasyController", englishResource)
local english = englishResource.L
local chineseResource = {}
assert(loadfile("Locales/enUS.lua"))("EasyController", chineseResource)
assert(loadfile("Locales/zhCN.lua"))("EasyController", chineseResource)
local chinese = chineseResource.LOCALES.zhCN

-- A fresh addon table, its files' labels made as the game would at load:
-- the saved variables are there before the files (the game loads them first)
local function load(chosen, client)
    local CK = {}
    assert(loadfile("Locales/enUS.lua"))("EasyController", CK)
    assert(loadfile("Locales/zhCN.lua"))("EasyController", CK)
    ControllerKeyboardDB = chosen and { settings = { uiLanguage = chosen } } or nil
    GetLocale = function() return client end
    assert(loadfile("Core.lua"))("EasyController", CK)
    return CK
end

local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

-- Picked: Chinese labels on an English client
local picked = load("zhCN", "enUS")
equal(picked.uiLocale, "zhCN", "picked interface language")
equal(picked.L.TAB_KEYBOARD, chinese.TAB_KEYBOARD, "picked labels")
equal(picked.L.SEND, chinese.SEND, "picked button")
equal(BINDING_NAME_CONTROLLERKEYBOARD_TOGGLE, chinese.BINDING_TOGGLE, "picked key binding")
assert(picked:UiIsChinese(), "picked Chinese controls")

-- Nothing picked: the client's own language, as before
local automatic = load("auto", "enUS")
equal(automatic.uiLocale, "enUS", "auto interface language")
equal(automatic.L.TAB_KEYBOARD, english.TAB_KEYBOARD, "auto labels")
assert(not automatic:UiIsChinese(), "auto English controls")
local absent = load(nil, "enUS")
equal(absent.uiLocale, "enUS", "no setting yet")
equal(absent.L.TAB_KEYBOARD, english.TAB_KEYBOARD, "no setting yet labels")

-- A value we don't have (edited by hand): the client's
local unknown = load("xxXX", "enUS")
equal(unknown.uiLocale, "enUS", "unknown pick ignored")
equal(unknown.L.TAB_KEYBOARD, english.TAB_KEYBOARD, "unknown pick labels")

-- A Chinese client keeps its Chinese (the existing behaviour)
local clientChinese = load("auto", "zhCN")
equal(clientChinese.uiLocale, "zhCN", "Chinese client")
equal(clientChinese.L.TAB_KEYBOARD, chinese.TAB_KEYBOARD, "Chinese client labels")
-- ...and a client we don't translate keeps English
local otherClient = load("auto", "jaJP")
equal(otherClient.uiLocale, "jaJP", "client without a resource")
equal(otherClient.L.TAB_KEYBOARD, english.TAB_KEYBOARD, "client without a resource labels")
assert(not otherClient:UiIsChinese(), "a client without a resource is not Chinese")

-- The pick kept by the command and the panel; Chinese controls bring the
-- Chinese input, and going back to English leaves it on
local setting = load("auto", "enUS")
setting.db = { settings = { uiLanguage = "auto", chineseInput = "off", inputMethod = "wheel" } }
local asked = {}
setting.SetChineseInput = function(self, mode)
    asked[#asked + 1] = mode
    self.db.settings.chineseInput = mode
end
assert(setting:SetUiLanguage("zhCN"), "zhCN accepted")
equal(setting.db.settings.uiLanguage, "zhCN", "zhCN kept")
equal(setting.db.settings.chineseInput, "ziranma", "Chinese controls turn the Chinese input on")
equal(#asked, 1, "the Chinese input set once")
assert(setting:SetUiLanguage("enUS"), "enUS accepted")
equal(setting.db.settings.uiLanguage, "enUS", "enUS kept")
equal(setting.db.settings.chineseInput, "ziranma", "English controls leave the Chinese input on")
equal(#asked, 1, "nothing else set")
assert(not setting:SetUiLanguage("klingon"), "an unknown pick is refused")
equal(setting.db.settings.uiLanguage, "enUS", "a refused pick changes nothing")
-- The command's short names are not locale names: refused here as well
assert(not setting:SetUiLanguage("zh"), "a short name is refused")
-- Off again: picked Chinese, the Chinese input comes back
setting.db.settings.chineseInput = "off"
assert(setting:SetUiLanguage("zhCN"), "zhCN accepted again")
equal(setting.db.settings.chineseInput, "ziranma", "turned on again when off")

-- A hand-edited value goes back to the client's (InitDB, CleanEntries)
local cleaned = { uiLanguage = "xxXX", mapping = {}, replaced = {},
    supplies = { list = {}, custom = {} }, myWheels = { list = {} }, wheel = {} }
picked.CleanEntries(cleaned)
equal(cleaned.uiLanguage, "auto", "a value we don't have goes back to auto")
local kept = { uiLanguage = "zhCN", mapping = {}, replaced = {},
    supplies = { list = {}, custom = {} }, myWheels = { list = {} }, wheel = {} }
picked.CleanEntries(kept)
equal(kept.uiLanguage, "zhCN", "a value we have is kept")
print("PASS interface language: picked, automatic, unknown, client fallback and the Chinese input")
