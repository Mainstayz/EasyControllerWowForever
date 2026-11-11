local _, CK = ...

-- Adapter between the offline IME and the keyboard. Unconfirmed codes never
-- enter CK.buffer, a game EditBox, a draft's text, or a secure send macro.
local CHAT_COMMANDS = {
    ["/s"] = true, ["/say"] = true, ["/y"] = true, ["/yell"] = true,
    ["/p"] = true, ["/party"] = true, ["/ra"] = true, ["/raid"] = true,
    ["/g"] = true, ["/guild"] = true, ["/o"] = true, ["/officer"] = true,
    ["/w"] = true, ["/whisper"] = true, ["/r"] = true, ["/reply"] = true,
    ["/e"] = true, ["/em"] = true, ["/emote"] = true, ["/me"] = true,
    ["/i"] = true, ["/instance"] = true, ["/rw"] = true,
}
CK.CHINESE_PUNCTUATION = {
    [","] = "，", ["."] = "。", ["?"] = "？", ["!"] = "！",
    [":"] = "：", [";"] = "；", ["("] = "（", [")"] = "）",
}

function CK:InitChineseInput()
    if type(self.db.imeHistory) ~= "table" then self.db.imeHistory = {} end
    self.ChineseIME:Load(self.ZIRANMA_DICT or {}, self.db.imeHistory, self.ZHCN_WOW_SHORTCUTS)
    if self.db.settings.chineseInput == "ziranma" and self.db.settings.inputMethod ~= "wheel"
        and self.db.settings.inputMethod ~= "stick" then self.db.settings.inputMethod = "stick" end
end

function CK:HasChineseInput()
    return self.db and self.db.settings.chineseInput == "ziranma" and self.ChineseIME ~= nil
end

function CK:IsIMEComposing()
    return self.ChineseIME ~= nil and self.ChineseIME:HasComposition()
end

function CK:UsesChineseInput()
    if not self:HasChineseInput() or self.db.settings.chineseLatin then return false end
    if self.field and self.field.IsNumeric and self.field:IsNumeric() then return false end
    local text = self:GetText()
    if text:sub(1, 1) == "/" then
        -- Commands and their arguments stay literal; chat command bodies can
        -- use Chinese. The slash token itself is never put through the IME.
        local command = text:match("^(/[^%s]+)%s")
        if not command then return false end
        command = command:lower()
        return CHAT_COMMANDS[command] or command:match("^/%d+$") ~= nil
    end
    return true
end

function CK:ResetIMEComposition()
    if self.ChineseIME then self.ChineseIME:Reset() end
end

function CK:CancelIMEComposition()
    self:ResetIMEComposition()
    self:Refresh()
end

function CK:AcceptIMECandidate(index)
    if not self:IsIMEComposing() then return false end
    local word = self.ChineseIME:Commit(index or self.state.selected or 1)
    if not word then return false end
    self.buffer = self:GetText() .. word
    self.state.activeRow = "suggestions"
    self:Refresh()
    return true
end

-- Explicit ABC button: keep an English name or abbreviation typed while in
-- Chinese mode. An unsuccessful conversion never silently inserts raw codes.
function CK:CommitIMERaw()
    if not self:IsIMEComposing() then return false end
    local raw = self.ChineseIME:CommitRaw()
    self.buffer = self:GetText() .. raw
    self:Refresh()
    return true
end

function CK:ChangeIMEPage(delta)
    if not self:IsIMEComposing() then return end
    self.ChineseIME:NextPage(delta)
    self:Refresh()
end

local function redraw()
    if not CK.frame then return end
    CK:ApplyFont()
    CK:Layout()
    CK:UpdateMethod()
    CK:UpdateHelp()
    CK:Refresh()
end

function CK:SetChineseInput(mode)
    if mode ~= "off" and mode ~= "ziranma" then return false end
    if self:IsIMEComposing() then self:CommitIMERaw() end
    self.db.settings.chineseInput = mode
    self.db.settings.chineseLatin = false
    if mode == "ziranma" and self.db.settings.inputMethod ~= "wheel"
        and self.db.settings.inputMethod ~= "stick" then self:SetInputMethod("stick") end
    redraw()
    return true
end

function CK:ToggleIMELatin()
    if not self:HasChineseInput() then return end
    if self:IsIMEComposing() then self:CommitIMERaw() end
    self.db.settings.chineseLatin = not self.db.settings.chineseLatin
    redraw()
end
