-- Run from the addon root with Lua 5.1; no game client or other test file is needed.
-- Exercise the actual modules and captured secure snippets. The frame/API stubs
-- record layout and actions, and reject insecure protected writes during combat.
local function equal(actual, expected, message)
    assert(actual == expected, (message or "unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function near(actual, expected, message)
    assert(type(actual) == "number" and math.abs(actual - expected) < 0.000001,
        (message or "unexpected coordinate") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local diagonal = math.sqrt(0.5)
local DIRS = { { 0, 1 }, { diagonal, diagonal }, { 1, 0 }, { diagonal, -diagonal },
    { 0, -1 }, { -diagonal, -diagonal }, { -1, 0 }, { -diagonal, diagonal } }
local KEYS = { { "UP" }, { "UP", "RIGHT" }, { "RIGHT" }, { "DOWN", "RIGHT" },
    { "DOWN" }, { "DOWN", "LEFT" }, { "LEFT" }, { "UP", "LEFT" } }

local function pack(...) return { n = select("#", ...), ... } end

local function fixture(slots)
    local f = { combat = false, secure = false, actions = {}, units = { player = true },
        state = { sticks = { { x = 0, y = 0, len = 0 }, { x = 0, y = 0, len = 0 } } } }
    local Frame = {}
    Frame.__index = function(_, key)
        if Frame[key] then return Frame[key] end
        if key:match("^Set") or key:match("^Enable") or key:match("^Register") or key == "Clear" then
            return function() end
        end
    end
    local function protected(frame)
        assert(not (frame.protected and f.combat and not f.secure), "insecure protected write in combat: " .. tostring(frame.name))
    end
    local function frame(name, parent, template)
        local b = setmetatable({ name = name, parent = parent, attrs = {}, refs = {}, scripts = {}, bindings = {},
            shown = true, protected = template ~= nil, points = {} }, Frame)
        if name then _G[name] = b end
        return b
    end
    function Frame:SetAttribute(key, value) protected(self); self.attrs[key] = value end
    function Frame:GetAttribute(key) return self.attrs[key] end
    function Frame:GetFrameRef(key) return self.refs[key] end
    function Frame:GetName() return self.name end
    function Frame:SetPoint(...) protected(self); self.points[#self.points + 1] = { ... } end
    function Frame:ClearAllPoints() protected(self); self.points = {} end
    function Frame:GetPoint(i) return unpack(self.points[i or 1] or {}) end
    function Frame:SetSize(w, h) protected(self); self.width, self.height = w, h end
    function Frame:SetWidth(w) protected(self); self.width = w end
    function Frame:SetHeight(h) protected(self); self.height = h end
    function Frame:GetWidth() return self.width or 1024 end
    function Frame:GetHeight() return self.height or 768 end
    function Frame:GetFrameLevel() return 1 end
    function Frame:GetEffectiveScale() return 1 end
    function Frame:Show() protected(self); self.shown = true end
    function Frame:Hide() protected(self); self.shown = false end
    function Frame:SetShown(show) if show then self:Show() else self:Hide() end end
    function Frame:IsShown() return self.shown end
    function Frame:IsVisible() return self.shown end
    function Frame:SetScript(event, callback) self.scripts[event] = callback end
    function Frame:HookScript() end -- Draws are invoked explicitly; no event loop is simulated.
    function Frame:CreateTexture() return frame(nil, self) end
    function Frame:CreateFontString() return frame(nil, self) end
    function Frame:SetTexture(value) self.texture = value end
    function Frame:SetRotation(value) self.rotation = value end
    function Frame:SetText(value) self.text = value end
    function Frame:SetBindingClick(_, key, name, button) protected(self); self.bindings[key] = { name, button } end
    function Frame:ClearBindings() protected(self); self.bindings = {} end

    format, gmatch, strsub = string.format, string.gmatch, string.sub
    UIParent = frame("UIParent")
    function InCombatLockdown() return f.combat end
    function GetGamePadState() return f.state end
    C_GamePad = { GetDeviceMappedState = GetGamePadState }
    function UnitExists(unit) return f.units[unit] == true end
    function UnitName(unit) return unit end
    function UnitClass() return "Warrior", "WARRIOR" end
    function UnitHealth() return 100 end
    function UnitHealthMax() return 100 end
    function GetTime() return 10 end
    function SetPortraitTexture() end
    function GetMacroInfo(name) if name == "Eight" then return name, 800 end end
    function ClearOverrideBindings(b) b:ClearBindings() end
    function SecureHandlerSetFrameRef(b, key, value) b.refs[key] = value end
    function SecureHandlerWrapScript(b, _, owner, pre, post)
        b.owner = owner
        b.pre = assert(loadstring("return function(self, owner, button, down)\n" .. pre .. "\nend", b.name .. " pre"))()
        if post then b.post = assert(loadstring("return function(self, owner, button, down)\n" .. post .. "\nend", b.name .. " post"))() end
    end
    C_Timer = { After = function() end }
    C_CVar = { GetCVar = function() return "0" end, SetCVar = function() end }
    C_Spell = { GetSpellName = function(id)
        return ({ [433] = "Food", [430] = "Drink", [19705] = "Well Fed", [746] = "First Aid" })[id] or ("Spell " .. id)
    end, GetSpellTexture = function(id) return id end,
        GetSpellCooldown = function() return 0, 0 end, IsSpellUsable = function() return true end,
        IsSpellInRange = function() return true end }
    C_Item = { GetItemNameByID = function(id) return "Item " .. id end,
        GetItemIconByID = function(id) return id end, GetItemCount = function() return 5 end,
        GetItemInfoInstant = function() return nil, nil, nil, nil, nil, 0, 7 end,
        GetItemSpell = function(id) if id == 90003 then return "First Aid" end end }
    C_Container = { GetItemCooldown = function() return 0, 0 end }
    local L = setmetatable({ MYWHEEL_DEFAULT = "Wheel %d" }, { __index = function(_, key) return key end })
    local CK = { L = L, NewFrame = function(_, name, parent, template) return frame(name, parent, template) end,
        db = { settings = { wheel = { enabled = true, categories = {} },
            myWheels = { list = { { id = 1, name = "Test wheel", slots = slots or
                { [1] = "spell:101", [3] = "item:90003", [8] = "macro:Eight" } } } } } },
        ConfigKit = { C = {} }, Config = { Render = function() end, Toast = function() end },
        Mapping = { SpellCast = function(id) return "cast:" .. id end, SpellName = function(id) return "Spell " .. id end },
        Paddles = { SetIcon = function(icon, value) icon:SetTexture(value) end } }
    function CK:GlyphMarkup(key) return key end
    function CK.Paddles:CreateSlot(parent)
        local s = frame(nil, parent)
        for _, key in ipairs({ "icon", "count", "cooldown", "over", "pressed" }) do s[key] = frame(nil, s) end
        return s
    end
    assert(loadfile("ConsumableWheel.lua"))("EasyController", CK)
    assert(loadfile("MyWheels.lua"))("EasyController", CK)
    f.CK, f.W, f.MW = CK, CK.ConsumableWheel, CK.MyWheels
    f.config = CK.db.settings.myWheels.list[1]
    f.consumables, f.usable = {}, {}
    function f.W:Scan() return f.consumables end
    function f.W:ScanUsable() return f.usable end
    function f:secureCall(fn, ...)
        local was = self.secure
        self.secure = true
        local result = pack(pcall(fn, ...))
        self.secure = was
        assert(result[1], result[2])
        return unpack(result, 2, result.n)
    end
    -- Dispatch the action selected by a real pre-snippet, then its real post-
    -- snippet. Even a hidden button with stale action attributes would execute
    -- here, so clearing those attributes is part of the safety assertions.
    function f:press(b, button, down)
        local selected, post = self:secureCall(b.pre, b, b.owner, button, down)
        if selected == false then return false end
        local target = b
        if b:GetAttribute("type") == "click" then target = b:GetAttribute("*clickbutton-" .. (selected or button)) end
        if target then
            local proceed, targetPost = nil, post
            if target ~= b then proceed, targetPost = self:secureCall(target.pre, target, target.owner, "LeftButton", false) end
            if proceed ~= false then
                local kind = target:GetAttribute("type")
                local value = kind and target:GetAttribute(kind)
                if value and (kind == "spell" or kind == "item" or kind == "macro") then
                    self.actions[#self.actions + 1] = { button = target:GetName(), kind = kind, value = value, unit = target:GetAttribute("unit") }
                end
                if target.post and targetPost then self:secureCall(target.post, target, target.owner, button, down) end
            end
        end
        if target ~= b and b.post and post then self:secureCall(b.post, b, b.owner, button, down) end
        return selected
    end
    function f:stick(i, len, offset, index)
        local a = (i - 1) * math.pi / 4 + (offset or 0)
        len = len or 1
        self.state.sticks[index or self.W.frame:GetAttribute("ck-stick") or 1] = { x = math.sin(a) * len, y = math.cos(a) * len, len = len }
    end
    function f:open(wid)
        wid = wid or "1"
        if self.W.frame:IsShown() and self.W.frame:GetAttribute("wheel") == wid then return end
        local b = tonumber(wid) and self.W.myToggles[tonumber(wid)]
            or (wid == "c" and self.W.toggle) or (wid == "u" and self.W.usableToggle) or self.party
        self:press(b, "LeftButton", true)
        equal(self.W.frame:GetAttribute("wheel"), wid, "opened wrong wheel")
        assert(self.W.frame:IsShown(), "nonempty wheel did not open")
        self.W:Paint()
    end
    function f:releaseKeys(i)
        local keys = KEYS[i]
        for _, key in ipairs(keys) do equal(self:press(self.W.letGo, "PADRSTICK" .. key, true), false, "direction press used an action") end
        return self:press(self.W.letGo, "PADRSTICK" .. keys[#keys], false)
    end
    f.W:Fill()
    return f
end

local function pointAt(region, x, y, message)
    local p = region.points[1]
    assert(p, (message or "region") .. " has no position")
    near(p[4], x, message); near(p[5], y, message)
end
local function private(fn, name)
    for i = 1, 30 do
        local key, value = debug.getupvalue(fn, i)
        if key == name then return value end
        if not key then break end
    end
    error("missing upvalue " .. name)
end
local function letGoFixture(slots)
    local f = fixture(slots)
    f.CK.db.settings.wheel.aimStick = "right"
    f.CK.db.settings.wheel.stickRelease = true
    f.W:Fill()
    f:open()
    return f
end

local tests = {
    { "sparse slots 1, 3, 8 keep editor, secure buttons, art and counts aligned", function()
        local f = fixture()
        f:open()
        local W, wheel = f.W, f.W.frame
        equal(wheel:GetAttribute("ck-1-1-n"), 8, "section count")
        equal(wheel:GetAttribute("ck-1-total"), 3, "filled count")
        equal(wheel:GetAttribute("ck-1-pages"), 1, "page count")
        equal(wheel:GetAttribute("ck-1-2-n"), 0, "nonexistent page")
        equal(W.paintedCount, 8, "paint section count")
        assert(W.view.bg.texture:match("ck_wheel_bg_8$"), "background compressed sparse slots")
        local editorPoint = private(f.MW.Editor.Nearest, "slotPoint")
        for i, d in ipairs(DIRS) do
            local ex, ey = editorPoint(i)
            near((ex - 240) / 108, d[1], "editor x " .. i)
            near((186 - ey) / 108, d[2], "editor y " .. i)
            equal(W.buttons[i]:IsShown(), f.config.slots[i] ~= nil, "button visibility " .. i)
            equal(W.segments[i].slot:IsShown(), f.config.slots[i] ~= nil, "icon visibility " .. i)
            if f.config.slots[i] then
                pointAt(W.buttons[i], 128 * d[1], 128 * d[2], "secure slot " .. i)
                pointAt(W.segments[i].slot, 128 * d[1], 128 * d[2], "paint slot " .. i)
                near(W.segments[i].disabled.rotation, -(i - 1) * math.pi / 4, "veil rotation")
            end
        end
        equal(W.buttons[3]:GetAttribute("unit"), "player", "bandage self unit")
        equal(f.MW:Count(f.config), 3, "editor count")
    end },
    { "A, drawing and highlight agree across all eight sectors on either stick", function()
        for _, stick in ipairs({ "left", "right" }) do
            local f = fixture()
            f.CK.db.settings.wheel.aimStick = stick; f.W:Fill()
            for i = 1, 8 do
                for _, offset in ipairs({ -math.pi / 8 + 0.001, 0, math.pi / 8 - 0.001 }) do
                    f:open(); f:stick(i, 1, offset); f.W:Track()
                    local expected = f.config.slots[i] and i or nil
                    equal(f.W:Aimed(), expected, "visual aim " .. i)
                    equal(f.W.aimed, expected, "tracked aim " .. i)
                    equal(f.W.view.highlight:IsShown(), expected ~= nil, "highlight " .. i)
                    if expected then near(f.W.view.highlight.rotation, -(i - 1) * math.pi / 4, "highlight rotation") end
                    local before = #f.actions
                    equal(f:press(f.W.use, "LeftButton", true), expected and ("s" .. i) or false, "secure aim " .. i)
                    equal(#f.actions, before + (expected and 1 or 0), "action count " .. i)
                    if expected then equal(f.actions[#f.actions].button, "ControllerKeyboardWheelSlot" .. i, "wrong action") end
                end
                -- At an exact border either neighbor may win a floating-point
                -- tie, but the visible choice and secure action must agree.
                f:open(); f:stick(i, 1, math.pi / 8); f.W:Track()
                local expected = f.W:Aimed()
                equal(f:press(f.W.use, "LeftButton", true), expected and ("s" .. expected) or false, "sector border disagreed")
            end
        end
    end },
    { "editor direction keys and surviving actions stay put after clearing one slot", function()
        local f = fixture()
        f:open()
        local E = f.MW.Editor
        local moves = { { 1, "RIGHT", 2 }, { 1, "LEFT", 8 }, { 3, "UP", 2 }, { 3, "DOWN", 4 },
            { 5, "LEFT", 6 }, { 5, "RIGHT", 4 }, { 7, "UP", 8 }, { 7, "DOWN", 6 } }
        local function navigation()
            for _, move in ipairs(moves) do
                E.slot, E.zone = move[1], "slots"
                E:Press(move[2]); equal(E.slot, move[3], "editor D-pad move")
            end
        end
        navigation()
        E.id, E.slot = 1, 3
        E:Empty()
        navigation()
        equal(f.W.frame:GetAttribute("ck-1-total"), 2, "count after clear")
        equal(f.MW:Count(f.config), 2, "editor count after clear")
        equal(f.W.paintedCount, 8, "clear changed art")
        for _, i in ipairs({ 1, 8 }) do pointAt(f.W.buttons[i], 128 * DIRS[i][1], 128 * DIRS[i][2], "survivor") end
        for _, key in ipairs({ "type", "item", "spell", "macro", "unit" }) do
            equal(f.W.buttons[3]:GetAttribute(key), nil, "stale cleared attribute " .. key)
        end
        f:stick(3)
        equal(f.W:Aimed(), nil, "cleared slot still aimed")
        equal(f:press(f.W.use, "LeftButton", true), false, "cleared slot used via A")
        f:press(f.W.buttons[3], "LeftButton", false)
        equal(#f.actions, 0, "cleared slot executed a stale mouse action")
    end },
    { "leading holes and missing macros preserve slot 8 and actual totals", function()
        local f = fixture({ [3] = "macro:Missing", [8] = "macro:Eight" })
        f:open()
        equal(f.W.frame:GetAttribute("ck-1-total"), 1, "missing macro counted")
        equal(f.W:PageItems()[3], nil, "missing macro became an action")
        assert(f.W:PageItems()[8], "slot 8 moved to another index")
        equal(f.W:PageItems()[8].name, "Eight", "slot 8 moved")
        pointAt(f.W.buttons[8], -128 * diagonal, 128 * diagonal, "single slot 8")
        for i = 1, 7 do
            f:stick(i)
            equal(f:press(f.W.use, "LeftButton", true), false, "single action expanded into hole " .. i)
        end
        f:stick(8)
        equal(f:press(f.W.use, "LeftButton", true), "s8", "single action lost its direction")
    end },
    { "empty wheels do not open, and clearing the last slot closes and unbinds", function()
        local f = fixture({ [8] = "macro:Eight" })
        f:open()
        f.MW:SetSlot(1, 8, nil)
        equal(f.W.frame:GetAttribute("ck-1-total"), 0, "empty count")
        equal(f.W.frame:GetAttribute("ck-1-1-n"), 8, "empty wheel lost fixed geometry")
        equal(f.W.frame:IsShown(), false, "emptied wheel stayed open")
        equal(next(f.W.frame.bindings), nil, "emptied wheel kept bindings")
        f:press(f.W.myToggles[1], "LeftButton", true)
        equal(f.W.frame:IsShown(), false, "empty wheel opened")
        for i = 1, 8 do
            equal(f.W.buttons[i]:GetAttribute("type"), nil, "empty wheel retained action")
            f:stick(i); equal(f.W:Aimed(), nil, "empty wheel aimed an action")
        end
    end },
    { "neutral and dead zone do nothing even after a previous aim", function()
        local f = fixture()
        f:open(); f:stick(1); f.W:Track()
        for _, len in ipairs({ 0, 0.49, 0.5 }) do
            f:stick(1, len); f.W:Track()
            equal(f.W:Aimed(), nil, "dead zone visual selection")
            equal(f:press(f.W.use, "LeftButton", true), false, "dead zone reused previous action")
        end
        equal(#f.actions, 0, "dead zone executed action")
    end },
    { "hold-to-show release uses the fixed direction or closes without using a hole", function()
        local f = fixture()
        f.CK.db.settings.wheel.hold = true; f.W:Fill()
        for i = 1, 8 do
            f:open(); f:stick(i)
            local before = #f.actions
            equal(f:press(f.W.myToggles[1], "LeftButton", false), f.config.slots[i] and ("s" .. i) or false, "hold release " .. i)
            equal(#f.actions, before + (f.config.slots[i] and 1 or 0), "hold action count")
            equal(f.W.frame:IsShown(), false, "hold release did not close")
        end
        f:open(); f:stick(1, 0)
        equal(f:press(f.W.myToggles[1], "ckupLeftButton", false), false, "router neutral release used")
        equal(f.W.frame:IsShown(), false, "router neutral release stayed open")
        f:open(); f:stick(8)
        equal(f:press(f.W.myToggles[1], "ckupLeftButton", false), "s8", "router release changed slot")
    end },
    { "letting go with analog samples never chooses a neighboring filled slot", function()
        local f = letGoFixture()
        for i = 1, 8 do
            f:open(); f:stick(i, 1)
            local key = "PADRSTICK" .. KEYS[i][1]
            equal(f:press(f.W.letGo, key, true), false, "stick press used")
            f:stick(i, 0)
            local before = #f.actions
            equal(f:press(f.W.letGo, key, false), f.config.slots[i] and ("s" .. i) or false, "analog release " .. i)
            equal(#f.actions, before + (f.config.slots[i] and 1 or 0), "analog release action count")
            -- Empty releases leave it open; start each next flick from a new opening.
            if f.W.frame:IsShown() then f:press(ControllerKeyboardWheelClose, "LeftButton", true) end
        end
    end },
    { "direction-key fallback preserves all eight directions when analog samples are absent", function()
        local f = letGoFixture()
        for i = 1, 8 do
            f:open(); f:stick(i, 0)
            local before = #f.actions
            equal(f:releaseKeys(i), f.config.slots[i] and ("s" .. i) or false, "digital fallback " .. i)
            equal(#f.actions, before + (f.config.slots[i] and 1 or 0), "digital fallback action count")
            if f.W.frame:IsShown() then f:press(ControllerKeyboardWheelClose, "LeftButton", true) end
        end
    end },
    { "rolling from a filled direction into a hole cancels the previous flick action", function()
        for _, len in ipairs({ 1, 0.6 }) do
            local f = letGoFixture()
            f:stick(1, 1); f:press(f.W.letGo, "PADRSTICKUP", true)
            equal(f.W.frame:GetAttribute("ck-aim"), 1, "initial flick aim")
            f:stick(2, len); f:press(f.W.letGo, "PADRSTICKRIGHT", true)
            equal(f.W.frame:GetAttribute("ck-aim"), 2, "empty direction did not replace old aim")
            f:stick(2, 0)
            equal(f:press(f.W.letGo, "PADRSTICKRIGHT", false), false, "empty flick reused old action")
            equal(f:press(f.W.letGo, "PADRSTICKUP", false), false, "late direction release reused old action")
            equal(#f.actions, 0, "empty flick executed action")
        end
        local f = letGoFixture()
        f:stick(1); f:press(f.W.letGo, "PADRSTICKUP", true)
        f:stick(2, 0.6)
        equal(f:press(f.W.letGo, "PADRSTICKUP", false), false, "release sample in a hole reused strongest aim")
        equal(#f.actions, 0, "shorter final aim executed old action")
    end },
    { "clearing a remembered flick slot cannot fall back to another action", function()
        local f = letGoFixture()
        f:stick(3); f:press(f.W.letGo, "PADRSTICKRIGHT", true)
        f.MW:SetSlot(1, 3, nil)
        f:stick(3, 0)
        equal(f:press(f.W.letGo, "PADRSTICKRIGHT", false), false, "removed flick slot redirected")
        equal(#f.actions, 0, "removed flick executed action")
        equal(f.W.frame:GetAttribute("ck-1-total"), 2, "removed flick count")
    end },
    { "B, Escape and toggle cancellation clear bindings and reject late releases", function()
        for _, cancel in ipairs({ "B", "ESCAPE", "toggle" }) do
            local f = letGoFixture()
            f.CK.db.settings.wheel.hold = true; f.W:Fill()
            f:stick(1); f:press(f.W.letGo, "PADRSTICKUP", true)
            if cancel == "toggle" then
                f:press(f.W.myToggles[1], "LeftButton", true)
            else
                local binding = f.W.frame.bindings[cancel == "B" and "PAD2" or "ESCAPE"]
                equal(binding[1], "ControllerKeyboardWheelClose", "cancel binding")
                f:press(_G[binding[1]], "LeftButton", true)
            end
            equal(f.W.frame:IsShown(), false, "cancel left wheel open")
            equal(next(f.W.frame.bindings), nil, "cancel kept bindings")
            f:stick(1, 0)
            equal(f:press(f.W.letGo, "PADRSTICKUP", false), false, "canceled flick used")
            equal(f:press(f.W.myToggles[1], "ckupLeftButton", false), false, "canceled hold used")
            equal(f:press(f.W.use, "LeftButton", false), false, "canceled A release used")
            equal(#f.actions, 0, "cancel executed action")
        end
    end },
    { "combat keeps a stable secure snapshot, defers filling, and permits safe cancellation", function()
        local f = letGoFixture()
        f.combat = true
        f.MW:SetSlot(1, 3, nil)
        equal(f.W.pending, true, "combat fill was not deferred")
        equal(f.W.frame:GetAttribute("ck-1-total"), 3, "combat changed secure count")
        f.W:Paint() -- Protected-write guards also cover layout changes.
        f:stick(2); equal(f:press(f.W.use, "LeftButton", true), false, "combat hole used")
        f:stick(3); equal(f:press(f.W.use, "LeftButton", true), "s3", "combat snapshot moved action")
        equal(f.actions[1].unit, "player", "combat bandage unit")
        f:open(); f:stick(8); f:press(f.W.letGo, "PADRSTICKUP", true)
        f:press(ControllerKeyboardWheelClose, "LeftButton", true)
        f:stick(8, 0); equal(f:press(f.W.letGo, "PADRSTICKUP", false), false, "combat cancel used")
        f.combat = false; f.W:Fill()
        equal(f.W.pending, nil, "deferred fill did not complete")
        equal(f.W.frame:GetAttribute("ck-1-total"), 2, "deferred count")
        f:open(); f:stick(3)
        equal(f:press(f.W.use, "LeftButton", true), false, "post-combat cleared slot used")
    end },
    { "automatic consumable and usable wheels retain dynamic sections and paging", function()
        local f = fixture()
        for i = 1, 9 do f.consumables[i] = { id = 1000 + i, cat = "healthstone" } end
        for i = 1, 10 do f.usable[i] = { kind = "item", id = 2000 + i, cat = "usable" } end
        f.W:Fill()
        for _, wid in ipairs({ "c", "u" }) do
            f:open(wid)
            equal(f.W.frame:GetAttribute("ck-" .. wid .. "-fixed"), nil, "automatic wheel became fixed")
            equal(f.W.frame:GetAttribute("ck-" .. wid .. "-pages"), 2, "automatic pages")
            equal(f.W.paintedCount, 8, "full automatic page")
            equal(f:press(ControllerKeyboardWheelPage, "RB", true), false, "page turn used item")
            f.W:Track()
            local n = wid == "c" and 1 or 2
            equal(f.W.paintedCount, n, "automatic last-page count")
            for i = 1, n do
                local a = (i - 1) * 2 * math.pi / n
                pointAt(f.W.buttons[i], 128 * math.sin(a), 128 * math.cos(a), "automatic secure geometry")
                pointAt(f.W.segments[i].slot, 128 * math.sin(a), 128 * math.cos(a), "automatic art geometry")
            end
            f:stick(1); equal(f:press(f.W.use, "LeftButton", true), "s1", "automatic A use")
        end
        -- Three-item pages must also keep their existing thirds, not eight sectors.
        f.consumables = { { id = 1, cat = "healthstone" }, { id = 2, cat = "healthstone" }, { id = 3, cat = "healthstone" } }
        f.W:Fill(); f:open("c")
        equal(f.W.paintedCount, 3, "three-item page changed")
        pointAt(f.W.buttons[3], -128 * math.sqrt(3) / 2, -64, "three-item third slot")
        f:stick(3); equal(f:press(f.W.use, "LeftButton", true), "s2", "automatic nearest item changed")
    end },
    { "automatic release keeps strongest-sample behavior while custom wheels use current deliberate aim", function()
        local f = letGoFixture()
        for i = 1, 8 do f.consumables[i] = { id = 3000 + i, cat = "healthstone" } end
        f.W:Fill(); f:open("c")
        f:stick(1); f:press(f.W.letGo, "PADRSTICKUP", true)
        f:stick(2, 0.6); f:press(f.W.letGo, "PADRSTICKRIGHT", true)
        equal(f.W.frame:GetAttribute("ck-aim"), 1, "automatic strongest sample changed")
        f:stick(2, 0)
        equal(f:press(f.W.letGo, "PADRSTICKRIGHT", false), "s1", "automatic release changed")
    end },
    { "party wheels keep their five positions and choose the nearest member present", function()
        local f = fixture()
        f.units.party3 = true
        f.party = f.W:PartyToggle(2061)
        f:open("p2061")
        equal(f.W.frame:GetAttribute("ck-p2061-1-n"), 5, "party section count")
        equal(f.W.frame:GetAttribute("ck-p2061-fixed"), nil, "party became fixed custom wheel")
        equal(f.W.buttons[3]:IsShown(), false, "missing member shown")
        -- Party2's own direction (upper left) should still select party3,
        -- the nearest member present, rather than treating the gap as inert.
        local a = math.pi + 2 * 2 * math.pi / 5
        f.state.sticks[2] = { x = math.sin(a), y = math.cos(a), len = 1 }
        equal(f.W:AimedParty(), 4, "party visual nearest member")
        equal(f:press(f.W.use, "LeftButton", true), "s4", "party secure nearest member")
        equal(f.actions[#f.actions].unit, "party3", "party target changed")
        f.units.party3 = nil; f.W:ApplyPage(); f:open("p2061")
        f.state.sticks[2] = { x = 0, y = 0, len = 0 }
        equal(f:releaseKeys(1), "s1", "party digital fallback stopped using nearest present member")
        equal(f.actions[#f.actions].unit, "player", "party fallback target")
    end },
}

local failed = 0
for _, test in ipairs(tests) do
    local ok, err = pcall(test[2])
    if ok then print("PASS: " .. test[1])
    else failed = failed + 1; print("FAIL: " .. test[1] .. " - " .. tostring(err)) end
end
assert(failed == 0, tostring(failed) .. " wheel geometry regression(s) failed")
print("All wheel geometry regressions passed (" .. #tests .. ").")
