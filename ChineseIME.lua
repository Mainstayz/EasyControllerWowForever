local _, CK = ...

local I = {}
CK.ChineseIME = I

local MAX_CODE = 32
local MAX_HISTORY = 1024       -- code/text pairs, not just distinct codes
local MAX_COUNT = 9999
local MAX_TEXT_BYTES = 128
local DEFAULT_LIMIT = 5

local dictionary, history, shortcuts = {}, {}, {}
local code, page, pageLimit = "", 1, DEFAULT_LIMIT
local cachedCandidates

local function invalidate()
    page, cachedCandidates = 1, nil
end

local function validCode(value)
    -- Retain learned shortcuts even if a later load temporarily omits their
    -- data table. History alone never injects a candidate into query results.
    return type(value) == "string" and #value >= 2 and #value <= MAX_CODE
        and not value:find("[^a-z]")
end

local function validCount(value)
    if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
        return nil
    end
    value = math.floor(math.min(value, MAX_COUNT))
    if value >= 1 then return value end
end

local function continuation(byte)
    return byte and byte >= 128 and byte <= 191
end

-- Lua 5.1 has no UTF-8 library. Reject damaged tokens and oversized saved
-- history keys without depending on WoW globals or the process locale.
local function validText(text)
    if type(text) ~= "string" or #text == 0 or #text > MAX_TEXT_BYTES then return false end
    local pos, size = 1, #text
    while pos <= size do
        local a, b, c, d = text:byte(pos, pos + 3)
        if a < 128 then
            if a <= 32 or a == 127 then return false end
            pos = pos + 1
        elseif a >= 194 and a <= 223 then
            if not continuation(b) then return false end
            pos = pos + 2
        elseif a >= 224 and a <= 239 then
            if not continuation(b) or not continuation(c)
                or (a == 224 and b < 160) or (a == 237 and b > 159) then return false end
            pos = pos + 3
        elseif a >= 240 and a <= 244 then
            if not continuation(b) or not continuation(c) or not continuation(d)
                or (a == 240 and b < 144) or (a == 244 and b > 143) then return false end
            pos = pos + 4
        else
            return false
        end
    end
    return true
end

-- Keep only the current composition's list. Query at most 16 complete
-- double-pinyin prefixes and one exact shortcut; never enumerate either table.
-- Shortcuts match the entire code so they cannot consume the first syllable
-- of a longer double-pinyin word or sentence.
local function candidates()
    if cachedCandidates then return cachedCandidates end
    local out, seen = {}, {}
    for length = #code, 2, -1 do
        local prefix = code:sub(1, length)
        local full = length % 2 == 0 and rawget(dictionary, prefix)
        local shortcut = length == #code and rawget(shortcuts, code)
        if type(full) == "string" or type(shortcut) == "string" then
            local row = rawget(history, prefix)
            if type(row) ~= "table" then row = nil end
            local group, learned = {}, false
            local function append(value)
                if type(value) ~= "string" then return end
                -- Explicit ASCII separators avoid splitting a UTF-8 continuation
                -- byte that some locales classify as whitespace through %s.
                for text in value:gmatch("[^ \t\r\n]+") do
                    if not seen[text] and validText(text) then
                        seen[text] = true
                        local count = row and validCount(rawget(row, text)) or 0
                        count = count or 0
                        if count > 0 then learned = true end
                        group[#group + 1] = {
                            text = text, length = length, count = count, rank = #group + 1,
                        }
                    end
                end
            end
            append(shortcut)
            append(full)
            -- Longer consumption always precedes shorter consumption. History
            -- only changes ordering inside one group; ties keep dictionary order.
            if learned then
                table.sort(group, function(a, b)
                    if a.count ~= b.count then return a.count > b.count end
                    return a.rank < b.rank
                end)
            end
            for i = 1, #group do out[#out + 1] = group[i] end
        end
    end
    cachedCandidates = out
    return out
end

