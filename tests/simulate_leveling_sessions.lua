local addonPath = arg[1] or "Hoppdebaese.lua"

local sourceFile = assert(io.open(addonPath, "r"))
local addonSource = sourceFile:read("*a")
sourceFile:close()

local challengeInfo = {}
local dailyGoals = {}
local freshAirMinimum, freshAirMaximum = addonSource:match(
    'id = "freshAir".-values = { min = (%d+), max = (%d+) }.-fixedScale = true'
)
assert(tonumber(freshAirMinimum) == 30 and tonumber(freshAirMaximum) == 120, "Stoßlüften must remain 30-120 seconds")
assert(addonSource:find('text = "Do the dishes if not done, else free"', 1, true), "Dishes challenge is missing")
assert(addonSource:find('id = "deadHang"', 1, true), "Dead hang challenge is missing")
assert(addonSource:find('cooldown = 14400', 1, true), "Shower cooldown is missing")
assert(addonSource:find('id = "lunges", code = "lu"', 1, true), "Forward lunges challenge is missing")
assert(addonSource:find('id = "calfRaises"', 1, true) and addonSource:find('amountMultiplier = 1.35', 1, true), "Calf-raise values were not increased")
assert(addonSource:find('id = "catPlay"', 1, true) and addonSource:find('id = "catPets"', 1, true), "Cat challenges are missing")
assert(addonSource:find('id = "catLitter"', 1, true) and addonSource:find('text = "Clean up the cat litter box"', 1, true), "Cat litter challenge is missing")
assert(addonSource:find('id = "postureCheck"', 1, true) and addonSource:find('name = "Posture check"', 1, true), "Easy posture challenge is missing")
assert(addonSource:find('id = "qualityTime"', 1, true) and addonSource:find('text = "Spend quality time with your significant other"', 1, true), "Significant-other challenge is missing or timed")
assert(addonSource:find('values = { min = 5, max = 20 }, fixedScale = true, higherIsBetter = true', 1, true), "Cat play must use a 5-20 minute higher-is-better range")
local catChallengeBlock = assert(addonSource:match("local CAT_CHALLENGES = {(.-)\n}"), "Cat challenge pool is missing")
local catWeightCount = 0
for _ in catChallengeBlock:gmatch("weight = 1%.2") do catWeightCount = catWeightCount + 1 end
assert(catWeightCount == 3, "All cat challenges must use 1.2 selection weight")
local completionQuoteBlock = assert(addonSource:match("local COMPLETION_QUOTES = {(.-)\n}"), "Completion quotes are missing")
local completionQuoteCount = 0
for _ in completionQuoteBlock:gmatch('\n%s*"') do completionQuoteCount = completionQuoteCount + 1 end
assert(completionQuoteCount == 68, "Completion quote pool must contain 68 messages")
for _, name in ipairs({ "Obama", "Gandhi", "Richi", "Sam Altman" }) do
    assert(completionQuoteBlock:find(name, 1, true), name .. " completion quote is missing")
end
for _, phrase in ipairs({ "Früener hämmer", "OMEGALUL", "6 7 Reps", "Gopferdammi" }) do
    assert(completionQuoteBlock:find(phrase, 1, true), phrase .. " quote style is missing")
end
for line in addonSource:gmatch("[^\n]+") do
    local id, name, unit = line:match('id = "([^"]+)".-name = "([^"]+)".-unit = "([^"]+)"')
    if id then challengeInfo[id] = { name = name, unit = unit } end

    local goalID, easy, medium, hard, extreme = line:match(
        '^%s*(%w+) = { easy = (%d+), medium = (%d+), hard = (%d+), extreme = (%d+) }'
    )
    if goalID then
        dailyGoals[goalID] = {
            easy = tonumber(easy),
            medium = tonumber(medium),
            hard = tonumber(hard),
            extreme = tonumber(extreme),
        }
    end
end

local simulatedLevel = 1
local simulatedDate = "2026-11-04"
local clock = 0
local savedDB
local taxiHook
local guildMessages = {}
local professionSkills = {
    [1] = { name = "Alchemy", rank = 9 },
    [2] = { name = "Fishing", rank = 19 },
    [3] = { name = "Cooking", rank = 29 },
    [4] = { name = "First Aid", rank = 39 },
}
local shiftDown = false

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function createMock(kind, name, createdFrames, namedFrames)
    local object = {
        kind = kind,
        name = name,
        scripts = {},
        shown = false,
        width = 500,
        height = 400,
        point = { "CENTER", nil, "CENTER", 0, 0 },
    }

    local methods = {}
    function methods:SetScript(scriptName, callback) self.scripts[scriptName] = callback end
    function methods:HookScript(scriptName, callback)
        local previous = self.scripts[scriptName]
        self.scripts[scriptName] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    function methods:CreateFontString() return createMock("FontString", nil, createdFrames, namedFrames) end
    function methods:CreateTexture() return createMock("Texture", nil, createdFrames, namedFrames) end
    function methods:SetText(text) self.text = text end
    function methods:GetText() return self.text end
    function methods:SetVertexColor(red, green, blue, alpha)
        self.vertexColor = { red, green, blue, alpha }
    end
    function methods:SetBackdropColor(red, green, blue, alpha)
        self.backdropColor = { red, green, blue, alpha }
    end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:SetWidth(width) self.width = width end
    function methods:SetHeight(height) self.height = height end
    function methods:GetWidth() return self.width end
    function methods:GetHeight() return self.height end
    function methods:SetPoint(point, _, relativePoint, x, y)
        self.point = { point or "CENTER", nil, relativePoint or point or "CENTER", x or 0, y or 0 }
    end
    function methods:GetPoint() return unpack(self.point) end
    function methods:Show()
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function methods:Hide() self.shown = false end
    function methods:IsShown() return self.shown end
    function methods:Enable() self.enabled = true end
    function methods:Disable() self.enabled = false end
    function methods:SetChecked(value) self.checked = value end
    function methods:GetChecked() return self.checked end
    function methods:SetValue(value)
        self.value = value
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
    end
    function methods:GetValue() return self.value end
    function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function methods:RegisterForClicks(...) self.registeredClicks = { ... } end
    function methods:GetStringHeight()
        local _, lines = (self.text or ""):gsub("\n", "\n")
        return (lines + 1) * 14
    end
    function methods:RegisterEvent() end

    setmetatable(object, {
        __index = function(_, key)
            if methods[key] then return methods[key] end
            if key:match("^[A-Z]") then return function() end end
            return nil
        end,
    })

    if kind ~= "FontString" and kind ~= "Texture" then table.insert(createdFrames, object) end
    if name then namedFrames[name] = object end
    return object
