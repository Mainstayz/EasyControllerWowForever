-- Run from the addon root: lua tools/test_chinese_ime.lua (Lua 5.1).
-- Also works with lupa.lua51; no WoW globals, live dictionary, or DB required.
assert(_VERSION == "Lua 5.1", "these regressions must run on Lua 5.1")

local passed, failed = 0, 0
local function check(name, test)
    local ok, err = pcall(test)
    if ok then
        passed = passed + 1
        print("PASS " .. name)
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

local function equal(actual, expected, message)
    assert(actual == expected, (message or "unexpected value")
        .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function listEqual(actual, expected)
    equal(#actual, #expected, "candidate count")
    for index = 1, #expected do equal(actual[index], expected[index], "candidate " .. index) end
end

local function defaultDictionary()
    -- Complete Ziranma codes, not full pinyin. Tone variants share candidates.
    return {
        ni = "你 尼 呢 泥 拟 逆 妮 倪 匿 腻 霓 昵", hk = "好 号", nihk = "你好",
        vs = "中 钟", go = "国 过", vsgo = "中国", wo = "我", ma = "吗 嘛",
        aa = "啊 阿", ai = "爱", an = "安", ah = "昂", ao = "奥",
        ee = "饿", ei = "诶", en = "恩", eg = "嗯", er = "二", oo = "哦", ou = "欧",
        lv = "绿 驴", nv = "女", lt = "略", nt = "虐", ju = "居", qu = "去", xu = "需",
    }
end

local function fixture(dict, savedHistory, overrides, shortcuts)
    if dict == nil then dict = defaultDictionary() end
    if savedHistory == nil then savedHistory = {} end
    local CK = {
        buffer = "existing message",
        Refresh = function() error("the engine must not refresh UI") end,
    }
    setmetatable(CK, { __index = function(_, key) error("unexpected addon dependency: " .. key) end })
    local chunk = assert(loadfile("ChineseIME.lua"))
    local env = setmetatable(overrides or {}, { __index = _G })
    setfenv(chunk, env)
    chunk("EasyController", CK)
    local ime = CK.ChineseIME
    ime:Load(dict, savedHistory, shortcuts)
    return ime, savedHistory, CK, dict
end

local function feed(ime, text)
    for pos = 1, #text do equal(ime:Feed(text:sub(pos, pos)), true, "letter must be consumed") end
end

local function historySize(history)
    local size = 0
    for _, row in pairs(history) do
        for _ in pairs(row) do size = size + 1 end
    end
    return size
end

check("a first key composes without a premature candidate", function()
    local ime, history = fixture()
    equal(ime:HasComposition(), false)
    equal(ime:Backspace(), false)
    equal(ime:Feed("n"), true)
    equal(ime:GetCode(), "n")
    equal(ime:HasComposition(), true)
    local visible, page, pages = ime:Candidates(5)
    listEqual(visible, {})
    equal(page, 1)
    equal(pages, 1)
    equal(ime:NextPage(), false)
    equal(ime:Commit(1), nil)
    equal(ime:GetCode(), "n")
    equal(next(history), nil)
    equal(ime:Feed("i"), true)
    equal(ime:Candidates(5)[1], "你")
end)

for _, case in ipairs({ { "ni", "你" }, { "nihk", "你好" }, { "vsgo", "中国" } }) do
    check(case[1] .. " commits " .. case[2] .. " without UI side effects", function()
        local ime, history, CK = fixture()
        feed(ime, case[1])
        equal(ime:Candidates(5)[1], case[2])
        equal(ime:Commit(1), case[2])
        equal(ime:GetCode(), "")
        equal(ime:HasComposition(), false)
        equal(history[case[1]][case[2]], 1)
        equal(CK.buffer, "existing message")
    end)
end

for _, case in ipairs({
    { "aa", "啊" }, { "ai", "爱" }, { "an", "安" }, { "ah", "昂" }, { "ao", "奥" },
    { "ee", "饿" }, { "ei", "诶" }, { "en", "恩" }, { "eg", "嗯" }, { "er", "二" },
    { "oo", "哦" }, { "ou", "欧" },
}) do
    check("zero-initial fixture " .. case[1] .. " -> " .. case[2], function()
        local ime = fixture()
        feed(ime, case[1])
        equal(ime:Commit(), case[2])
    end)
end

for _, case in ipairs({
    { "lv", "绿" }, { "nv", "女" }, { "lt", "略" }, { "nt", "虐" },
    { "ju", "居" }, { "qu", "去" }, { "xu", "需" },
}) do
    check("u/umlaut fixture " .. case[1] .. " -> " .. case[2], function()
        local ime = fixture()
        feed(ime, case[1])
        equal(ime:Commit(), case[2])
    end)
end

check("full pinyin is not silently interpreted as double pinyin", function()
    local ime = fixture()
    ime:SetCode("nihao")
    equal(ime:Commit(), "你")
    equal(ime:GetCode(), "hao")
    listEqual(ime:Candidates(), {})
end)

check("unknown sentences consume one known character prefix at a time", function()
    local ime, history = fixture()
    ime:SetCode("niwoma")
    equal(ime:Commit(), "你")
    equal(ime:GetCode(), "woma")
    equal(ime:Commit(), "我")
    equal(ime:GetCode(), "ma")
    equal(ime:Commit(), "吗")
    equal(ime:GetCode(), "")
    equal(history.ni["你"], 1)
    equal(history.wo["我"], 1)
    equal(history.ma["吗"], 1)
    equal(history.niwoma, nil)
end)

check("an unknown sentence still offers its longest known phrase prefix", function()
    local ime = fixture()
    ime:SetCode("nihkvsgo")
    listEqual(ime:Candidates(5), { "你好", "你", "尼", "呢", "泥" })
    equal(ime:Commit(), "你好")
    equal(ime:GetCode(), "vsgo")
    equal(ime:Commit(), "中国")
    equal(ime:GetCode(), "")
end)

check("choosing a shorter candidate preserves the suffix and learns its actual prefix", function()
    local ime, history = fixture()
    ime:SetCode("nihk")
    equal(ime:Commit(2), "你")
    equal(ime:GetCode(), "hk")
    equal(history.ni["你"], 1)
    equal(history.nihk, nil)
    equal(ime:Commit(), "好")
    equal(ime:GetCode(), "")
end)

check("an incomplete trailing syllable survives committing a phrase", function()
    local ime = fixture()
    ime:SetCode("nihkm")
    equal(ime:GetDisplayCode(), "ni hk m")
    equal(ime:Commit(), "你好")
    equal(ime:GetCode(), "m")
    equal(ime:Commit(), nil)
    equal(ime:GetCode(), "m")
    equal(ime:Feed("a"), true)
    equal(ime:Commit(), "吗")
end)

check("an unknown suffix is retained for correction or raw commit", function()
    local ime = fixture()
    ime:SetCode("nizz")
    equal(ime:Commit(), "你")
    equal(ime:GetCode(), "zz")
    listEqual(ime:Candidates(), {})
    equal(ime:Commit(), nil)
    equal(ime:CommitRaw(), "zz")
end)

check("learning cannot move a character ahead of an exact phrase", function()
    local history = { ni = { ["泥"] = 9999 }, nihk = { ["拟好"] = 2 } }
    local ime = fixture({ ni = "你 泥", nihk = "你好 拟好" }, history)
    ime:SetCode("nihk")
    listEqual(ime:Candidates(10), { "拟好", "你好", "泥", "你" })
    equal(ime:Commit(), "拟好")
    equal(history.nihk["拟好"], 3)
    equal(history.ni["泥"], 9999)
end)

check("equal learning counts preserve dictionary order within a length", function()
    local ime = fixture(nil, { ni = { ["你"] = 2, ["泥"] = 5, ["尼"] = 5 } })
    ime:SetCode("ni")
    listEqual(ime:Candidates(5), { "尼", "泥", "你", "呢", "拟" })
    ime:Reset()
    ime:SetCode("ni")
    listEqual(ime:Candidates(5), { "尼", "泥", "你", "呢", "拟" })
end)

check("committing changes later ranking and survives reloading the same history", function()
    local ime, history, _, dict = fixture()
    ime:SetCode("ni")
    equal(ime:Commit(4), "泥")
    equal(history.ni["泥"], 1)
    ime:Load(dict, history)
    ime:SetCode("ni")
    equal(ime:Candidates(5)[1], "泥")
    equal(ime:Commit(), "泥")
    equal(history.ni["泥"], 2)
end)

check("history from another code and unknown words do not inject candidates", function()
    local ime = fixture(nil, { hk = { ["泥"] = 9999 }, ni = { ["不存在"] = 9999 } })
    ime:SetCode("ni")
    listEqual(ime:Candidates(5), { "你", "尼", "呢", "泥", "拟" })
end)

check("duplicates keep a stable order and their longest consuming match", function()
    local ime, history = fixture({ nihk = "你好 你 你好", ni = "你 泥 你 呢 泥" })
    ime:SetCode("nihk")
    listEqual(ime:Candidates(10), { "你好", "你", "泥", "呢" })
    equal(ime:Commit(2), "你")
    equal(ime:GetCode(), "")
    equal(history.nihk["你"], 1)
    equal(history.ni, nil)
end)

check("five-candidate pages wrap forwards and backwards including the partial last page", function()
    local ime = fixture()
    ime:SetCode("ni")
    local visible, page, pages = ime:Candidates(5)
    listEqual(visible, { "你", "尼", "呢", "泥", "拟" })
    equal(page, 1)
    equal(pages, 3)
    equal(ime:NextPage(), true)
    visible, page, pages = ime:Candidates(5)
    listEqual(visible, { "逆", "妮", "倪", "匿", "腻" })
    equal(page, 2)
    equal(pages, 3)
    equal(ime:NextPage(), true)
    visible, page = ime:Candidates()
    listEqual(visible, { "霓", "昵" })
    equal(page, 3)
    equal(ime:NextPage(), true)
    equal(select(2, ime:Candidates()), 1)
    equal(ime:NextPage(-1), true)
    equal(select(2, ime:Candidates()), 3)
    equal(ime:NextPage(3), false)
    equal(ime:NextPage(0), false)
end)

check("page-relative commit matches the display and consumes only its prefix", function()
    local ime, history = fixture()
    ime:SetCode("nihk")
    ime:Candidates(5)
    equal(ime:NextPage(), true)
    listEqual(ime:Candidates(), { "拟", "逆", "妮", "倪", "匿" })
    equal(ime:Commit(5), "匿")
    equal(ime:GetCode(), "hk")
    equal(history.ni["匿"], 1)
    equal(history.nihk, nil)
    local visible, page, pages = ime:Candidates()
    listEqual(visible, { "好", "号" })
    equal(page, 1)
    equal(pages, 1)
end)

check("commit uses the most recent page width rather than an assumed five", function()
    local ime, history = fixture()
    ime:SetCode("ni")
    ime:Candidates(3)
    equal(ime:NextPage(2), true)
    listEqual(ime:Candidates(), { "妮", "倪", "匿" })
    equal(ime:Commit(2), "倪")
    equal(history.ni["倪"], 1)
end)

check("changing page width starts at page one without losing candidates", function()
    local ime = fixture()
    ime:SetCode("ni")
    ime:Candidates(5)
    ime:NextPage()
    local visible, page, pages = ime:Candidates(4)
    listEqual(visible, { "你", "尼", "呢", "泥" })
    equal(page, 1)
    equal(pages, 3)
end)

check("hundreds of candidates remain pageable through the final candidate", function()
    local words = {}
    for index = 1, 303 do words[index] = string.format("候选%03d", index) end
    local ime, history = fixture({ ni = table.concat(words, " ") })
    ime:SetCode("ni")
    local _, page, pages = ime:Candidates(5)
    equal(page, 1)
    equal(pages, 61)
    equal(ime:NextPage(60), true)
    local visible
    visible, page, pages = ime:Candidates()
    listEqual(visible, { "候选301", "候选302", "候选303" })
    equal(page, 61)
    equal(pages, 61)
    equal(ime:Commit(3), "候选303")
    equal(history.ni["候选303"], 1)
    equal(ime:GetCode(), "")
end)

check("invalid commit indices do not consume code, change pages, or learn", function()
    local ime, history = fixture()
    ime:SetCode("ni")
    ime:Candidates(5)
    ime:NextPage(2)
    for _, index in ipairs({ 0, -1, 1.5, 3, 6, "1", false, {}, math.huge, -math.huge, 0 / 0 }) do
        equal(ime:Commit(index), nil)
        equal(ime:GetCode(), "ni")
        equal(select(2, ime:Candidates()), 3)
        equal(next(history), nil)
    end
    equal(ime:Commit(2), "昵")
end)

check("an index beyond the visible width cannot silently pick the next page", function()
    local ime, history = fixture()
    ime:SetCode("ni")
    ime:Candidates(5)
    equal(ime:Commit(6), nil)
    equal(ime:GetCode(), "ni")
    equal(next(history), nil)
end)

check("invalid pagination data has deterministic bounded behavior", function()
    local ime = fixture()
    ime:SetCode("ni")
    for _, width in ipairs({ 0, -1, 0.5, "3", false, {}, math.huge, -math.huge, 0 / 0 }) do
        local visible, page, pages = ime:Candidates(width)
        equal(#visible, 5)
        equal(page, 1)
        equal(pages, 3)
    end
    local visible, _, pages = ime:Candidates(3.9)
    equal(#visible, 3)
    equal(pages, 4)
    for _, delta in ipairs({ "1", false, {}, 1.5, math.huge, -math.huge, 0 / 0 }) do
        equal(ime:NextPage(delta), false)
        equal(select(2, ime:Candidates()), 1)
    end
    equal(ime:NextPage(1e100), false)
end)

check("backspace deletes one letter, invalidates stale pages, and reports empty composition", function()
    local ime, history = fixture()
    ime:SetCode("nihk")
    ime:Candidates(5)
    ime:NextPage()
    equal(ime:Backspace(), true)
    equal(ime:GetCode(), "nih")
    local visible, page = ime:Candidates()
    equal(visible[1], "你")
    equal(page, 1)
    equal(ime:Backspace(), true)
    equal(ime:GetCode(), "ni")
    equal(ime:Backspace(), true)
    equal(ime:GetCode(), "n")
    listEqual(ime:Candidates(), {})
    equal(ime:Backspace(), true)
    equal(ime:HasComposition(), false)
    equal(ime:Backspace(), false)
    equal(next(history), nil)
end)

check("reset cancels composition and pages without learning or clearing past learning", function()
    local ime, history = fixture(nil, { ni = { ["泥"] = 2 } })
    ime:SetCode("nihk")
    ime:Candidates(2)
    ime:NextPage()
    ime:Reset()
    equal(ime:GetCode(), "")
    equal(ime:GetDisplayCode(), "")
    equal(ime:HasComposition(), false)
    local visible, page, pages = ime:Candidates()
    listEqual(visible, {})
    equal(page, 1)
    equal(pages, 1)
    equal(ime:Commit(), nil)
    equal(historySize(history), 1)
    equal(history.ni["泥"], 2)
    ime:SetCode("ni")
    equal(#ime:Candidates(), 5)
    equal(ime:Candidates()[1], "泥")
end)

check("raw commit returns continuous normalized code and cancels without learning", function()
    local ime, history = fixture()
    ime:SetCode("NI-hk")
    ime:Candidates(2)
    ime:NextPage()
    equal(ime:CommitRaw(), "nihk")
    equal(ime:GetCode(), "")
    equal(ime:HasComposition(), false)
    equal(ime:CommitRaw(), "")
    equal(next(history), nil)
    ime:SetCode("ni")
    equal(#ime:Candidates(), 5)
end)

check("feed accepts one ASCII letter and rejects other input without mutation", function()
    local ime = fixture()
    equal(ime:Feed("N"), true)
    equal(ime:Feed("I"), true)
    equal(ime:GetCode(), "ni")
    for _, ch in ipairs({ "", "ni", "1", " ", "-", "你", "ü", "\0", false, 1, {} }) do
        equal(ime:Feed(ch), false)
        equal(ime:GetCode(), "ni")
    end
    equal(ime:Feed(nil), false)
end)

check("restored code keeps only ASCII letters, lowercases, and handles corrupt values", function()
    local ime = fixture()
    ime:SetCode("N-i H K /VÜ 123")
    equal(ime:GetCode(), "nihkv")
    equal(ime:GetDisplayCode(), "ni hk v")
    for _, value in ipairs({ false, 123, {}, function() error("must not call input") end }) do
        ime:SetCode(value)
        equal(ime:GetCode(), "")
    end
    ime:SetCode(nil)
    equal(ime:GetCode(), "")
end)

check("the 32-letter cap eats overflow without changing the code or displayed page", function()
    local ime = fixture()
    local full = "ni" .. string.rep("a", 30)
    ime:SetCode(full .. "EXTRA")
    equal(ime:GetCode(), full)
    ime:Candidates(5)
    ime:NextPage()
    equal(ime:Feed("z"), true)
    equal(ime:GetCode(), full)
    equal(select(2, ime:Candidates()), 2)
    equal(ime:Backspace(), true)
    equal(#ime:GetCode(), 31)
    equal(ime:Feed("Z"), true)
    equal(ime:GetCode(), full:sub(1, 31) .. "z")
    equal(select(2, ime:Candidates()), 1)
end)

check("a full 32-letter dictionary phrase can be selected without truncation", function()
    local fullCode, fullText = string.rep("ni", 16), string.rep("你", 16)
    local ime = fixture({ [fullCode] = fullText, ni = "你" })
    ime:SetCode(fullCode)
    listEqual(ime:Candidates(), { fullText, "你" })
    equal(ime:Commit(), fullText)
    equal(ime:GetCode(), "")
end)

check("a new load resets composition, paging width, history source, and query cache", function()
    local ime, oldHistory = fixture()
    ime:SetCode("ni")
    ime:Candidates(2)
    ime:NextPage()
    local newHistory = {}
    ime:Load({ ni = "泥" }, newHistory)
    equal(ime:GetCode(), "")
    ime:SetCode("ni")
    listEqual(ime:Candidates(), { "泥" })
    equal(ime:Commit(), "泥")
    equal(newHistory.ni["泥"], 1)
    equal(next(oldHistory), nil)
end)

check("missing or non-table dictionaries and histories are safe", function()
    local ime = fixture()
    ime:Load(nil, nil)
    ime:SetCode("ni")
    listEqual(ime:Candidates(), {})
    equal(ime:Commit(), nil)
    for _, value in ipairs({ false, 123, "broken", function() error("must not execute data") end }) do
        ime:Load(value, value)
        ime:SetCode("ni")
        listEqual(ime:Candidates(), {})
        equal(ime:CommitRaw(), "ni")
        ime:Load({ ni = "你" }, value)
        ime:SetCode("ni")
        equal(ime:Commit(), "你")
    end
end)

check("damaged dictionary values are ignored while valid shorter prefixes still work", function()
    local ime = fixture({ ni = "你", nihk = false, hk = {}, vsgo = 42, vs = "中",
        go = function() error("must not execute dictionary data") end })
    ime:SetCode("nihk")
    equal(ime:Commit(), "你")
    equal(ime:GetCode(), "hk")
    listEqual(ime:Candidates(), {})
    ime:SetCode("vsgo")
    equal(ime:Commit(), "中")
    equal(ime:GetCode(), "go")
    listEqual(ime:Candidates(), {})
end)

check("malformed UTF-8 and control tokens are skipped without damaging valid Unicode", function()
    local valid = { "你", "阿\194\160乙", "\240\159\152\128", "\224\160\128",
        "\237\159\191", "\238\128\128", "\240\144\128\128", "\244\143\191\191", string.rep("a", 128) }
    local bad = { "\255", "\128", "\192\175", "\226\130", "\237\160\128",
        "\244\144\128\128", "\245\128\128\128", "\224\128\128", "\240\128\128\128",
        "\226a\172", "\0", "\1", "\127", string.rep("长", 43) }
    local ime = fixture({ ni = table.concat(valid, " \t") .. "\r\n" .. table.concat(bad, " ") })
    ime:SetCode("ni")
    listEqual(ime:Candidates(100), valid)
end)

check("load sanitizes corrupt history keys, counts, text, and cycles in place", function()
    local badKey = {}
    local history = {
        [""] = { ["你"] = 1 }, n = { ["你"] = 1 }, NI = { ["你"] = 1 },
        ["ni-"] = { ["你"] = 1 }, [string.rep("a", 34)] = { ["你"] = 1 },
        [1] = { ["你"] = 1 }, [badKey] = { ["你"] = 1 }, hk = "broken", wo = {}, ma = { ["吗"] = 0.5 },
        ni = { ["你"] = 3.9, ["尼"] = 0 / 0, ["泥"] = math.huge, ["呢"] = -3,
            ["拟"] = "8", ["逆"] = 0, ["妮"] = 1e100, ["倪"] = false, [false] = 3,
            [""] = 4, ["bad word"] = 2, ["\255"] = 3, [string.rep("长", 50)] = 1, ["a\0b"] = 2 },
        vs = { ["中"] = 2 },
    }
    history.go = history
    history.vs.cycle = history.vs
    local ime = fixture(nil, history)
    equal(historySize(history), 3)
    equal(history.ni["你"], 3)
    equal(history.ni["妮"], 9999)
    equal(history.vs["中"], 2)
    equal(history.go, nil)
    equal(history.vs.cycle, nil)
    equal(history[badKey], nil)
    ime:SetCode("ni")
    equal(ime:Candidates()[1], "妮")
end)

check("learning counts saturate and remain bounded on subsequent commits", function()
    local history = { ni = { ["你"] = 9998 } }
    local ime = fixture(nil, history)
    for _ = 1, 4 do
        ime:SetCode("ni")
        equal(ime:Commit(), "你")
        equal(history.ni["你"], 9999)
    end
end)

check("history capacity counts pairs even if they all share one code", function()
    local history = { ni = {} }
    for index = 1, 1050 do history.ni[string.format("词%04d", index)] = index end
    local ime = fixture(nil, history)
    equal(historySize(history), 1024)
    equal(history.ni["词0026"], nil)
    equal(history.ni["词0027"], 27)
    equal(history.ni["词1050"], 1050)
    ime:Prune()
    equal(historySize(history), 1024)
end)

check("learning at capacity prunes the excess deterministically", function()
    local history = { ni = {} }
    for index = 1, 1024 do history.ni[string.format("词%04d", index)] = 1 end
    local ime = fixture(nil, history)
    ime:SetCode("ni")
    equal(ime:Commit(), "你")
    equal(historySize(history), 1024)
    equal(history.ni["你"], 1)
    equal(history.ni["词1024"], nil)
    equal(history.ni["词1023"], 1)
end)

check("capacity applies across codes and removes empty evicted rows", function()
    local history = { aa = { ["啊"] = 1 }, ni = {} }
    for index = 1, 1024 do history.ni[string.format("词%04d", index)] = 2 end
    fixture(nil, history)
    equal(historySize(history), 1024)
    equal(history.aa, nil)
end)

check("explicit pruning handles later corruption and rebuilds ranking", function()
    local ime, history = fixture()
    ime:SetCode("ni")
    ime:Candidates(5)
    ime:NextPage()
    history.ni = { ["泥"] = 10, ["你"] = "broken" }
    history.hk = false
    ime:Prune()
    local visible, page = ime:Candidates()
    equal(visible[1], "泥")
    equal(page, 1)
    equal(history.hk, nil)
    equal(history.ni["你"], nil)
end)

check("bad counts written after load cannot break candidate sorting or learning", function()
    local ime, history = fixture()
    history.ni = { ["泥"] = {}, ["尼"] = math.huge, ["你"] = "bad" }
    ime:SetCode("ni")
    equal(ime:Candidates()[1], "你")
    equal(ime:Commit(), "你")
    equal(history.ni["你"], 1)
    equal(historySize(history), 1)
end)

check("dictionary data is read without mutation or metatable lookups", function()
    local dict = setmetatable({ ni = "你 尼", nihk = "你好", hk = "好" }, {
        __index = function() error("dictionary misses must use direct lookup") end,
        __newindex = function() error("dictionary must stay read-only") end,
    })
    local ime = fixture(dict)
    ime:SetCode("niwoma")
    equal(ime:Commit(), "你")
    equal(dict.ni, "你 尼")
    equal(rawget(dict, "niwoma"), nil)
end)

check("queries never enumerate the dictionary and cache only the current composition", function()
    local dict, lookups = defaultDictionary(), 0
    local ime = fixture(dict, {}, {
        pairs = function(value)
            assert(value ~= dict, "dictionary enumeration is forbidden")
            return pairs(value)
        end,
        next = function(value, key)
            assert(value ~= dict, "dictionary enumeration is forbidden")
            return next(value, key)
        end,
        rawget = function(value, key)
            if value == dict then lookups = lookups + 1 end
            return rawget(value, key)
        end,
    })
    equal(lookups, 0, "load must not scan or index dictionary")
    ime:SetCode("ni" .. string.rep("a", 30))
    equal(lookups, 0, "restoring code must not query dictionary eagerly")
    ime:Candidates(5)
    equal(lookups, 16)
    ime:NextPage()
    for _ = 1, 20 do ime:Candidates(5) end
    equal(ime:Commit(6), nil)
    equal(lookups, 16, "cached reads and invalid commits must not repeat lookups")
    equal(ime:Commit(3), "倪")
    equal(ime:GetCode(), string.rep("a", 30))
    equal(lookups, 16, "learning must not scan the dictionary")
    ime:Candidates(5)
    equal(lookups, 31, "the new composition has exactly 15 complete prefixes")
    ime:Reset()
    ime:Feed("n")
    ime:Candidates()
    equal(lookups, 31, "an incomplete first syllable needs no dictionary lookup")
end)

check("returned arrays cannot alter the cached choice being committed", function()
    local ime = fixture()
    ime:SetCode("nihk")
    local visible = ime:Candidates(5)
    visible[1], visible[2] = "tampered", nil
    equal(ime:Candidates(5)[1], "你好")
    equal(ime:Commit(), "你好")
end)

check("reset and set-code discard parsed candidates as well as displayed pages", function()
    local dict = { ni = "你", hk = "好" }
    local ime = fixture(dict)
    ime:SetCode("ni")
    equal(ime:Candidates()[1], "你")
    dict.ni = "泥"
    ime:Reset()
    ime:SetCode("ni")
    equal(ime:Candidates()[1], "泥")
    ime:SetCode("hk")
    equal(ime:Candidates()[1], "好")
end)

check("shared corrupt history rows cannot couple learning between codes", function()
    local shared = { ["你"] = 2 }
    local history = { ni = shared, hk = shared }
    local ime = fixture(nil, history)
    assert(history.ni ~= history.hk, "each code must own its counts")
    ime:SetCode("ni")
    equal(ime:Commit(), "你")
    equal(history.ni["你"], 3)
    equal(history.hk["你"], 2)
end)

check("shared history rows retain exactly the capacity during pruning", function()
    local shared = {}
    for index = 1, 600 do shared[string.format("词%04d", index)] = 1 end
    local history = { aa = shared, ni = shared }
    fixture(nil, history)
    equal(historySize(history), 1024)
end)

check("a corrupt history reference to dictionary data cannot mutate the dictionary", function()
    local dict = { ni = "你", hk = "好" }
    local history = { ni = dict }
    local ime = fixture(dict, history)
    equal(dict.ni, "你")
    equal(dict.hk, "好")
    equal(next(history), nil)
    ime:SetCode("ni")
    equal(ime:Commit(), "你")
    equal(dict.ni, "你")
    equal(history.ni["你"], 1)
    ime:Load(dict, dict)
    ime:SetCode("ni")
    equal(ime:Commit(), "你")
    equal(dict.ni, "你")
    equal(dict.hk, "好")
end)

check("exact shortcuts lead but keep the matching double-pinyin character selectable", function()
    local ime, history = fixture({ ss = "松 送" }, nil, nil, { ss = "术士" })
    feed(ime, "SS")
    listEqual(ime:Candidates(), { "术士", "松", "送" })
    equal(ime:Commit(2), "松")
    equal(ime:GetCode(), "")
    equal(history.ss["松"], 1)
    ime:SetCode("ss")
    listEqual(ime:Candidates(), { "松", "术士", "送" })
end)

check("odd-length shortcuts consume their whole code and keep learned order after reload", function()
    local shortcuts = { klz = "卡拉赞 卡拉赞队伍", mld = "玛拉顿" }
    local dict = { kl = "开" }
    local ime, history = fixture(dict, { abc = { ["旧词"] = 1 } }, nil, shortcuts)
    feed(ime, "KLZ")
    equal(ime:GetDisplayCode(), "klz")
    listEqual(ime:Candidates(), { "卡拉赞", "卡拉赞队伍", "开" })
    equal(ime:Commit(2), "卡拉赞队伍")
    equal(ime:GetCode(), "")
    equal(history.klz["卡拉赞队伍"], 1)
    equal(history.abc["旧词"], 1, "absent shortcut history must remain available")
    ime:SetCode("abc")
    listEqual(ime:Candidates(), {})
    ime:Load(dict, history, shortcuts)
    ime:SetCode("klz")
    equal(ime:Candidates()[1], "卡拉赞队伍")
    equal(ime:Commit(), "卡拉赞队伍")
    equal(history.klz["卡拉赞队伍"], 2)
    ime:SetCode("mld")
    equal(ime:Commit(), "玛拉顿")
    equal(ime:GetCode(), "")
end)

check("shortcut prefixes never displace longer double-pinyin words or sentences", function()
    local ime = fixture({ ss = "松", ssui = "松树", lin = "not a full code" }, nil, nil,
        { ss = "术士", ssu = "缩写" })
    ime:SetCode("ssui")
    listEqual(ime:Candidates(), { "松树", "松" })
    equal(ime:GetDisplayCode(), "ss ui")
    ime:SetCode("ssuii")
    listEqual(ime:Candidates(), { "松树", "松" })
    equal(ime:Commit(), "松树")
    equal(ime:GetCode(), "i")
end)

check("shortcut and full-code duplicates keep one candidate with the longest match", function()
    local ime, history = fixture({ kl = "开", klz = "not a full code" }, nil, nil,
        { klz = "卡拉赞 卡拉赞 开" })
    ime:SetCode("klz")
    listEqual(ime:Candidates(), { "卡拉赞", "开" })
    equal(ime:Commit(2), "开")
    equal(ime:GetCode(), "")
    equal(history.klz["开"], 1)
    equal(history.kl, nil)
end)

check("shortcut pagination uses the visible index and resets after backspace", function()
    local ime, history = fixture({ ab = "甲" }, nil, nil,
        { abc = "一 二 三 四 五 六 七" })
    ime:SetCode("abc")
    ime:Candidates(5)
    ime:NextPage()
    listEqual(ime:Candidates(), { "六", "七", "甲" })
    equal(ime:Commit(2), "七")
    equal(ime:GetCode(), "")
    equal(history.abc["七"], 1)
    ime:SetCode("abc")
    ime:Candidates(2)
    ime:NextPage()
    ime:Backspace()
    listEqual(ime:Candidates(), { "甲" })
    equal(select(2, ime:Candidates()), 1)
    equal(ime:Commit(), "甲")
end)

check("shortcut lookup is exact and never scans or mutates either dictionary", function()
    local shortcuts, lookups = { klz = "卡拉赞" }, 0
    setmetatable(shortcuts, {
        __index = function() error("shortcut misses must use direct lookup") end,
        __newindex = function() error("shortcuts must stay read-only") end,
    })
    local ime = fixture({}, {}, {
        pairs = function(value)
            assert(value ~= shortcuts, "shortcut enumeration is forbidden")
            return pairs(value)
        end,
        next = function(value, key)
            assert(value ~= shortcuts, "shortcut enumeration is forbidden")
            return next(value, key)
        end,
        rawget = function(value, key)
            if value == shortcuts then lookups = lookups + 1 end
            return rawget(value, key)
        end,
    }, shortcuts)
    equal(lookups, 0)
    ime:SetCode("klz")
    equal(ime:Candidates()[1], "卡拉赞")
    equal(lookups, 1)
    ime:Candidates()
    ime:NextPage()
    equal(lookups, 1)
    ime:SetCode("klza")
    listEqual(ime:Candidates(), {})
    equal(lookups, 2)
    equal(shortcuts.klz, "卡拉赞")
end)

check("a new load clears shortcuts and ignores corrupt shortcut values and references", function()
    local shortcuts = { klz = "卡拉赞", mld = false, zz = {} }
    local history = { klz = shortcuts }
    local ime = fixture({}, history, nil, shortcuts)
    equal(next(history), nil)
    ime:SetCode("klz")
    equal(ime:Commit(), "卡拉赞")
    equal(shortcuts.klz, "卡拉赞")
    ime:SetCode("mld")
    listEqual(ime:Candidates(), {})
    ime:Load({}, shortcuts, shortcuts)
    ime:SetCode("klz")
    equal(ime:Commit(), "卡拉赞")
    equal(shortcuts.klz, "卡拉赞")
    ime:Load({}, history)
    equal(history.klz["卡拉赞"], 1)
    ime:SetCode("klz")
    listEqual(ime:Candidates(), {})
    ime:Load({}, history, shortcuts)
    ime:SetCode("klz")
    equal(ime:Commit(), "卡拉赞")
    equal(history.klz["卡拉赞"], 2)
    for _, value in ipairs({ false, 12, "broken" }) do
        ime:Load({}, {}, value)
        ime:SetCode("klz")
        listEqual(ime:Candidates(), {})
    end
end)

assert(failed == 0, failed .. " Chinese IME regression tests failed (" .. passed .. " passed)")
print(passed .. " Chinese IME regression tests passed on " .. _VERSION)