local function totalPages(list)
    return math.max(1, math.ceil(#list / pageLimit))
end

function I:Reset()
    code, pageLimit = "", DEFAULT_LIMIT
    invalidate()
end

-- history[matchedCode][text] = positive use count. Keep the caller's root
-- table so the integrating addon can persist it directly in SavedVariables.
-- Orphaned history never creates candidates absent from either data table.
function I:Load(dict, savedHistory, shortcutDict)
    dictionary = type(dict) == "table" and dict or {}
    shortcuts = type(shortcutDict) == "table" and shortcutDict or {}
    history = type(savedHistory) == "table" and savedHistory ~= dictionary
        and savedHistory ~= shortcuts and savedHistory or {}
    self:Prune()
    self:Reset()
end

function I:SetCode(value)
    local letters = {}
    if type(value) == "string" then
        for ch in value:gmatch("[A-Za-z]") do
            letters[#letters + 1] = ch:lower()
            if #letters == MAX_CODE then break end
        end
    end
    code = table.concat(letters)
    invalidate()
end

function I:GetCode()
    return code
end

function I:GetDisplayCode()
    if type(rawget(shortcuts, code)) == "string" then return code end
    local syllables = {}
    for pos = 1, #code, 2 do syllables[#syllables + 1] = code:sub(pos, pos + 1) end
    return table.concat(syllables, " ")
end

function I:HasComposition()
    return code ~= ""
end

function I:Feed(ch)
    if type(ch) ~= "string" or #ch ~= 1 then return false end
    ch = ch:lower()
    if not ch:match("^[a-z]$") then return false end
    if #code < MAX_CODE then
        code = code .. ch
        invalidate()
    end
    return true
end

function I:Backspace()
    if code == "" then return false end
    code = code:sub(1, -2)
    invalidate()
    return true
end

-- Empty results still report page 1 of 1. Omitting limit keeps the last
-- width; changing it starts on page 1. Invalid widths use the default five.
function I:Candidates(limit)
    if limit ~= nil then
        if type(limit) ~= "number" or limit ~= limit or limit < 1 or limit == math.huge then
            limit = DEFAULT_LIMIT
        else
            limit = math.floor(limit)
        end
        if limit ~= pageLimit then page, pageLimit = 1, limit end
    end
    local list = candidates()
    local pages = totalPages(list)
    page = math.min(page, pages)
    local visible, first = {}, (page - 1) * pageLimit + 1
    for pos = first, math.min(first + pageLimit - 1, #list) do
        visible[#visible + 1] = list[pos].text
    end
    return visible, page, pages
end

-- Wrap in both directions. False means that the visible page did not move.
function I:NextPage(delta)
    if delta == nil then delta = 1 end
    if type(delta) ~= "number" or delta ~= delta or delta == math.huge
        or delta == -math.huge or delta % 1 ~= 0 or delta == 0 then return false end
    local pages = totalPages(candidates())
    local nextPage = (page - 1 + delta % pages) % pages + 1
    if nextPage == page then return false end
    page = nextPage
    return true
end

-- A successful selection consumes precisely its matched prefix, leaving any
-- unfinished suffix for the next selection. Never touch CK.buffer or the UI.
function I:Commit(index)
    if index == nil then index = 1 end
    if type(index) ~= "number" or index ~= index or index < 1
        or index > pageLimit or index % 1 ~= 0 then return nil end
    local entry = candidates()[(page - 1) * pageLimit + index]
    if not entry then return nil end
    local prefix = code:sub(1, entry.length)
    local row = rawget(history, prefix)
    if type(row) ~= "table" or row == history or row == dictionary or row == shortcuts then
        row = {}
        rawset(history, prefix, row)
    end
    rawset(row, entry.text, math.min(MAX_COUNT, (validCount(rawget(row, entry.text)) or 0) + 1))
    code = code:sub(entry.length + 1)
    self:Prune()
    return entry.text
end

function I:CommitRaw()
    local raw = code
    self:Reset()
    return raw
end

-- Sanitize in place on load, after learning, or when explicitly requested.
-- Frequency wins; equal counts use code/text byte order for deterministic
-- eviction. Work is proportional to history size, never dictionary size.
function I:Prune()
    local entries, rows = {}, {}
    for prefix, row in pairs(history) do
        if not validCode(prefix) or type(row) ~= "table" or row == history
            or row == dictionary or row == shortcuts then
            rawset(history, prefix, nil)
        else
            -- Damaged saved tables may share a row between codes. Detach it
            -- before learning or eviction can change another code's counts.
            if rows[row] then
                local copy = {}
                for text, count in pairs(row) do copy[text] = count end
                row = copy
                rawset(history, prefix, row)
            end
            rows[row] = true
            for text, count in pairs(row) do
                count = validCount(count)
                if validText(text) and count then
                    rawset(row, text, count)
                    entries[#entries + 1] = { code = prefix, text = text, count = count, row = row }
                else
                    rawset(row, text, nil)
                end
            end
            if next(row) == nil then rawset(history, prefix, nil) end
        end
    end
    if #entries > MAX_HISTORY then
        table.sort(entries, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            if a.code ~= b.code then return a.code < b.code end
            return a.text < b.text
        end)
        for pos = MAX_HISTORY + 1, #entries do
            local entry = entries[pos]
            rawset(entry.row, entry.text, nil)
            if next(entry.row) == nil then rawset(history, entry.code, nil) end
        end
    end
    invalidate()
end
