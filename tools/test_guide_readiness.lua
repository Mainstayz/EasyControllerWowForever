-- Guide readiness: real Mapping + Guide code, with a small UI surface.
-- Run from the addon root with Lua 5.1 or tools/run_lua_tests.py.
-- Font measurements here are estimates; the optional wowlua companion
-- checks actual client geometry and captures the last page.
format = string.format
local function equal(actual, expected, why)
    assert(actual == expected, why .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function contains(actual, expected, why)
    assert(actual:find(expected, 1, true), why .. ": missing " .. expected .. " in " .. actual)
end
local function noop() end
local function newRegion(parent)
    local r = { parent = parent, scripts = {}, width = 0, height = 0, size = 13, shown = true }
    if parent then
        parent.children = parent.children or {}
        parent.children[#parent.children + 1] = r
    end
    function r:SetPoint(...) self.point = { ... } end
    function r:ClearAllPoints() self.point = nil end
    function r:SetAllPoints(target) self.allPoints = target or self.parent end
    function r:SetWidth(w) self.width = w end
    function r:SetHeight(h) self.height = h end
    function r:SetSize(w, h) self.width, self.height = w, h end
    function r:GetWidth() return self.width end
    function r:GetHeight() return self.height end
    function r:SetText(value) self.value = value or "" end
    function r:GetText() return self.value or "" end
    function r:SetTextColor(...) self.color = { ... } end
    function r:SetWordWrap(value) self.wrap = value end
    function r:GetStringWidth()
        local width = 0
        for ch in self:GetText():gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            width = width + self.size * (#ch >= 3 and 1 or 0.60)
        end
        return width
    end
    function r:GetStringHeight()
        return (self.size + 1) * (self.wrap and self.width > 0
            and math.max(1, math.ceil(self:GetStringWidth() / self.width)) or 1)
    end
    function r:CreateTexture() return newRegion(self) end
    function r:SetScript(event, fn) self.scripts[event] = fn end
    function r:SetShown(value) self.shown = value end
    function r:IsShown() return self.shown end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetState(state) self.state = state end
    for _, method in ipairs({ "SetJustifyH", "SetJustifyV", "SetTexture", "SetTexCoord", "SetVertexColor",
        "SetAlpha", "SetBlendMode", "RegisterEvent", "SetFrameStrata", "EnableKeyboard",
        "SetPropagateKeyboardInput", "EnableGamePadButton" }) do r[method] = noop end
    return r
end

local TOGGLE = "cmd:CONTROLLERKEYBOARD_TOGGLE"
local PHRASES, CONSUMABLES, USABLE = "wheel:phrases", "wheel:consumables", "wheel:usable"
local BINDINGS = {
    [TOGGLE] = "CONTROLLERKEYBOARD_TOGGLE",
    [PHRASES] = "CLICK ControllerKeyboardPhrasesToggle:LeftButton",
    [CONSUMABLES] = "CLICK ControllerKeyboardWheelToggle:LeftButton",
    [USABLE] = "CLICK ControllerKeyboardUsableToggle:LeftButton",
}

local function fixture(locale)
    local CK = {}
    assert(loadfile("Locales/enUS.lua"))("EasyController", CK)
    if locale ~= "enUS" then
        assert(loadfile("Locales/" .. locale .. ".lua"))("EasyController", CK)
        for key, value in pairs(CK.LOCALES[locale]) do CK.L[key] = value end
    end
    -- Supply proposed keys until the separate locale change lands.
    CK.L.GUIDE_ENTRY_REVIEW = CK.L.GUIDE_ENTRY_REVIEW or (locale == "zhCN"
        and "选择一项查看或补设按键，也可直接完成。"
        or "Select a row to review its key, or finish now.")
    CK.L.GUIDE_KEYBOARD_BINDING = CK.L.GUIDE_KEYBOARD_BINDING or (locale == "zhCN"
        and "在游戏的按键设置 > 插件中设置“%s”；也可用 /ec keyboard 打开。"
        or "Set \"%s\" in the game\039s Key Bindings > AddOns. /ec keyboard also opens it.")
    CK.L.GUIDE_ENTRY_MAPPING_OFF = CK.L.GUIDE_ENTRY_MAPPING_OFF or (locale == "zhCN"
        and "未绑定 · 手柄扩展已关闭" or "No key · Gamepad extras off")
    local st = {
        modules = { keyboard = true, mapping = true }, features = {},
        mapping = {}, replaced = {}, paddles = {}, touchButtons = {},
        wheel = { enabled = true, usableEnabled = true }, supplies = {}, vibration = {},
        inputMethod = "wheel", petalRings = false,
    }
    CK.db = { settings = st }
    local bindings, native = {}, {}
    local cvars = { GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateAlt = "PADRTRIGGER", GamePadEmulateCtrl = "none" }
    CreateFrame = function() return newRegion() end
    UIParent = newRegion()
    GetBindingKey = function(binding) return unpack(bindings[binding] or {}) end
    GetBindingAction = function(key) return native[key] or "" end
    GetBindingText = function(key) return "Key[" .. key .. "]" end
    GetCVar = function(key) return cvars[key] or "none" end
    GetTime = function() return 10 end
    InCombatLockdown = function() return false end
    UnitClass = function() return "Warrior", "WARRIOR" end
    ControllerKeyboard_Toggle = function() error("review must not open native chat") end
    CK.BlockedByCombat = function() return false end
    CK.GetLanguage = function() return { key = "enUS", name = "English" } end
    CK.NewFrame = function(_, _, parent) return newRegion(parent) end
    CK.Paddles = { NativeButton = noop, LiveButton = noop }
    CK.ConsumableWheel = { Fill = noop }
    CK.Config = { Swallow = noop, Toast = noop, Render = noop, Close = noop }
    local K = { C = {}, TEX = "" }
    for i, name in ipairs({ "title", "focus", "dimGold", "focusText", "cream", "cream2", "help", "grey",
        "disabled", "line1", "line3", "boxEdge", "controlBg", "nowBg", "warn", "info", "panel", "bronze", "yours" }) do
        K.C[name] = { i / 30, 0.3, 0.2 }
    end
    local function font(parent, size, color)
        local r = newRegion(parent)
        r.size, r.wrap = size, false
        if color then r:SetTextColor(unpack(color)) end
        return r
    end
    K.Text, K.ChatText = font, font
    K.Solid = function(parent) return newRegion(parent) end
    K.Box = function() return { SetPoints = noop, SetColors = noop } end
    K.Button = function(parent, size)
        local r = newRegion(parent)
        r.label = font(r, size)
        return r
    end
    K.ComboMarkup = function(id, layer) return (layer ~= "" and layer .. " + " or "") .. id end
    K.H = function(keys, label, press) return { keys = keys, label = label, press = press } end
    CK.ConfigKit = K
    assert(loadfile("Mapping.lua"))("EasyController", CK)
    assert(loadfile("Guide.lua"))("EasyController", CK)
    local G = CK.Guide
    G.active, G.mode, G.frame = true, "normal", newRegion()
    G.screens = {}
    for _, step in ipairs({ 4, 5, 6 }) do
        local s = { controls = {}, frame = newRegion(), index = step }
        G["BuildScreen" .. step](G, s, s.frame)
        G.screens[step] = s
    end
    -- Real controls and focus/navigation, without the window chrome.
    G.Render = function(self)
        if not self.active then return end
        local s = self:Current()
        if s.render then s.render() end
        for _, c in ipairs(s.controls) do c:draw(c == self:Focused()) end
        if s.layout then s.layout() end
    end
    G:Go(6)
    local ctx = { CK = CK, G = G, st = st, bindings = bindings, native = native, cvars = cvars, K = K }
    function ctx:status(i) self.G:Render(); return self.G.screens[6].summary[i].frame.status:GetText() end
    function ctx:bind(action, keys)
        self.bindings[BINDINGS[action]] = keys
        for _, key in ipairs(keys) do self.native[key] = BINDINGS[action] end
    end
    return ctx
end

local f = fixture("enUS")
local G, st, L = f.G, f.st, f.CK.L
contains(f:status(1), L.GUIDE_NO_KEY, "unbound keyboard marked")
contains(f:status(1), "/ec keyboard", "unbound keyboard has a real fallback")
for i = 2, 4 do equal(f:status(i), L.GUIDE_NO_KEY, "enabled entry without a binding " .. i) end
-- Existing automatic chat settings do not invent an Enter/pad shortcut.
for _, automatic in ipairs({ false, true }) do
    st.autoOpen, st.onlyWithGamepad = automatic, true
    contains(f:status(1), L.GUIDE_NO_KEY, "auto chat has no Toggle binding")
end
f:bind(TOGGLE, { "CTRL-K", "F10" })
contains(f:status(1), "Key[CTRL-K]", "game Toggle binding")
contains(f:status(1), "Key[F10]", "second Toggle binding")
f:bind(PHRASES, { "F8" })
contains(f:status(2), "Key[F8]", "native phrase binding")
f:bind(CONSUMABLES, { "F6" })
f:bind(USABLE, { "F7" })
contains(f:status(3), "Key[F6]", "native consumables binding")
contains(f:status(4), "Key[F7]", "native usable binding")
print("PASS guide native Toggle, phrases and both wheel bindings; honest missing-key fallback")

f = fixture("enUS")
G, st, L = f.G, f.st, f.CK.L
st.mapping["L4:"] = TOGGLE
st.mapping["L5:"] = PHRASES
st.mapping["R4:LT"] = CONSUMABLES
st.replaced["X:RT"] = USABLE
contains(f:status(1), "L4", "mapped keyboard")
contains(f:status(2), "L5", "mapped phrases")
contains(f:status(3), "LT + R4", "wheel trigger layer")
contains(f:status(4), "RT + X", "active replacement")
equal(next(f.CK.Mapping.bound), nil, "no live overrides in guide")
f:bind(TOGGLE, { "PADPADDLE2" })
equal(#G.EntryKeys(TOGGLE), 1, "duplicate native and mapped label removed")
st.modules.mapping = false
for _, action in ipairs({ PHRASES, CONSUMABLES, USABLE }) do
    equal(#G.KeysOf(action), 0, "mapping off excludes saved bindings")
end
contains(f:status(2), L.GUIDE_ENTRY_MAPPING_OFF, "mapping off explains missing key")
contains(f:status(1), "L4", "native Toggle still works with mapping off")
f:bind(CONSUMABLES, { "F6" })
contains(f:status(3), "Key[F6]", "native wheel binding survives mapping off")
st.modules.keyboard, st.wheel.enabled, st.wheel.usableEnabled = false, false, false
for _, i in ipairs({ 1, 3, 4 }) do equal(f:status(i), L.GUIDE_SUM_OFF, "disabled feature " .. i) end
f:bind(PHRASES, { "F8" })
contains(f:status(2), "Key[F8]", "phrases independent of keyboard")
st.wheel.usableEnabled = nil
contains(f:status(4), L.GUIDE_NO_KEY, "usable default is enabled")
print("PASS guide mapped/replaced keys, module-off states, default usable wheel and independent phrases")

f = fixture("enUS")
G, st, L = f.G, f.st, f.CK.L
st.mapping["TL1:"] = PHRASES
st.mapping["UP:"] = CONSUMABLES -- belongs to the game, not a free assignment
st.replaced["X:RT"] = USABLE
f.cvars.GamePadEmulateAlt = "none"
equal(#G.KeysOf(PHRASES), 0, "disabled touch input")
equal(#G.KeysOf(CONSUMABLES), 0, "stale mapping on native button")
equal(#G.KeysOf(USABLE), 0, "replacement without unique trigger keys")
st.touchButtons.TL1 = true
equal(#G.KeysOf(PHRASES), 0, "unidentified touch input")
st.paddles.TL1 = { key = "F13" }
equal(#G.KeysOf(PHRASES), 1, "enabled and identified touch input")
f.cvars.GamePadEmulateAlt = "PADRTRIGGER"
f:bind(TOGGLE, { "ALT-PAD3" })
equal(#G.EntryKeys(TOGGLE), 0, "native key shadowed by another active replacement")
st.mapping["L4:RT"] = PHRASES
f:bind(TOGGLE, { "PADPADDLE2" })
equal(#G.EntryKeys(TOGGLE), 0, "routed paddle owns its unassigned base layer")
print("PASS guide ignores disabled/unidentified inputs, stale assignments and shadowed native keys")

f = fixture("enUS")
G, st, L = f.G, f.st, f.CK.L
local summary = G.screens[6]
for _ = 1, #summary.rows do G:Press("DOWN") end
equal(G:Focused(), summary.summary[1], "pad can reach keyboard status")
G:Press("A")
equal(G.step, 4, "A opens keyboard settings")
equal(G:Focused(), G.screens[4].module, "keyboard settings focused")
contains(G.screens[4].module.frame.help:GetText(), L.BINDING_TOGGLE, "binding help identifies Toggle")
G:Press("RB")
equal(G.step, 6, "one RB returns to summary")
equal(G:Focused(), summary.summary[1], "return retains origin row")
for i, step in ipairs({ 4, 4, 5, 5 }) do
    summary.summary[i].frame.scripts.OnClick()
    equal(G.step, step, "click reviews correct entry " .. i)
    equal(G.mode, "normal", "review is not forced capture")
    G:Press("B")
    equal(G.step, 6, "B returns from review " .. i)
    equal(G:Focused(), summary.summary[i], "origin row retained " .. i)
end
st.wheel.enabled = false
summary.summary[3].frame.scripts.OnClick()
equal(G:Focused(), G.screens[5].cards[1].toggle, "off wheel focuses enable switch")
G:Press("A")
equal(st.wheel.enabled, true, "one A enables wheel")
G:Press("B")
summary.summary[3].frame.scripts.OnClick()
equal(G:Focused(), G.screens[5].cards[1].key, "on wheel focuses binding control")
G:Press("A")
equal(G.mode, "bind", "binding remains explicit")
G:BindPressed("PAD2")
equal(G.mode, "normal", "ordinary B cancels binding")
equal(G.step, 5, "binding cancellation stays at repair step")
G:Press("B")
equal(G.step, 6, "B after cancellation returns to summary")
-- Bind through Guide capture, then verify the returned status.
summary.summary[3].frame.scripts.OnClick()
G:Press("A")
f.CK.MapPage = {
    Cell = function() return { state = "free" } end,
    Put = function(_, input, layer, action) st.mapping[input.id .. ":" .. layer] = action; return true end,
}
G:BindPressed("PADPADDLE2")
equal(G.mode, "normal", "capture accepted a paddle")
G:Press("RB")
contains(f:status(3), "L4", "summary refreshes after binding")
-- No validation gate or hold before finishing with no keys.
st.mapping = {}
G:Go(6)
summary.finish.frame.scripts.OnClick()
equal(G.active, false, "Finish succeeds without keys")
equal(f.CK.db.onboarding.seen, true, "Finish marks onboarding seen")
print("PASS guide click/pad review, focus, B cancellation, live refresh and unrestricted Finish")

local locales = { "enUS", "zhCN", "frFR", "deDE", "esES", "itIT" }
for _, locale in ipairs(locales) do
    f = fixture(locale)
    G, st = f.G, f.st
    for _, scenario in ipairs({ "missing", "mapping-off", "long-keys", "off" }) do
        st.modules.mapping = scenario ~= "mapping-off"
        st.modules.keyboard, st.wheel.enabled, st.wheel.usableEnabled = scenario ~= "off", scenario ~= "off", scenario ~= "off"
        if scenario == "long-keys" then
            for action in pairs(BINDINGS) do f:bind(action, { "CTRL-ALT-SHIFT-NUMPADMULTIPLY", "CTRL-ALT-SHIFT-NUMPADDIVIDE" }) end
        else
            for binding in pairs(f.bindings) do f.bindings[binding] = nil end
        end
        G:Go(6)
        local s, bottom = G.screens[6], 128
        for i, c in ipairs(s.summary) do
            local r = c.frame
            local y = -r.point[5]
            assert(y >= bottom, locale .. " " .. scenario .. ": rows overlap " .. i)
            assert(r:GetHeight() >= 54 and r:GetWidth() == 288, "comfortable full-row click target")
            assert(r.label:GetStringWidth() <= r.label:GetWidth(), locale .. ": label clipped " .. i)
            assert(28 + r.status:GetStringHeight() <= r:GetHeight(), locale .. ": status clipped " .. i)
            bottom = y + r:GetHeight()
        end
        assert(bottom <= 380, locale .. " " .. scenario .. ": summary touches finish actions")
    end
end
print("PASS guide estimated layout in six locales: missing/off/mapping-off/long localized keys")
