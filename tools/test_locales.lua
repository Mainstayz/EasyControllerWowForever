-- Check Chinese resource coverage, format arguments, commands and fallback.
-- Run from the addon root with Lua 5.1 or tools/run_lua_tests.py.
local CK = {}
assert(loadfile("Locales/enUS.lua"))("EasyController", CK)
assert(loadfile("Locales/zhCN.lua"))("EasyController", CK)
local english, chinese = CK.L, CK.LOCALES.zhCN
local englishKeyboard = english.TAB_KEYBOARD
local strings, keys = 0, 0
local function tokens(text, pattern)
    local out = {}
    for value in text:gmatch(pattern) do out[#out + 1] = value end
    return table.concat(out, "\n")
end
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function checkValue(source, target, path)
    equal(type(target), type(source), path .. " type")
    if type(source) == "table" then
        for key, value in pairs(source) do
            checkValue(value, target[key], path .. "." .. tostring(key))
        end
        for key in pairs(target) do assert(source[key] ~= nil, path .. ": unknown key " .. tostring(key)) end
    elseif type(source) == "string" then
        strings = strings + 1
        assert(target ~= "", path .. ": empty translation")
        local formats = "%%[-+ #0]*%d*%.?%d*[cdiouxXeEfgGqs%%]"
        equal(tokens(target, formats), tokens(source, formats), path .. " format arguments")
        equal(tokens(target, "|c%x%x%x%x%x%x%x%x"), tokens(source, "|c%x%x%x%x%x%x%x%x"), path .. " colour codes")
        equal(tokens(target, "|r"), tokens(source, "|r"), path .. " colour endings")
        if source:match("^@%u+$") or source:match("^/[%a%d]+$") then
            equal(target, source, path .. " command token")
        end
    end
end
for key, value in pairs(english) do
    keys = keys + 1
    checkValue(value, chinese[key], key)
end
for key in pairs(chinese) do assert(english[key] ~= nil, "unknown Chinese key " .. key) end
print("PASS all " .. keys .. " English keys and " .. strings .. " strings have compatible Chinese translations")

-- The locale overlay must run before settings and widgets capture their labels.
GetLocale = function() return "zhCN" end
CreateFrame = function() error("unexpected frame creation") end
assert(loadfile("Core.lua"))("EasyController", CK)
equal(CK.L.TAB_KEYBOARD, chinese.TAB_KEYBOARD, "Chinese keyboard tab")
equal(CK.L.CHANNEL_NAMES[1], chinese.CHANNEL_NAMES[1], "Chinese chat channel")
equal(CK.L.PHRASE_ROWS[1][1], chinese.PHRASE_ROWS[1][1], "Chinese phrase category")
equal(BINDING_NAME_CONTROLLERKEYBOARD_TOGGLE, chinese.BINDING_TOGGLE, "Chinese key binding")
print("PASS zhCN client loads Chinese labels, channels, phrase rows and key bindings")

-- Other clients keep the English base when they have no locale resource.
local fallback = {}
assert(loadfile("Locales/enUS.lua"))("EasyController", fallback)
assert(loadfile("Locales/zhCN.lua"))("EasyController", fallback)
GetLocale = function() return "jaJP" end
assert(loadfile("Core.lua"))("EasyController", fallback)
equal(fallback.L.TAB_KEYBOARD, englishKeyboard, "English fallback")
print("PASS unsupported locales retain the English base")
