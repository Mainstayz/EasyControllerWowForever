-- Integration regressions: real message/input/IME modules, simulated WoW API.
-- Run with Lua 5.1 from the addon root, or tools/run_lua_tests.py.
local passed = 0
local function check(name, fn)
    fn()
    passed = passed + 1
    print("PASS " .. name)
end
local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function fixture(realDictionary)
    local CK = {}
    local clock = 100
    GetLocale = function() return "enUS" end
    GetTime = function() return clock end
    InCombatLockdown = function() return false end
    format = string.format
    wipe = function(t) for k in pairs(t) do t[k] = nil end end
    ClearOverrideBindings = function() end
    local binds = {}
    SetOverrideBindingClick = function(_, _, key, button) binds[key] = button end
    SetOverrideBinding = function(_, _, key, action) binds[key] = action end
    ChatTypeInfo = nil
    DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    C_Timer = { After = function(_, fn) fn() end }
    ControllerKeyboardDB = nil
    assert(loadfile("Locales/enUS.lua"))("EasyController", CK)
    assert(loadfile("Core.lua"))("EasyController", CK)
    CK:InitDB()
    CK.db.settings.chineseInput = "ziranma"
    CK.db.settings.chineseLatin = false
    assert(loadfile("ChineseIME.lua"))("EasyController", CK)
    assert(loadfile("ChineseInput.lua"))("EasyController", CK)
    assert(loadfile("Message.lua"))("EasyController", CK)
    assert(loadfile("Input.lua"))("EasyController", CK)
    assert(loadfile("QuestLinks.lua"))("EasyController", CK)
    CK.ZIRANMA_DICT = {
        ni = "你 尼 呢 泥 拟 逆 妮 腻 倪 昵 匿", hk = "好 号 浩",
        nihk = "你好", vsgo = "中国", ui = "是 时 事 市 十 使 世 史 式 师 试 诗",
    }
    if realDictionary then assert(loadfile("Dict_zhCN.lua"))("EasyController", CK) end
    CK:InitChineseInput()
    CK.Predict = {
        Context = function() return {} end,
        Query = function() return {} end,
        QueryCommands = function() return {} end,
        LearnCommand = function() end,
    }
    local method = { Reset = function() end, buttons = {} }
    CK.GetMethod = function() return method end
    CK.DisplayChar = function(self, ch)
        return (self.state.shift or self.state.caps) and CK.Upper(ch) or ch
    end
    local function noop() end
    CK.UpdatePreview, CK.UpdateSuggestions, CK.UpdateIMEBar = noop, noop, noop
    CK.UpdateChannels, CK.UpdateRows, CK.UpdateMethod = noop, noop, noop
    CK.ApplyFont, CK.Layout, CK.UpdateHelp = noop, noop, noop
    CK.EnableButtons = noop
    CK.frame = {
        shown = true, IsShown = function(self) return self.shown end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        Raise = noop,
    }
    CK.sendButton = {
        attrs = {}, SetAttribute = function(self, k, v) self.attrs[k] = v end,
        Show = noop, Hide = noop,
    }
    CK.buffer, CK.standalone = "", true
    CK.chatAttrs = { chatType = "SAY" }
    local function typeCode(code)
        for c in code:gmatch(".") do CK:TypeChar(c) end
    end
    local function clickA()
        CK:PrepareSend(true)
        equal(CK.sendButton.attrs.macrotext, "")
        CK:FinishSend(true)
        CK:PrepareSend(false)
        equal(CK.sendButton.attrs.macrotext, "")
        CK:FinishSend(false)
    end
    return CK, typeCode, clickA, binds, function(t) clock = t end
end

check("preedit stays out of the message and secure macro", function()
    local CK, typeCode = fixture()
    typeCode("nihk")
    equal(CK:GetText(), "")
    equal(CK.ChineseIME:GetCode(), "nihk")
    equal(CK:BuildMacroText(), nil)
    equal(CK.state.suggestions[1], "你好")
end)

check("one A press commits once and both edges suppress sending", function()
    local CK, typeCode, clickA = fixture()
    typeCode("nihk")
    clickA()
    equal(CK:GetText(), "你好")
    equal(CK.ChineseIME:GetCode(), "")
    CK:PrepareSend(true)
    equal(CK.sendButton.attrs.macrotext, "/s 你好")
end)

check("A does not consume a second syllable on release", function()
    local CK, typeCode, clickA = fixture()
    typeCode("nivsgo")
    clickA()
    equal(CK:GetText(), "你")
    equal(CK.ChineseIME:GetCode(), "vsgo")
    clickA()
    equal(CK:GetText(), "你中国")
    equal(CK.ChineseIME:GetCode(), "")
end)

check("invalid codes never send an already committed message", function()
    local CK, typeCode, clickA = fixture()
    CK.buffer = "等一下"
    typeCode("zz")
    clickA()
    equal(CK:GetText(), "等一下")
    equal(CK.ChineseIME:GetCode(), "zz")
end)

