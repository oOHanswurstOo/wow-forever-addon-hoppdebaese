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
    _G.UnitFullName = function() return "Testhero", "Testrealm" end
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

-- Daily caps intentionally alter long sessions, so test the raw selection weight
-- separately without completing challenges or changing the available pool.
savedDB = nil
simulatedLevel = 20
local distributionSession = startSession("2026-11-07", 404, "medium")
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

-- Guild addon messages can echo back with a differently formatted realm. They
-- must not create a second local-player row or alter old saved entries.
local selfEchoKey = "Testhero-Test realm"
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
distributionSession.named.HoppdebaeseLeaderboard:Show()
local leaderboardText = distributionSession.addon.leaderboardText.text
local _, playerRows = leaderboardText:gsub("Testhero", "")
assert(playerRows == 1, "Leaderboard rendered the local player more than once")
assert(HoppdebaeseDB.guildStats[selfEchoKey] == legacySelfEntry, "Legacy self entry was modified or deleted")
distributionSession.named.HoppdebaeseLeaderboard:Hide()
distributionSession.named.HoppdebaeseExerciseLeaderboard:Show()
local exerciseLeaderboardText = distributionSession.addon.exerciseLeaderboardText.text
assert(exerciseLeaderboardText:find("Total: 30 reps", 1, true), "Exercise leaderboard total is incorrect")
assert(exerciseLeaderboardText:find("Otherhero", 1, true), "Exercise leaderboard omitted a top contributor")
distributionSession.named.HoppdebaeseExerciseLeaderboard:Hide()

local distributionTotal = 2000
local stapleHits = 0
local rareHits = 0
local stapleCounts = { squats = 0, situps = 0, pushups = 0 }
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
    if id == "elephant" then rareHits = rareHits + 1 end
    HoppdebaeseDB.todo = {}
end

local stapleShare = stapleHits / distributionTotal
assert(stapleShare > 0.24, string.format("Weighted staple share too low: %.1f%%", stapleShare * 100))
assert(stapleShare < 0.35, string.format("Weighted staple share too high: %.1f%%", stapleShare * 100))
assert(rareHits >= 5 and rareHits <= 40, "Rare challenge did not stay near one percent: " .. rareHits)
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
for _ = 1, 300 do
    distributionSession.addon:ShowChallenge("manual")
    for _ = 1, 100 do mainFrame.scripts.OnUpdate(mainFrame, 0.05) end
    local challenge = distributionSession.addon.currentChallenge
    local color = distributionSession.addon.boxRows[3].background.vertexColor
    if challenge.valueRatio and challenge.valueRatio <= 0.15 then
        sawGreen = color[2] > color[1]
    elseif challenge.valueRatio and challenge.valueRatio >= 0.85 then
        sawRed = color[1] > color[2]
    end
    HoppdebaeseDB.todo = {}
    if sawGreen and sawRed then break end
end
assert(sawGreen and sawRed, "Low/high challenge values did not render green/red")

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