end

local function installWoWMocks(createdFrames, namedFrames)
    _G.unpack = _G.unpack or table.unpack
    _G.UIParent = createMock("UIParent", nil, {}, {})
    _G.Minimap = createMock("Minimap", nil, {}, {})
    _G.BackdropTemplateMixin = nil
    _G.SlashCmdList = {}
    _G.C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return true end,
        SendAddonMessage = function() end,
    }
    _G.CreateFrame = function(kind, name)
        return createMock(kind, name, createdFrames, namedFrames)
    end
    _G.UnitLevel = function() return simulatedLevel end
    _G.UnitName = function() return "Testhero" end
    _G.UnitFullName = function() return "Testhero", "Chrieger" end
    _G.GetGuildInfo = function() return nil end
    _G.IsInGuild = function() return false end
    _G.SendChatMessage = function(message, channel)
        table.insert(guildMessages, { message = message, channel = channel })
    end
    _G.GetTime = function() clock = clock + 1; return clock end
    _G.time = os.time
    _G.date = function() return simulatedDate end
    _G.Ambiguate = function(name) return name:match("^[^-]+") or name end
    _G.hooksecurefunc = function(_, callback) taxiHook = callback end
    _G.TakeTaxiNode = function() end
    _G.IsShiftKeyDown = function() return shiftDown end
    _G.GetProfessions = function() return 1, nil, nil, 2, 3, 4 end
    _G.GetProfessionInfo = function(index)
        local profession = professionSkills[index]
        return profession.name, nil, profession.rank, 300
    end
end

local function findButton(createdFrames, text)
    for _, frame in ipairs(createdFrames) do
        if frame.text == text and frame.scripts.OnClick then return frame end
    end
    error("Button not found: " .. text)
end

local function startSession(dateKey, seed, difficulty)
    simulatedDate = dateKey
    math.randomseed(seed)
    local createdFrames, namedFrames = {}, {}
    installWoWMocks(createdFrames, namedFrames)
    _G.HoppdebaeseDB = savedDB

    local chunk = assert(loadfile(addonPath))
    chunk("Hoppdebaese")
    local addon = createdFrames[1]
    assert(addon and addon.scripts.OnEvent, "Addon event frame was not created")
    addon.scripts.OnEvent(addon, "ADDON_LOADED", "Hoppdebaese")
    HoppdebaeseDB.difficulty = difficulty
    addon.scripts.OnEvent(addon, "PLAYER_LOGIN")

    return {
        addon = addon,
        frames = createdFrames,
        named = namedFrames,
        swap = findButton(createdFrames, "Replace Exercise (Session)"),
        help = findButton(createdFrames, "?"),
        minimize = findButton(createdFrames, "Minimize"),
        records = {},
    }
end