check("space and R3 commit without appending western spaces", function()
    local CK, typeCode = fixture()
    typeCode("ni")
    CK:Space()
    equal(CK:GetText(), "你")
    typeCode("hk")
    CK:RowSelect()
    equal(CK:GetText(), "你好")
end)

check("backspace edits the code before removing a UTF-8 character", function()
    local CK, typeCode = fixture()
    CK.buffer = "你好😀"
    typeCode("ni")
    CK:Backspace()
    equal(CK.ChineseIME:GetCode(), "n")
    equal(CK:GetText(), "你好😀")
    CK:Backspace()
    CK:Backspace()
    equal(CK:GetText(), "你好")
end)

check("B cancels only composition including in standalone/touch mode", function()
    local CK, typeCode = fixture()
    CK.buffer = "队伍"
    typeCode("ni")
    equal(CK:ButtonAction("PAD2"), "CancelIMEComposition")
    CK:OnPadButton("PAD2")
    equal(CK:GetText(), "队伍")
    equal(CK:IsIMEComposing(), false)
    equal(CK:IsOpen(), true)
end)

check("B is captured even when only an uncommitted code exists", function()
    local CK, typeCode, _, binds = fixture()
    CK.standalone, CK.bindingsActive = false, true
    CK.editBox = { GetAttribute = function(_, k) if k == "chatType" then return "SAY" end end }
    typeCode("n")
    equal(binds.PAD2, "ControllerKeyboardPadPAD2")
    CK:CancelMessage()
    equal(binds.PAD2, nil)
end)

check("D-pad crosses page boundaries without losing the selected candidate", function()
    local CK, typeCode = fixture()
    typeCode("ui")
    for _ = 1, 5 do CK:NextSuggestion() end
    equal(CK.imePage, 2)
    equal(CK.state.selected, 1)
    local word = CK.state.suggestions[1]
    CK:AcceptSuggestion()
    equal(CK:GetText(), word)
end)

check("Chinese punctuation commits text and preserves UTF-8", function()
    local CK, typeCode = fixture()
    typeCode("nihk")
    CK:TypeChar(",")
    equal(CK:GetText(), "你好，")
    typeCode("vsgo")
    CK:TypeChar("!")
    equal(CK:GetText(), "你好，中国！")
end)

check("English mode and ABC preserve literal letters", function()
    local CK, typeCode = fixture()
    typeCode("ni")
    CK:CommitIMERaw()
    equal(CK:GetText(), "ni")
    CK:ToggleIMELatin()
    typeCode("raid")
    equal(CK:GetText(), "niraid")
    equal(CK:IsIMEComposing(), false)
    CK:ToggleIMELatin()
    typeCode("hk")
    CK:Space()
    equal(CK:GetText(), "niraid好")
end)

check("addon commands stay literal while chat command bodies accept Chinese", function()
    local CK, typeCode = fixture()
    typeCode("/ec")
    CK:Space()
    typeCode("config")
    equal(CK:GetText(), "/ec config")
    equal(CK:IsIMEComposing(), false)
    CK.buffer = "/p "
    typeCode("nihk")
    CK:Space()
    equal(CK:GetText(), "/p 你好")
end)

check("a prompt sees committed Chinese only and needs a separate confirmation", function()
    local CK, typeCode = fixture()
    local field = { value = "", GetText = function(self) return self.value end,
        SetText = function(self, s) self.value = s end }
    local result
    CK:OpenPrompt("Name", "", function(value) result = value end, field)
    typeCode("ni")
    equal(field.value, "")
    CK:FinishPrompt(true)
    equal(result, nil)
    equal(field.value, "你")
    CK:FinishPrompt(true)
    equal(result, "你")
end)

check("combat drafts restore codes even when no Chinese was committed yet", function()
    local CK, typeCode = fixture()
    typeCode("ni")
    CK:Close("combat")
    equal(CK.draft.text, "")
    equal(CK.draft.imeCode, "ni")
    equal(CK:IsIMEComposing(), false)
    local eb = { GetText = function() return "" end,
        GetAttribute = function(_, k) if k == "chatType" then return "SAY" end end }
    CK:Open(eb)
    equal(CK:GetText(), "")
    equal(CK.ChineseIME:GetCode(), "ni")
    equal(CK.state.suggestions[1], "你")
end)

check("expired drafts do not revive old composition", function()
    local CK, typeCode, _, _, time = fixture()
    typeCode("ni")
    CK:Close("combat")
    time(800)
    local eb = { GetText = function() return "" end,
        GetAttribute = function(_, k) if k == "chatType" then return "SAY" end end }
    CK:Open(eb)
    equal(CK:IsIMEComposing(), false)
    equal(CK:GetText(), "")
end)

check("touch transition keeps composition and physical replacement resets it", function()
    local CK, typeCode = fixture()
    CK.standalone = false
    local eb = { GetText = function() return "实体输入" end,
        GetAttribute = function(_, k) if k == "chatType" then return "SAY" end end }
    CK.editBox = eb
    typeCode("ni")
    CK:EnterStandalone()
    equal(CK.ChineseIME:GetCode(), "ni")
    CK.editBox = eb
    CK:OnChatTextChanged(eb, true)
    equal(CK:IsIMEComposing(), false)
    equal(CK:GetText(), "实体输入")
end)