local function runPrompt(session, eventName, label, level, shouldSwap)
    if level then simulatedLevel = level end
    if eventName == "FLIGHT" then
        assert(taxiHook, "Taxi hook was not installed")
        taxiHook()
    else
        session.addon.scripts.OnEvent(session.addon, eventName, level)
    end

    local mainFrame = assert(session.named.HoppdebaeseBoxFrame, "Main box window was not created")
    assert(mainFrame.scripts.OnUpdate, "Box update handler is missing")
    for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end

    local first = assert(session.addon.currentChallenge, "Box did not select a challenge")
    assert(first == session.addon.boxItems[3], "Selected challenge is not the visible center row")
    assert(session.named.HoppdebaeseTodo:IsShown(), "Todo did not open after the challenge settled")
    local swappedFrom
    if shouldSwap and dailyGoals[first.id] then
        swappedFrom = first.text
        assert(#HoppdebaeseDB.todo == 1, "Settled challenge was not queued")
        session.swap.scripts.OnClick(session.swap)
        assert(session.addon.sessionDisabled[first.id], "Session replacement did not disable " .. first.id)
        assert(session.named.HoppdebaeseRested, "Rested Exercises window was not created")
        session.named.HoppdebaeseRested:Show()
        local restore = findButton(session.frames, "Restore")
        assert(restore.exerciseID == first.id, "Rested Exercises listed the wrong exercise")
        for _ = 1, 90 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
        assert(#HoppdebaeseDB.todo == 1, "Session replacement did not replace its Todo entry")
        restore.scripts.OnClick(restore)
        assert(not session.addon.sessionDisabled[first.id], "Restore did not re-enable " .. first.id)
    end

    local selected = assert(session.addon.currentChallenge, "No challenge selected after swap")
    assert(not session.addon.sessionDisabled[selected.id], "Selected a session-rested exercise: " .. selected.id)
    assert(#HoppdebaeseDB.todo == 1, "Selected challenge is missing from Todo")
    local complete = findButton(session.frames, "Complete")
    complete.scripts.OnClick(complete)
    assert(#HoppdebaeseDB.todo == 0, "Completed Todo entry was not removed")
    table.insert(session.records, {
        eventName = eventName,
        event = label,
        level = simulatedLevel,
        text = selected.text,
        id = selected.id,
        amount = selected.amount,
        swappedFrom = swappedFrom,
    })
end

local sessions = {
    {
        title = "Session 1: level 1 to 9",
        date = "2026-11-04",
        seed = 101,
        events = {
            { "PLAYER_LEVEL_UP", "Level 2", 2, true },
            { "PLAYER_LEVEL_UP", "Level 3", 3 },
            { "FLIGHT", "Flight path", nil },
            { "PLAYER_LEVEL_UP", "Level 4", 4 },
            { "PLAYER_LEVEL_UP", "Level 5", 5 },
            { "PLAYER_DEAD", "Death", nil },
            { "PLAYER_LEVEL_UP", "Level 6", 6 },
            { "PLAYER_LEVEL_UP", "Level 7", 7 },
            { "FLIGHT", "Flight path", nil },
            { "PLAYER_LEVEL_UP", "Level 8", 8 },
            { "DUNGEON_COMPLETED", "Dungeon complete", nil },
            { "PLAYER_LEVEL_UP", "Level 9", 9 },
        },
    },
    {
        title = "Session 2: level 9 to 15",
        date = "2026-11-05",
        seed = 202,
        events = {
            { "PLAYER_LEVEL_UP", "Level 10", 10 },
            { "FLIGHT", "Flight path", nil },
            { "PLAYER_LEVEL_UP", "Level 11", 11 },
            { "PLAYER_LEVEL_UP", "Level 12", 12 },
            { "PLAYER_DEAD", "Death", nil, true },
            { "PLAYER_LEVEL_UP", "Level 13", 13 },
            { "DUNGEON_COMPLETED", "Dungeon complete", nil },
            { "PLAYER_LEVEL_UP", "Level 14", 14 },
            { "FLIGHT", "Flight path", nil },
            { "PLAYER_LEVEL_UP", "Level 15", 15 },
        },
    },
    {
        title = "Session 3: level 15 to 20",
        date = "2026-11-06",
        seed = 303,
        events = {
            { "PLAYER_LEVEL_UP", "Level 16", 16 },
            { "PLAYER_LEVEL_UP", "Level 17", 17 },
            { "FLIGHT", "Flight path", nil },
            { "PLAYER_LEVEL_UP", "Level 18", 18 },
            { "PLAYER_DEAD", "Death", nil },
            { "PLAYER_LEVEL_UP", "Level 19", 19 },
            { "FLIGHT", "Flight path", nil, true },
            { "PLAYER_LEVEL_UP", "Level 20", 20 },
            { "DUNGEON_COMPLETED", "Dungeon complete", nil },
        },
    },
}

local function runDifficulty(difficulty)
    savedDB = nil
    simulatedLevel = 1
    taxiHook = nil
    local expectedPrompts = 0
    local stapleChallenges = 0
    local levelUpPrompts = 0
    local levelUpWorkouts = 0
    local extraEventPrompts = 0
    local exerciseCounts = {}

    print("\n============================================================")
    print(string.upper(difficulty) .. " DIFFICULTY")
    print("============================================================")

    for _, definition in ipairs(sessions) do
        local session = startSession(definition.date, definition.seed, difficulty)
        for _, event in ipairs(definition.events) do
            runPrompt(session, event[1], event[2], event[3], event[4])
        end
        expectedPrompts = expectedPrompts + #definition.events
        savedDB = HoppdebaeseDB

        print("\n" .. definition.title .. " (" .. definition.date .. ")")
        local sessionLevelUps = 0
        local sessionExtras = 0
        local sessionTotals = {}
        local sessionCounts = {}
        for index, record in ipairs(session.records) do
            local swapNote = record.swappedFrom and (" [rested " .. record.swappedFrom .. "]") or ""
            print(string.format("%2d. %-18s -> %s%s", index, record.event, record.text, swapNote))
            if record.id == "squats" or record.id == "situps" or record.id == "pushups" then
                stapleChallenges = stapleChallenges + 1
            end
            if record.eventName == "PLAYER_LEVEL_UP" then
                levelUpPrompts = levelUpPrompts + 1
                sessionLevelUps = sessionLevelUps + 1
                if dailyGoals[record.id] then levelUpWorkouts = levelUpWorkouts + 1 end
            else
                extraEventPrompts = extraEventPrompts + 1
                sessionExtras = sessionExtras + 1
            end
            if dailyGoals[record.id] then
                exerciseCounts[record.id] = (exerciseCounts[record.id] or 0) + 1
            end
            sessionTotals[record.id] = (sessionTotals[record.id] or 0) + record.amount
            sessionCounts[record.id] = (sessionCounts[record.id] or 0) + 1
        end
        print(string.format(
            "Session prompts: %d from level increments, %d from flights/death/dungeon",
            sessionLevelUps,
            sessionExtras
        ))

        print("Session exercise totals:")
        local sessionIDs = {}
        for id in pairs(sessionTotals) do table.insert(sessionIDs, id) end
        table.sort(sessionIDs)
        for _, id in ipairs(sessionIDs) do
            local info = challengeInfo[id]
            local amount = sessionTotals[id]
            local goalText = "no daily cap"
            if dailyGoals[id] then
                local goal = dailyGoals[id][difficulty]
                local dailyAmount = savedDB.daily.stats[id] or 0
                assert(dailyAmount <= goal, string.format(
                    "%s daily goal exceeded for %s: %d > %d",
                    difficulty,
                    id,
                    dailyAmount,
                    goal
                ))
                goalText = string.format("daily goal %d %s", goal, info.unit)
            end
            print(string.format(
                "    %-20s %4d %-8s across %d challenge(s)  [%s]",
                info.name,
                amount,
                info.unit,
                sessionCounts[id],
                goalText
            ))
        end
    end

    assert(savedDB.completedChallenges == expectedPrompts, string.format(
        "%s: expected %d completed prompts, got %d",
        difficulty,
        expectedPrompts,
        savedDB.completedChallenges
    ))

    print("\nAll-time overview after level 20:")
    local completedIDs = {}
    for id, count in pairs(savedDB.completionCounts) do
        if count > 0 then table.insert(completedIDs, id) end
    end
    table.sort(completedIDs)
    for _, id in ipairs(completedIDs) do
        local info = challengeInfo[id]
        print(string.format(
            "    %-20s %4d %-8s across %d challenge(s)",
            info.name,
            savedDB.stats[id],
            info.unit,
            savedDB.completionCounts[id]
        ))
    end
    print(string.format("Staple challenges: %d of %d", stapleChallenges, expectedPrompts))
    print(string.format(
        "Level increments: %d prompts (%d physical workouts, %d wellness prompts)",
        levelUpPrompts,
        levelUpWorkouts,
        levelUpPrompts - levelUpWorkouts
    ))
    print(string.format("Extra event prompts: %d", extraEventPrompts))
    print("Physical workout mix:")
    local exerciseIDs = {}
    for id in pairs(exerciseCounts) do table.insert(exerciseIDs, id) end
    table.sort(exerciseIDs)
    for _, id in ipairs(exerciseIDs) do
        print(string.format("    %-20s %d challenge(s)", challengeInfo[id].name, exerciseCounts[id]))
    end
    print(string.format("Total completed challenges: %d", savedDB.completedChallenges))
end

for _, difficulty in ipairs({ "easy", "medium", "hard", "extreme" }) do runDifficulty(difficulty) end

-- Pull-ups use dedicated ranges and ignore event multipliers so Easy remains one.
savedDB = nil
simulatedLevel = 60
local pullupSession = startSession("2026-11-07", 403, "medium")
HoppdebaeseDB.tools.pullupBar = true
HoppdebaeseDB.triggers.cats = false
for id in pairs(dailyGoals) do
    if id ~= "pullups" then pullupSession.addon.sessionDisabled[id] = true end
end
local pullupMain = pullupSession.named.HoppdebaeseBoxFrame
local function assertPullupRange(difficulty, level, minimum, maximum, trigger)
    HoppdebaeseDB.difficulty = difficulty
    local checked = 0
    while checked < 25 do
        pullupSession.addon:ShowChallenge(trigger or "manual", level)
        for _ = 1, 100 do pullupMain.scripts.OnUpdate(pullupMain, 0.05) end
        local challenge = assert(pullupSession.addon.currentChallenge)
        if challenge.id ~= "elephant" then
            assert(challenge.id == "pullups", "Pull-up range test selected " .. challenge.id)
            assert(challenge.amount >= minimum and challenge.amount <= maximum, string.format(
                "%s level %d pull-ups outside %d-%d: %d",
                difficulty, level, minimum, maximum, challenge.amount
            ))
            checked = checked + 1
        end
        HoppdebaeseDB.todo = {}
    end
end
assertPullupRange("easy", 10, 1, 1)
assertPullupRange("easy", 60, 1, 1, "death")
assertPullupRange("medium", 20, 1, 2)
assertPullupRange("medium", 40, 2, 3)
assertPullupRange("medium", 60, 2, 4)
assertPullupRange("hard", 20, 2, 3)
assertPullupRange("hard", 40, 3, 4)
assertPullupRange("hard", 60, 4, 5)
assertPullupRange("extreme", 20, 4, 6)
assertPullupRange("extreme", 40, 6, 8)
assertPullupRange("extreme", 60, 8, 10)
HoppdebaeseDB.triggers.cats = true

-- Fuultier tokens are earned only after completing physical exercises in the top ten percent.
savedDB = nil
simulatedLevel = 20
local tokenSession = startSession("2026-11-07", 406, "medium")
local tokenMain = tokenSession.named.HoppdebaeseBoxFrame
HoppdebaeseDB.triggers.cats = false
for id in pairs(dailyGoals) do
    if id ~= "squats" then tokenSession.addon.sessionDisabled[id] = true end
end
local sawQualifyingExercise, sawNonQualifyingExercise = false, false
for _ = 1, 300 do
    local tokensBefore = HoppdebaeseDB.fuultierTokens
    tokenSession.addon:ShowChallenge("manual")
    for _ = 1, 100 do tokenMain.scripts.OnUpdate(tokenMain, 0.05) end
    local challenge = tokenSession.addon.currentChallenge
    local expectedAward = challenge.id == "squats" and challenge.rewardRatio >= 0.90
    assert(HoppdebaeseDB.fuultierTokens == tokensBefore, "Rolling an exercise awarded a Fuultier token before completion")
    assert(HoppdebaeseDB.todo[1].rewardRatio == challenge.rewardRatio, "Todo did not preserve the rolled reward ratio")
    tokenSession.addon.todoRows[1].complete.scripts.OnClick(tokenSession.addon.todoRows[1].complete)
    assert(HoppdebaeseDB.fuultierTokens == tokensBefore + (expectedAward and 1 or 0), "Completed exercise token eligibility was applied incorrectly")
    if challenge.id == "squats" then
        if expectedAward then sawQualifyingExercise = true else sawNonQualifyingExercise = true end
    end
    HoppdebaeseDB.daily.stats.squats = 0
    if sawQualifyingExercise and sawNonQualifyingExercise then break end
end
assert(sawQualifyingExercise and sawNonQualifyingExercise, "Token test did not cover both exercise value bands")

for id in pairs(dailyGoals) do tokenSession.addon.sessionDisabled[id] = true end
HoppdebaeseDB.triggers.cats = true
local tokensBeforeChallenges = HoppdebaeseDB.fuultierTokens
local sawHighCat = false
for _ = 1, 300 do
    tokenSession.addon:ShowChallenge("manual")
    for _ = 1, 100 do tokenMain.scripts.OnUpdate(tokenMain, 0.05) end
    local challenge = tokenSession.addon.currentChallenge
    assert(HoppdebaeseDB.fuultierTokens == tokensBeforeChallenges, "Rolling a non-exercise challenge awarded a Fuultier token")
    if challenge.id == "catPlay" and challenge.rewardRatio >= 0.90 then sawHighCat = true end
    tokenSession.addon.todoRows[1].complete.scripts.OnClick(tokenSession.addon.todoRows[1].complete)
    assert(HoppdebaeseDB.fuultierTokens == tokensBeforeChallenges, "Completing a non-exercise challenge awarded a Fuultier token")
    if sawHighCat then break end
end
assert(sawHighCat, "Token test did not roll a top-ten-percent cat challenge")

HoppdebaeseDB.fuultierTokens = 3
HoppdebaeseDB.todo = {
    { todoID = 9001, id = "squats", text = "20 squats", icon = "", amount = 20, unit = "reps" },
}
local squatsBeforeSkip = tonumber(HoppdebaeseDB.stats.squats) or 0
local completionsBeforeSkip = tonumber(HoppdebaeseDB.completionCounts.squats) or 0
tokenSession.addon:RefreshTodo()
local skipButton = tokenSession.addon.todoRows[1].skip
assert(skipButton:IsShown() and skipButton.enabled, "Exercise Skip button was not enabled with three tokens")
skipButton.scripts.OnClick(skipButton)
assert(HoppdebaeseDB.fuultierTokens == 0 and #HoppdebaeseDB.todo == 0, "Exercise skip did not spend exactly three tokens")
assert((tonumber(HoppdebaeseDB.stats.squats) or 0) == squatsBeforeSkip, "Skipped exercise credited volume")
assert((tonumber(HoppdebaeseDB.completionCounts.squats) or 0) == completionsBeforeSkip, "Skipped exercise credited a completion")

HoppdebaeseDB.todo = {
    { todoID = 9002, id = "catPlay", text = "Play with your cats for 20 minutes", icon = "", amount = 20, unit = "min" },
}
tokenSession.addon:RefreshTodo()
assert(not tokenSession.addon.todoRows[1].skip:IsShown(), "Cat challenge displayed an exercise Skip button")
assert(tokenSession.addon.todoTokenText.text == "Fuultier tokens: 0", "Todo token counter is incorrect")
HoppdebaeseDB.todo = {}
HoppdebaeseDB.fuultierTokens = 2
savedDB = HoppdebaeseDB
local tokenReload = startSession("2026-11-08", 407, "medium")
assert(HoppdebaeseDB.fuultierTokens == 2, "Fuultier tokens did not survive reload")
tokenReload.named.HoppdebaeseSettings:Show()
assert(tokenReload.addon.settingsTokenText.text == "Fuultier tokens: 2", "Settings token counter is incorrect")

-- Daily caps intentionally alter long sessions, so test the raw selection weight
-- separately without completing challenges or changing the available pool.
savedDB = nil
simulatedLevel = 20
local distributionSession = startSession("2026-11-07", 404, "medium")
assert(HoppdebaeseDB.triggers.cats == true, "Cats setting was not enabled by default")
assert(HoppdebaeseDB.triggers.significantOther == false, "Significant-other setting must default off")
local minimapButton = assert(distributionSession.named.HoppdebaeseMinimapButton, "Minimap button was not created")
distributionSession.named.HoppdebaeseTodo:Hide()
minimapButton.scripts.OnClick(minimapButton, "LeftButton")
assert(distributionSession.named.HoppdebaeseTodo:IsShown(), "Minimap left-click did not open Todo")
shiftDown = true
minimapButton.scripts.OnClick(minimapButton, "LeftButton")
assert(distributionSession.named.HoppdebaeseLeaderboard:IsShown(), "Minimap shift-left-click did not open leaderboard")
shiftDown = false
minimapButton.scripts.OnClick(minimapButton, "RightButton")
assert(distributionSession.named.HoppdebaeseSettings:IsShown(), "Minimap right-click did not open Settings")
distributionSession.named.HoppdebaeseLeaderboard:Hide()
distributionSession.named.HoppdebaeseSettings:Hide()
distributionSession.help.scripts.OnClick(distributionSession.help)
assert(distributionSession.named.HoppdebaeseHelp:IsShown(), "Help button did not open the reference window")
distributionSession.named.HoppdebaeseHelp:Hide()

-- WoW Forever guild messages use a space-separated first and last name. They
-- must not create a second local-player row or alter old saved entries.
local selfEchoKey = "Testhero Chrieger"
distributionSession.addon.scripts.OnEvent(
    distributionSession.addon,
    "CHAT_MSG_ADDON",
    "HOPPDEBASE",
    "S|medium|z=1,sq=2",
    "GUILD",
    selfEchoKey
)
assert(HoppdebaeseDB.guildStats[selfEchoKey] == nil, "Self guild echo was stored")
local legacySelfEntry = {
    difficulty = "medium",
    completedChallenges = 99,
    stats = { squats = 999 },
    completionCounts = { squats = 99 },
}
HoppdebaeseDB.guildStats[selfEchoKey] = legacySelfEntry
HoppdebaeseDB.stats.squats = 10
HoppdebaeseDB.guildStats["Otherhero-Testrealm"] = {
    difficulty = "medium",
    completedChallenges = 2,
    stats = { squats = 20 },
    completionCounts = { squats = 2 },
}
distributionSession.addon.scripts.OnEvent(
    distributionSession.addon,
    "CHAT_MSG_ADDON",
    "HOPPDEBASE",
    "S|medium|z=3,sq=f",
    "GUILD",
    "Testhero Schami"
)
assert(HoppdebaeseDB.guildStats["Testhero Schami"], "Same-first-name guildmate was not stored")
distributionSession.named.HoppdebaeseLeaderboard:Show()
local leaderboardText = distributionSession.addon.leaderboardText.text
local _, playerRows = leaderboardText:gsub("Testhero", "")
assert(playerRows == 2, "Leaderboard omitted a guildmate who shares the local first name")
assert(not leaderboardText:find(selfEchoKey, 1, true), "Leaderboard rendered the full-name self entry")
assert(leaderboardText:find("Testhero Schami", 1, true), "Leaderboard omitted the distinct full-name guildmate")
assert(leaderboardText:find(">> ", 1, true) and leaderboardText:find("(YOU)", 1, true), "Local leaderboard row is not highlighted")
assert(HoppdebaeseDB.guildStats[selfEchoKey] == legacySelfEntry, "Legacy self entry was modified or deleted")
distributionSession.named.HoppdebaeseLeaderboard:Hide()
distributionSession.named.HoppdebaeseExerciseLeaderboard:Show()
local exerciseLeaderboardText = distributionSession.addon.exerciseLeaderboardText.text
assert(exerciseLeaderboardText:find("Total: 45 reps", 1, true), "Exercise leaderboard total is incorrect")
assert(exerciseLeaderboardText:find("Otherhero", 1, true), "Exercise leaderboard omitted a top contributor")
assert(exerciseLeaderboardText:find("Testhero Schami", 1, true), "Exercise leaderboard omitted the distinct full-name guildmate")
assert(exerciseLeaderboardText:find("(YOU)", 1, true), "Local exercise standing is not highlighted")
assert(not exerciseLeaderboardText:find(selfEchoKey, 1, true), "Exercise leaderboard rendered the full-name self entry")
assert(HoppdebaeseDB.guildStats[selfEchoKey] == legacySelfEntry, "Exercise leaderboard modified legacy self data")
distributionSession.named.HoppdebaeseExerciseLeaderboard:Hide()

local distributionTotal = 2000
local stapleHits = 0
local rareHits = 0
local stapleCounts = { squats = 0, situps = 0, pushups = 0 }
local catCounts = { catPlay = 0, catPets = 0, catLitter = 0 }
local mainFrame = assert(distributionSession.named.HoppdebaeseBoxFrame)
local todoFrame = assert(distributionSession.named.HoppdebaeseTodo)
assert(todoFrame.backdropColor and todoFrame.backdropColor[4] == 0.38, "Todo backdrop is not sufficiently translucent")
todoFrame:SetSize(240, 110)
todoFrame.scripts.OnSizeChanged(todoFrame)
assert(distributionSession.addon.todoContent:GetWidth() >= 205, "Compact Todo layout became too narrow")
local originalTodoWidth = distributionSession.addon.todoContent:GetWidth()
todoFrame:SetSize(700, 520)
todoFrame.scripts.OnSizeChanged(todoFrame)
assert(distributionSession.addon.todoContent:GetWidth() > originalTodoWidth, "Todo content did not follow window resize")
assert(HoppdebaeseDB.todoWindow.width == 700 and HoppdebaeseDB.todoWindow.height == 520, "Todo size was not saved")

-- Primary and secondary profession slots trigger the mixed Easy pool at multiples of ten.
for index, expectedName in ipairs({ "Alchemy", "Fishing", "Cooking", "First Aid" }) do
    professionSkills[index].rank = professionSkills[index].rank + 1
    mainFrame:Hide()
    todoFrame:Hide()
    distributionSession.addon.scripts.OnEvent(distributionSession.addon, "SKILL_LINES_CHANGED")
    assert(mainFrame:IsShown(), expectedName .. " milestone did not open a challenge")
    assert(distributionSession.addon.titleText.text == expectedName .. " Skill " .. professionSkills[index].rank)
    for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
    assert(todoFrame:IsShown(), expectedName .. " milestone did not open Todo")
    HoppdebaeseDB.todo = {}
end
professionSkills[1].rank = 11
mainFrame:Hide()
distributionSession.addon.scripts.OnEvent(distributionSession.addon, "SKILL_LINES_CHANGED")
assert(not mainFrame:IsShown(), "Non-multiple profession skill opened a challenge")

local sawProfessionExercise, sawProfessionWellness = false, false
for _ = 1, 200 do
    distributionSession.addon:ShowChallenge("profession")
    for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
    local id = distributionSession.addon.currentChallenge.id
    if dailyGoals[id] then sawProfessionExercise = true else sawProfessionWellness = true end
    HoppdebaeseDB.todo = {}
    if sawProfessionExercise and sawProfessionWellness then break end
end
assert(sawProfessionExercise and sawProfessionWellness, "Profession pool did not mix exercises and wellness challenges")

for _ = 1, distributionTotal do
    distributionSession.addon:ShowChallenge("manual")
    for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
    local challenge = distributionSession.addon.currentChallenge
    local id = challenge.id
    if stapleCounts[id] then
        stapleCounts[id] = stapleCounts[id] + 1
        stapleHits = stapleHits + 1
    end
    if catCounts[id] then catCounts[id] = catCounts[id] + 1 end
    if id == "elephant" then rareHits = rareHits + 1 end
    HoppdebaeseDB.todo = {}
end

local stapleShare = stapleHits / distributionTotal
assert(stapleShare > 0.20, string.format("Weighted staple share too low: %.1f%%", stapleShare * 100))
assert(stapleShare < 0.32, string.format("Weighted staple share too high: %.1f%%", stapleShare * 100))
assert(rareHits >= 5 and rareHits <= 40, "Rare challenge did not stay near one percent: " .. rareHits)
assert(catCounts.catPlay > 0 and catCounts.catPets > 0 and catCounts.catLitter > 0, "Enabled cat challenges did not enter the wheel")

HoppdebaeseDB.triggers.cats = false
for _ = 1, 100 do
    distributionSession.addon:ShowChallenge("manual")
    for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
    local challengeID = distributionSession.addon.currentChallenge.id
    assert(not catCounts[challengeID], "Disabled cat challenge entered the wheel")
    HoppdebaeseDB.todo = {}
end
HoppdebaeseDB.triggers.cats = true

HoppdebaeseDB.triggers.cats = false
HoppdebaeseDB.triggers.significantOther = false
for _ = 1, 100 do
    distributionSession.addon:ShowChallenge("manual")
    for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
    assert(distributionSession.addon.currentChallenge.id ~= "qualityTime", "Disabled significant-other challenge entered the wheel")
    HoppdebaeseDB.todo = {}
end
HoppdebaeseDB.triggers.significantOther = true
local sawQualityTime = false
for _ = 1, 300 do
    distributionSession.addon:ShowChallenge("manual")
    for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
    local challenge = distributionSession.addon.currentChallenge
    if challenge.id == "qualityTime" then
        assert(challenge.text == "Spend quality time with your significant other", "Quality-time challenge displayed a time amount")
        sawQualityTime = true
    end
    HoppdebaeseDB.todo = {}
    if sawQualityTime then break end
end
assert(sawQualityTime, "Enabled significant-other challenge did not enter the wheel")
HoppdebaeseDB.triggers.significantOther = false
HoppdebaeseDB.triggers.cats = true
print("\nWeighted selection over " .. distributionTotal .. " unchanged-pool rolls:")
print(string.format(
    "    Squats: %d  |  Sit-ups: %d  |  Push-ups: %d  |  Combined: %.1f%%",
    stapleCounts.squats,
    stapleCounts.situps,
    stapleCounts.pushups,
    stapleShare * 100
))

-- Verify popup delay and center-row commitment independently of the session data.
distributionSession.addon:ShowChallenge("manual")
local initialBottom = distributionSession.addon.boxItems[5]
for _ = 1, 8 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
assert(distributionSession.addon.boxItems[5] == initialBottom, "Box moved before the 0.45 second delay")
for _ = 1, 92 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
assert(distributionSession.addon.currentChallenge == distributionSession.addon.boxItems[3])

distributionSession.addon:ShowChallenge("manual")
for _ = 1, 9 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
local earlyAdvances = 0
local previousBottom = distributionSession.addon.boxItems[5]
for _ = 1, 20 do
    mainFrame.scripts.OnUpdate(mainFrame, 0.05)
    if distributionSession.addon.boxItems[5] ~= previousBottom then
        earlyAdvances = earlyAdvances + 1
        previousBottom = distributionSession.addon.boxItems[5]
    end
end
for _ = 1, 40 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
local lateAdvances = 0
previousBottom = distributionSession.addon.boxItems[5]
for _ = 1, 20 do
    mainFrame.scripts.OnUpdate(mainFrame, 0.05)
    if distributionSession.addon.boxItems[5] ~= previousBottom then
        lateAdvances = lateAdvances + 1
        previousBottom = distributionSession.addon.boxItems[5]
    end
end
assert(earlyAdvances > lateAdvances * 3, "Roll ending is not substantially slower than its beginning")
HoppdebaeseDB.todo = {}

-- The box follows the resized main frame, and low/high amounts retain their
-- green/red range metadata for the row renderer.
local originalBoxWidth = distributionSession.addon.boxVisual:GetWidth()
mainFrame:SetSize(720, 610)
mainFrame.scripts.OnSizeChanged(mainFrame)
assert(distributionSession.addon.boxVisual:GetWidth() > originalBoxWidth, "Box width did not follow window resize")
assert(distributionSession.addon.boxRows[1]:GetHeight() > 40, "Box rows did not grow with window height")

local sawGreen, sawRed = false, false
local sawCatLowRed, sawCatHighGreen = false, false
for _ = 1, 1000 do
    distributionSession.addon:ShowChallenge("manual")
    for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
    local challenge = distributionSession.addon.currentChallenge
    local color = distributionSession.addon.boxRows[3].background.vertexColor
    if challenge.id == "catPlay" and challenge.valueRatio <= 0.15 then
        sawCatLowRed = color[1] > color[2]
    elseif challenge.id == "catPlay" and challenge.valueRatio >= 0.85 then
        sawCatHighGreen = color[2] > color[1]
    elseif challenge.valueRatio and not challenge.higherIsBetter and challenge.valueRatio <= 0.15 then
        sawGreen = color[2] > color[1]
    elseif challenge.valueRatio and not challenge.higherIsBetter and challenge.valueRatio >= 0.85 then
        sawRed = color[1] > color[2]
    end
    HoppdebaeseDB.todo = {}
    if sawGreen and sawRed and sawCatLowRed and sawCatHighGreen then break end
end
assert(sawGreen and sawRed, "Low/high challenge values did not render green/red")
assert(sawCatLowRed and sawCatHighGreen, "Cat play did not render minimum red and maximum green")

-- A pending Todo survives an addon reload and can only be completed there.
distributionSession.addon:ShowChallenge("manual")
for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
assert(#HoppdebaeseDB.todo == 1, "Pending Todo was not saved")
local pendingTodoID = HoppdebaeseDB.todo[1].todoID
savedDB = HoppdebaeseDB
local reloadedSession = startSession("2026-11-07", 405, "medium")
assert(HoppdebaeseDB.todo[1].todoID == pendingTodoID, "Pending Todo did not survive reload")
assert(reloadedSession.named.HoppdebaeseTodo:GetWidth() == 700, "Todo width did not survive reload")
assert(reloadedSession.named.HoppdebaeseTodo:GetHeight() == 520, "Todo height did not survive reload")
assert(not pcall(findButton, reloadedSession.frames, "Complete & Close"), "Main completion button still exists")
local todoComplete = findButton(reloadedSession.frames, "Complete")
todoComplete.scripts.OnClick(todoComplete)
assert(#HoppdebaeseDB.todo == 0, "Reloaded Todo could not be completed")

local statsBeforeReset = HoppdebaeseDB.stats
local countsBeforeReset = HoppdebaeseDB.completionCounts
local guildStatsBeforeReset = HoppdebaeseDB.guildStats
local todoBeforeReset = HoppdebaeseDB.todo
local completedBeforeReset = HoppdebaeseDB.completedChallenges
local tokensBeforeReset = HoppdebaeseDB.fuultierTokens
local resetExpectations = {
    main = { frame = "HoppdebaeseBoxFrame", width = 500, height = 430, x = 0, y = 40 },
    todo = { frame = "HoppdebaeseTodo", width = 560, height = 470, x = 25, y = 10 },
    leaderboard = { frame = "HoppdebaeseLeaderboard", width = 650, height = 500, x = 50, y = 20 },
    exerciseLeaderboard = { frame = "HoppdebaeseExerciseLeaderboard", width = 610, height = 580, x = 75, y = 0 },
    rested = { frame = "HoppdebaeseRested", width = 520, height = 430, x = 10, y = 20 },
    help = { frame = "HoppdebaeseHelp", width = 720, height = 600, x = -20, y = 10 },
    progress = { frame = "HoppdebaeseProgress", width = 690, height = 590, x = -35, y = 10 },
    settings = { frame = "HoppdebaeseSettings", width = 420, height = 700, x = 0, y = 0 },
}
for key, expected in pairs(resetExpectations) do
    local window = assert(reloadedSession.named[expected.frame], key .. " window is missing")
    local reset = assert(reloadedSession.addon.windowResetButtons[key], key .. " reset button is missing")
    window:SetSize(333, 222)
    window:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 91, -73)
    reset.scripts.OnClick(reset)
    local point, _, relativePoint, x, y = window:GetPoint(1)
    assert(window:GetWidth() == expected.width and window:GetHeight() == expected.height, key .. " reset did not restore size")
    assert(point == "CENTER" and relativePoint == "CENTER" and x == expected.x and y == expected.y, key .. " reset did not restore position")
end
assert(HoppdebaeseDB.window.width == 500 and HoppdebaeseDB.window.height == 430, "Main reset geometry was not persisted")
assert(HoppdebaeseDB.todoWindow.width == 560 and HoppdebaeseDB.todoWindow.height == 470, "Todo reset geometry was not persisted")
assert(HoppdebaeseDB.stats == statsBeforeReset and HoppdebaeseDB.completionCounts == countsBeforeReset, "Window reset replaced progress data")
assert(HoppdebaeseDB.guildStats == guildStatsBeforeReset and HoppdebaeseDB.todo == todoBeforeReset, "Window reset replaced guild or Todo data")
assert(HoppdebaeseDB.completedChallenges == completedBeforeReset and HoppdebaeseDB.fuultierTokens == tokensBeforeReset, "Window reset changed progress values")

local reloadedMain = reloadedSession.named.HoppdebaeseBoxFrame
reloadedMain:Show()
reloadedSession.minimize.scripts.OnClick(reloadedSession.minimize)
assert(not reloadedMain:IsShown(), "Minimize did not hide the main window")

distributionSession = reloadedSession
mainFrame = reloadedMain

-- Exactly the tenth completed quest should open the box; disabled triggers keep counting.
mainFrame:Hide()
for _ = 1, 9 do distributionSession.addon.scripts.OnEvent(distributionSession.addon, "QUEST_TURNED_IN") end
assert(not mainFrame:IsShown(), "Quest box opened before ten completed quests")
distributionSession.addon.scripts.OnEvent(distributionSession.addon, "QUEST_TURNED_IN")
assert(mainFrame:IsShown(), "Tenth completed quest did not open the box")
for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
mainFrame:Hide()
HoppdebaeseDB.triggers.quests = false
for _ = 1, 10 do distributionSession.addon.scripts.OnEvent(distributionSession.addon, "QUEST_TURNED_IN") end
assert(HoppdebaeseDB.questsCompleted == 20, "Quest counter did not continue while disabled")
assert(not mainFrame:IsShown(), "Disabled quest trigger opened the box")

HoppdebaeseDB.triggers.quests = true
HoppdebaeseDB.questsCompleted = 0
distributionSession.addon.questSlider.scripts.OnValueChanged(distributionSession.addon.questSlider, 3)
for _ = 1, 2 do distributionSession.addon.scripts.OnEvent(distributionSession.addon, "QUEST_TURNED_IN") end
assert(not mainFrame:IsShown(), "Adjustable quest trigger opened too early")
distributionSession.addon.scripts.OnEvent(distributionSession.addon, "QUEST_TURNED_IN")
assert(mainFrame:IsShown(), "Adjusted three-quest trigger did not open")
for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
mainFrame:Hide()

-- Guild announcements occur once for a selected center item and respect the toggle.
_G.IsInGuild = function() return true end
guildMessages = {}
HoppdebaeseDB.todo = {}
HoppdebaeseDB.announceGuild = true
distributionSession.addon:ShowChallenge("manual")
for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
assert(#guildMessages == 1 and guildMessages[1].channel == "GUILD", "Guild announcement missing")
assert(guildMessages[1].message:find("from Workout Challenge", 1, true), "Roll announcement omitted its event")
HoppdebaeseDB.announceGuild = false
distributionSession.addon:ShowChallenge("manual")
for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
assert(#guildMessages == 1, "Disabled guild announcements still sent a message")

HoppdebaeseDB.announceCompletion = true
local completionButton = findButton(distributionSession.frames, "Complete")
completionButton.scripts.OnClick(completionButton)
assert(#guildMessages == 2, "Completion announcement missing")
assert(guildMessages[2].message:find("completed from", 1, true), "Completion announcement omitted its event")
HoppdebaeseDB.announceCompletion = false
completionButton = findButton(distributionSession.frames, "Complete")
completionButton.scripts.OnClick(completionButton)
assert(#guildMessages == 2, "Disabled completion announcements still sent a message")

print("ALL_DIFFICULTIES_SIMULATION_PASS")