check("numeric fields bypass composition", function()
    local CK = fixture()
    CK.field = { IsNumeric = function() return true end }
    equal(CK:UsesChineseInput(), false)
end)

check("narrow candidate layout preserves all five choices including long phrases", function()
    local CK, typeCode = fixture()
    typeCode("ui")
    assert(loadfile("UI.lua"))("EasyController", CK)
    local function region()
        return {
            ClearAllPoints = function() end,
            SetPoint = function(self, _, _, _, x, y) self.x, self.y = x, y end,
            SetSize = function(self, w, h) self.w, self.h = w, h end,
            SetWordWrap = function() end,
        }
    end
    local f = CK.frame
    f.sugg, f.suggWidth, f.suggX, f.suggY, f.suggHeight = {}, 236, 52, 100, 44
    for i = 1, 5 do f.sugg[i] = region(); f.sugg[i].label = region() end
    CK.state.suggestions = { "是", "时", "这是一条很长的候选短语", "市", "十" }
    CK:LayoutSuggestions()
    equal(#CK.state.suggestions, 5)
    equal(f.sugg[5].h, 40)
    assert(f.sugg[5].x + f.sugg[5].w <= 288.01)
end)

check("holding D-pad up switches Chinese/English without a touch screen", function()
    local CK, typeCode, _, _, time = fixture()
    typeCode("ni")
    CK:OnPadButton("PADDUP")
    time(100.2)
    CK:OnPadButtonUp("PADDUP")
    equal(CK.db.settings.chineseLatin, false)
    equal(CK.ChineseIME:GetCode(), "ni")
    CK:OnPadButton("PADDUP")
    time(100.8)
    CK:OnPadButtonUp("PADDUP")
    equal(CK.db.settings.chineseLatin, true)
    equal(CK:GetText(), "ni")
    equal(CK:IsIMEComposing(), false)
    CK:OnPadButton("PADDUP")
    time(101.5)
    CK:OnPadButtonUp("PADDUP")
    equal(CK.db.settings.chineseLatin, false)
end)

check("the production dictionary uses standard Ziranma for actual chat phrases", function()
    local CK, typeCode = fixture(true)
    local examples = {
        { "nihk", "你好" }, { "xxxx", "谢谢" }, { "vsgo", "中国" },
        { "zudv", "组队" }, { "fubf", "副本" }, { "vilc", "治疗" },
        { "plmlhh", "拍卖行" }, { "isqy", "重庆" }, { "jpui", "军事" },
    }
    for _, example in ipairs(examples) do
        CK.buffer = ""
        typeCode(example[1])
        local found = false
        for _ = 1, CK.imePages do
            for i, word in ipairs(CK.state.suggestions) do
                if word == example[2] then
                    CK:AcceptSuggestion(i)
                    found = true
                    break
                end
            end
            if found then break end
            CK:ChangeIMEPage(1)
        end
        assert(found, "missing production candidate " .. example[1] .. " -> " .. example[2])
        equal(CK:GetText(), example[2])
        equal(CK.ChineseIME:GetCode(), "")
    end
end)

check("Chinese input selects a CJK font even on an English client", function()
    local CK = fixture()
    CK.Config = { pages = {}, NewRailPage = function(def) return def end }
    CK.MyWheels = { TabPage = function(_, page) return page end }
    STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    assert(loadfile("Options.lua"))("EasyController", CK)
    equal(CK:GetFontPath(), "Fonts\\ARKai_T.TTF")
    CK.db.settings.chineseInput = "off"
    equal(CK:GetFontPath(), "Fonts\\FRIZQT__.TTF")
end)

check("unsupported legacy layouts cannot bypass candidate confirmation", function()
    local CK = fixture()
    CK.db.settings.inputMethod = "consoleport"
    CK:InitChineseInput()
    equal(CK.db.settings.inputMethod, "stick")
    assert(loadfile("UI.lua"))("EasyController", CK)
    CK.Methods = { consoleport = {}, stick = {} }
    CK:SetInputMethod("consoleport")
    equal(CK.db.settings.inputMethod, "stick")
end)

check("the split keyboard uses QWERTY in Chinese mode without changing saved layout", function()
    local CK = fixture()
    assert(loadfile("StickKeyboard.lua"))("EasyController", CK)
    local method = CK.Methods.stick
    method.sets = { qwerty = {}, azerty = {} }
    CK.db.settings.kbLayout = "azerty"
    equal(method:ActiveSet(), method.sets.qwerty)
    equal(CK.db.settings.kbLayout, "azerty")
    CK.db.settings.chineseInput = "off"
    equal(method:ActiveSet(), method.sets.azerty)
end)

print(passed .. " Chinese input integration regressions passed")
