-- Hoppdebäse
-- A self-contained workout challenge addon for WoW Classic-style clients.

local ADDON_NAME = ...
local addon = CreateFrame("Frame")
addon.sessionDisabled = {}
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local DEFAULTS = {
    schemaVersion = 1,
    difficulty = "medium",
    stats = {},
    completionCounts = {},
    guildStats = {},
    completedChallenges = 0,
    questsCompleted = 0,
    questInterval = 10,
    professionRanks = {},
    announceGuild = true,
    announceCompletion = true,
    promptCooldowns = {},
    todo = {},
    nextTodoID = 0,
    daily = {
        date = "",
        stats = {},
    },
    triggers = {
        levelUp = true,
        death = true,
        flight = true,
        dungeon = true,
        quests = true,
        professions = true,
    },
    tools = {
        bench = false,
        pullupBar = false,
        dumbbells = false,
        treadmill = false,
    },
    window = {
        width = 500,
        height = 430,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 40,
    },
    todoWindow = {
        width = 560,
        height = 470,
        point = "CENTER",
        relativePoint = "CENTER",
        x = 25,
        y = 10,
    },
}

-- Early-level rolls stay approachable, while the daily goals below prevent the
-- weighted staple exercises from accumulating unreasonable volume in one day.
local LEVEL_TIERS = {
    { maxLevel = 10, counts = { min = 5, max = 12 }, seconds = { min = 15, max = 35 }, toolCounts = { min = 5, max = 10 } },
    { maxLevel = 20, counts = { min = 8, max = 18 }, seconds = { min = 20, max = 50 }, toolCounts = { min = 7, max = 15 } },
    { maxLevel = 30, counts = { min = 10, max = 22 }, seconds = { min = 25, max = 60 }, toolCounts = { min = 8, max = 18 } },
    { maxLevel = 40, counts = { min = 12, max = 26 }, seconds = { min = 30, max = 75 }, toolCounts = { min = 10, max = 22 } },
    { maxLevel = 50, counts = { min = 15, max = 30 }, seconds = { min = 40, max = 90 }, toolCounts = { min = 12, max = 25 } },
    { maxLevel = 999, counts = { min = 18, max = 35 }, seconds = { min = 45, max = 105 }, toolCounts = { min = 15, max = 30 } },
}

local ICONS = {
    legs = "Interface\\Icons\\INV_Boots_05",
    push = "Interface\\Icons\\Ability_Warrior_InnerRage",
    hold = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    cardio = "Interface\\Icons\\Ability_Rogue_Sprint",
    balance = "Interface\\Icons\\Spell_Nature_Strength",
    pull = "Interface\\Icons\\Ability_Warrior_ShieldBash",
    press = "Interface\\Icons\\Ability_DualWield",
    arms = "Interface\\Icons\\INV_Hammer_04",
    weights = "Interface\\Icons\\INV_Stone_WeightStone_03",
    water = "Interface\\Icons\\INV_Drink_18",
    recovery = "Interface\\Icons\\Spell_Nature_Sleep",
}

local EXERCISES = {
    { id = "squats", code = "sq", name = "Squats", label = "%d squats", value = "counts", unit = "reps", weight = 1.5, icon = ICONS.legs },
    { id = "situps", code = "su", name = "Sit-ups", label = "%d sit-ups", value = "counts", unit = "reps", weight = 1.7, icon = ICONS.balance },
    { id = "wallSit", code = "ws", name = "Wall sit", label = "%d sec wall sit", value = "seconds", unit = "sec", icon = ICONS.hold },
    { id = "pushups", code = "pu", name = "Push-ups", label = "%d push-ups", value = "counts", unit = "reps", weight = 1.7, amountMultiplier = 1.6, icon = ICONS.push },
    { id = "jumpingJacks", code = "jj", name = "Jumping jacks", label = "%d jumping jacks", value = "counts", unit = "reps", icon = ICONS.cardio },
    { id = "plank", code = "pl", name = "Plank", label = "%d sec plank", value = "seconds", unit = "sec", icon = ICONS.hold },
    { id = "reverseLunges", code = "rl", name = "Reverse lunges", label = "%d reverse lunges", value = "counts", unit = "reps", icon = ICONS.legs },
    { id = "calfRaises", code = "cr", name = "Calf raises", label = "%d calf raises", value = "counts", unit = "reps", amountMultiplier = 1.2, icon = ICONS.legs },
    { id = "gluteBridges", code = "gb", name = "Glute bridges", label = "%d glute bridges", value = "counts", unit = "reps", icon = ICONS.balance },
    { id = "birdDogs", code = "bd", name = "Bird-dogs", label = "%d bird-dogs", value = "counts", unit = "reps", icon = ICONS.balance },
    { id = "mountainClimbers", code = "mc", name = "Mountain climbers", label = "%d mountain climbers", value = "counts", unit = "reps", icon = ICONS.cardio },
    { id = "highKnees", code = "hk", name = "High knees", label = "%d high knees", value = "counts", unit = "reps", icon = ICONS.cardio },
    { id = "deadBugs", code = "db", name = "Dead bugs", label = "%d dead bugs", value = "counts", unit = "reps", icon = ICONS.balance },
    { id = "sidePlank", code = "sp", name = "Side plank", label = "%d sec side plank", value = "seconds", unit = "sec", icon = ICONS.hold },
    { id = "benchPress", code = "bp", name = "Bench presses", label = "%d bench presses", value = "toolCounts", unit = "reps", tool = "bench", icon = ICONS.weights },
    {
        id = "pullups", code = "up", name = "Pull-ups", label = "%d pull-ups", unit = "reps", tool = "pullupBar", icon = ICONS.pull,
        difficultyValues = {
            easy = { { maxLevel = 999, min = 1, max = 1 } },
            medium = { { maxLevel = 30, min = 1, max = 2 }, { maxLevel = 50, min = 2, max = 3 }, { maxLevel = 999, min = 2, max = 4 } },
            hard = { { maxLevel = 30, min = 2, max = 3 }, { maxLevel = 50, min = 3, max = 4 }, { maxLevel = 999, min = 4, max = 5 } },
            extreme = { { maxLevel = 30, min = 4, max = 6 }, { maxLevel = 50, min = 6, max = 8 }, { maxLevel = 999, min = 8, max = 10 } },
        },
    },
    { id = "deadHang", code = "dh", name = "Dead hang", label = "%d sec dead hang", value = "seconds", unit = "sec", tool = "pullupBar", icon = ICONS.pull },
    { id = "dumbbellCurls", code = "dc", name = "Dumbbell curls", label = "%d dumbbell curls", value = "toolCounts", unit = "reps", tool = "dumbbells", icon = ICONS.arms },
    { id = "dumbbellRows", code = "dr", name = "Dumbbell rows", label = "%d dumbbell rows", value = "toolCounts", unit = "reps", tool = "dumbbells", icon = ICONS.pull },
    { id = "seatedShoulderPress", code = "ds", name = "Seated dumbbell shoulder presses", label = "%d seated dumbbell shoulder presses", value = "toolCounts", unit = "reps", tools = { "bench", "dumbbells" }, icon = ICONS.press },
    { id = "lateralRaises", code = "lr", name = "Lateral raises", label = "%d lateral raises", value = "toolCounts", unit = "reps", tool = "dumbbells", icon = ICONS.press },
    { id = "overheadTriceps", code = "ot", name = "Overhead triceps extensions", label = "%d overhead triceps extensions", value = "toolCounts", unit = "reps", tool = "dumbbells", icon = ICONS.push },
    { id = "hammerCurls", code = "hc", name = "Hammer curls", label = "%d hammer curls", value = "toolCounts", unit = "reps", tool = "dumbbells", icon = ICONS.arms },
    { id = "treadmillWalk", code = "tw", name = "Treadmill walk", label = "%d min treadmill walk", fixedValues = { min = 5, max = 15 }, unit = "min", tool = "treadmill", icon = ICONS.legs },
    { id = "treadmillRun", code = "tr", name = "Treadmill run", label = "%d min treadmill run", fixedValues = { min = 3, max = 10 }, unit = "min", tool = "treadmill", icon = ICONS.cardio },
}

local EASY_CHALLENGES = {
    { id = "water", code = "wa", name = "Glasses of water", text = "Drink a glass of water", amount = 1, unit = "glasses", icon = ICONS.water },
    { id = "stretch", code = "st", name = "Stretching", label = "Stand and stretch for %d seconds", values = { min = 20, max = 60 }, unit = "sec", icon = ICONS.recovery },
    { id = "shoulders", code = "sr", name = "Shoulder rolls", label = "%d slow shoulder rolls", values = { min = 6, max = 12 }, unit = "reps", icon = ICONS.recovery },
    { id = "breathing", code = "br", name = "Deep breaths", label = "Take %d slow, deep breaths", values = { min = 3, max = 6 }, unit = "breaths", icon = ICONS.recovery },
    { id = "eyeRest", code = "er", name = "Eye rest", text = "Look at something far away for 20 seconds", amount = 20, unit = "sec", icon = ICONS.recovery },
    { id = "shower", code = "sh", name = "Shower / face wash", text = "Take a shower / wash your face", amount = 1, unit = "times", cooldown = 14400, icon = ICONS.water },
    { id = "freshAir", code = "fa", name = "Stosslüften", label = "Open the window and walk around for %d seconds", values = { min = 30, max = 120 }, fixedScale = true, unit = "sec", icon = ICONS.recovery },
    { id = "dishes", code = "di", name = "Dishes", text = "Do the dishes if not done, else free", amount = 1, unit = "times", icon = ICONS.water },
    { id = "elephant", code = "el", name = "Rüssel strichle", text = "Gang di Rüssel go strichle", amount = 1, unit = "times", rareChance = 0.01, icon = ICONS.recovery },
}

local CHALLENGE_DESCRIPTIONS = {
    squats = "Lower-body squat repetitions for legs and hips.",
    situps = "Floor sit-ups for the abdominal muscles.",
    wallSit = "Hold a seated position with your back against a wall.",
    pushups = "Upper-body pushing repetitions from the floor or an elevated surface.",
    jumpingJacks = "Full-body jumping jacks to raise your heart rate.",
    plank = "Hold a straight forearm or high-plank position.",
    reverseLunges = "Step backward into alternating lunges; the amount is total repetitions.",
    calfRaises = "Rise onto your toes and lower with control.",
    gluteBridges = "Lift your hips from the floor while keeping your upper back planted.",
    birdDogs = "From hands and knees, extend opposite arm and leg; count both sides.",
    mountainClimbers = "Alternate driving your knees forward from a plank position.",
    highKnees = "Run in place while lifting the knees high; count total repetitions.",
    deadBugs = "Lower opposite arm and leg from a face-up tabletop position.",
    sidePlank = "Hold a side-plank position; split the time between both sides.",
    benchPress = "Press weights while supported by a workout bench.",
    pullups = "Pull yourself up from a pull-up bar with controlled form.",
    deadHang = "Hang from a pull-up bar with straight arms and controlled shoulders.",
    dumbbellCurls = "Curl dumbbells toward the shoulders; count total repetitions.",
    dumbbellRows = "Pull dumbbells toward the torso with a stable back.",
    seatedShoulderPress = "Press dumbbells overhead while seated on a bench.",
    lateralRaises = "Raise dumbbells out to the sides with soft elbows.",
    overheadTriceps = "Lower and extend a dumbbell behind the head.",
    hammerCurls = "Curl dumbbells with palms facing inward.",
    treadmillWalk = "Walk on a treadmill for the displayed number of minutes.",
    treadmillRun = "Run on a treadmill for the displayed number of minutes.",
    water = "Drink one glass of water.",
    stretch = "Stand up and gently stretch for the displayed duration.",
    shoulders = "Perform slow shoulder rolls to release upper-body tension.",
    breathing = "Pause for slow, controlled deep breaths.",
    eyeRest = "Look away from the screen at a distant object.",
    shower = "Take a shower or wash your face; this prompt has a four-hour cooldown.",
    freshAir = "Open the window fully and walk around while airing the room.",
    dishes = "Do the dishes if they are waiting; otherwise this challenge is free.",
    elephant = "A rare one-percent Swiss-German surprise challenge.",
}

local TRIGGER_INFO = {
    levelUp = { title = "Level Up Challenge", multiplier = 1 },
    death = { title = "Defeat Recovery Challenge", multiplier = 1.35 },
    flight = { title = "Flight Path Challenge", multiplier = 0.75 },
    dungeon = { title = "Dungeon Complete Challenge", multiplier = 1.2 },
    quest = { title = "10 Quests Complete Challenge", multiplier = 1 },
    profession = { title = "Profession Skill Milestone", multiplier = 1 },
    manual = { title = "Workout Challenge", multiplier = 1 },
}

local DIFFICULTIES = {
    easy = { label = "Easy", multiplier = 0.7 },
    medium = { label = "Medium", multiplier = 1 },
    hard = { label = "Hard", multiplier = 1.5 },
    extreme = { label = "Extreme", multiplier = 3 },
}

local COMPLETION_QUOTES = {
    "Geili Sach",
    "Looksmaxxer",
    "Mr. Maschine over head",
    "Au im IRL gits es Level up lol",
    "Starch gmacht",
    "Maschine!",
    "Du bisch am grinde",
    "Nöd schlecht, hä",
    "Witer so",
    "Level up im echte Läbe",
    "Stabil abgliferet",
    "Das git Gains",
    "Hopp, dä nächsti",
    "Suuberi Sach",
    "Du ziehsch dure",
    "Fitness-Skill erhöht",
    "Ehrenmensch",
    "Chli besser als geschter",
}

-- Goals cap how much of one movement can be assigned in a calendar day. They
-- are deliberately conservative so a normal six-hour leveling session remains
-- achievable; holds and treadmill work use seconds/minutes instead of reps.
local DAILY_GOALS = {
    squats = { easy = 30, medium = 45, hard = 65, extreme = 130 },
    situps = { easy = 20, medium = 32, hard = 48, extreme = 96 },
    wallSit = { easy = 50, medium = 75, hard = 110, extreme = 220 },
    pushups = { easy = 26, medium = 44, hard = 65, extreme = 130 },
    jumpingJacks = { easy = 30, medium = 50, hard = 75, extreme = 150 },
    plank = { easy = 50, medium = 75, hard = 110, extreme = 220 },
    reverseLunges = { easy = 20, medium = 30, hard = 45, extreme = 90 },
    calfRaises = { easy = 30, medium = 50, hard = 75, extreme = 150 },
    gluteBridges = { easy = 24, medium = 40, hard = 60, extreme = 120 },
    birdDogs = { easy = 20, medium = 30, hard = 45, extreme = 90 },
    mountainClimbers = { easy = 30, medium = 50, hard = 75, extreme = 150 },
    highKnees = { easy = 30, medium = 50, hard = 75, extreme = 150 },
    deadBugs = { easy = 20, medium = 30, hard = 45, extreme = 90 },
    sidePlank = { easy = 40, medium = 60, hard = 90, extreme = 180 },
    benchPress = { easy = 16, medium = 28, hard = 42, extreme = 84 },
    pullups = { easy = 8, medium = 12, hard = 18, extreme = 36 },
    deadHang = { easy = 45, medium = 60, hard = 90, extreme = 180 },
    dumbbellCurls = { easy = 20, medium = 30, hard = 45, extreme = 90 },
    dumbbellRows = { easy = 20, medium = 30, hard = 45, extreme = 90 },
    seatedShoulderPress = { easy = 16, medium = 28, hard = 42, extreme = 84 },
    lateralRaises = { easy = 16, medium = 24, hard = 36, extreme = 72 },
    overheadTriceps = { easy = 16, medium = 24, hard = 36, extreme = 72 },
    hammerCurls = { easy = 20, medium = 30, hard = 45, extreme = 90 },
    treadmillWalk = { easy = 20, medium = 30, hard = 45, extreme = 90 },
    treadmillRun = { easy = 12, medium = 20, hard = 30, extreme = 60 },
}

local REST_CHALLENGE_IDS = { "stretch", "water", "eyeRest" }
local PROFESSION_EXERCISE_IDS = {
    squats = true,
    situps = true,
    pushups = true,
    jumpingJacks = true,
    plank = true,
    calfRaises = true,
}

local TOOL_LABELS = {
    { key = "bench", text = "Workout bench" },
    { key = "pullupBar", text = "Pull-up bar" },
    { key = "dumbbells", text = "Dumbbells" },
    { key = "treadmill", text = "Running / walking treadmill" },
}

local MESSAGE_PREFIX = "HOPPDEBASE"
local CHALLENGE_BY_CODE = {}
local CHALLENGE_BY_ID = {}
local ALL_CHALLENGES = {}
for _, challenge in ipairs(EXERCISES) do table.insert(ALL_CHALLENGES, challenge) end
for _, challenge in ipairs(EASY_CHALLENGES) do table.insert(ALL_CHALLENGES, challenge) end
for _, challenge in ipairs(ALL_CHALLENGES) do
    CHALLENGE_BY_CODE[challenge.code] = challenge
    CHALLENGE_BY_ID[challenge.id] = challenge
end

local function CopyDefaults(source, destination)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(destination[key]) ~= "table" then
                destination[key] = {}
            end
            CopyDefaults(value, destination[key])
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
end

local function CloneTable(source)
    local clone = {}
    for key, value in pairs(source) do
        clone[key] = type(value) == "table" and CloneTable(value) or value
    end
    return clone
end

local function HasProgress(database)
    return type(database) == "table"
        and ((tonumber(database.completedChallenges) or 0) > 0
            or (type(database.stats) == "table" and next(database.stats) ~= nil))
end

local function InitializeDatabase()
    -- Older builds used an account-wide name. Migrate it only when this character
    -- has no progress, then keep the new per-character name stable across updates.
    if not HasProgress(HoppdebaeseDB) and HasProgress(GuildFitWheelDB) then
        HoppdebaeseDB = CloneTable(GuildFitWheelDB)
    end
    HoppdebaeseDB = HoppdebaeseDB or {}
    CopyDefaults(DEFAULTS, HoppdebaeseDB)
    HoppdebaeseDB.schemaVersion = DEFAULTS.schemaVersion
end

local function GetPlayerLevel(overrideLevel)
    return tonumber(overrideLevel) or UnitLevel("player") or 1
end

local function GetTier(level)
    for _, tier in ipairs(LEVEL_TIERS) do
        if level <= tier.maxLevel then
            return tier
        end
    end
    return LEVEL_TIERS[#LEVEL_TIERS]
end

local function Pick(list)
    return list[math.random(1, #list)]
end

local function PickValue(values)
    if values.min and values.max then return math.random(values.min, values.max) end
    return Pick(values)
end

local function PickWeighted(list)
    local totalWeight = 0
    for _, challenge in ipairs(list) do totalWeight = totalWeight + (challenge.weight or 1) end
    local roll = math.random() * totalWeight
    for _, challenge in ipairs(list) do
        roll = roll - (challenge.weight or 1)
        if roll <= 0 then return challenge end
    end
    return list[#list]
end

local function EnsureDailyState()
    local today = date and date("%Y-%m-%d") or "session"
    if HoppdebaeseDB.daily.date ~= today then
        HoppdebaeseDB.daily.date = today
        HoppdebaeseDB.daily.stats = {}
    end
end

local function GetDailyGoal(exerciseID)
    local goals = DAILY_GOALS[exerciseID]
    if not goals then return nil end
    return goals[HoppdebaeseDB.difficulty] or goals.medium
end

local function GetDailyAmount(exerciseID)
    EnsureDailyState()
    return tonumber(HoppdebaeseDB.daily.stats[exerciseID]) or 0
end

local function GetRemainingDailyGoal(exerciseID)
    local goal = GetDailyGoal(exerciseID)
    if not goal then return nil end
    return math.max(0, goal - GetDailyAmount(exerciseID))
end

local function IsExerciseAvailable(exercise)
    if exercise.tool and not HoppdebaeseDB.tools[exercise.tool] then return false end
    if exercise.tools then
        for _, tool in ipairs(exercise.tools) do
            if not HoppdebaeseDB.tools[tool] then return false end
        end
    end
    if addon.sessionDisabled and addon.sessionDisabled[exercise.id] then return false end
    local remaining = GetRemainingDailyGoal(exercise.id)
    return remaining == nil or remaining > 0
end

local function IsPromptAvailable(challenge)
    if challenge.rareChance then return false end
    if not challenge.cooldown then return true end
    local lastPrompt = tonumber(HoppdebaeseDB.promptCooldowns[challenge.id]) or 0
    local now = time and time() or 0
    return now <= 0 or (now - lastPrompt) >= challenge.cooldown
end

local function GetDifficultyValues(exercise, difficultyKey, level)
    local ranges = exercise.difficultyValues and exercise.difficultyValues[difficultyKey]
    if not ranges then return nil end
    for _, values in ipairs(ranges) do
        if level <= values.maxLevel then return values end
    end
    return ranges[#ranges]
end

local function BuildChallenge(exercise, tier, multiplier, difficultyKey, level)
    if exercise.text then
        local amount = exercise.amount or 1
        local remaining = GetRemainingDailyGoal(exercise.id)
        if remaining then amount = math.min(amount, remaining) end
        return {
            id = exercise.id,
            code = exercise.code,
            name = exercise.name,
            text = exercise.text,
            amount = amount,
            unit = exercise.unit,
            icon = exercise.icon,
        }
    end

    local difficultyValues = GetDifficultyValues(exercise, difficultyKey, level)
    local values = difficultyValues or exercise.values or exercise.fixedValues or tier[exercise.value]
    local amountMultiplier = exercise.amountMultiplier or 1
    local valueMultiplier = (difficultyValues or exercise.fixedScale) and 1 or multiplier * amountMultiplier
    local amount = math.max(1, math.floor((PickValue(values) * valueMultiplier) + 0.5))
    local minimum = math.max(1, math.floor((values.min * valueMultiplier) + 0.5))
    local maximum = math.max(minimum, math.floor((values.max * valueMultiplier) + 0.5))
    local remaining = GetRemainingDailyGoal(exercise.id)
    if remaining then
        amount = math.min(amount, remaining)
        maximum = math.min(maximum, remaining)
        minimum = math.min(minimum, maximum)
    end
    local valueRatio = maximum > minimum and ((amount - minimum) / (maximum - minimum)) or 0
    return {
        id = exercise.id,
        code = exercise.code,
        name = exercise.name,
        text = string.format(exercise.label, amount),
        amount = amount,
        unit = exercise.unit,
        icon = exercise.icon,
        valueRatio = math.max(0, math.min(1, valueRatio)),
    }
end

local function RollChallenge(triggerKey, excludedID)
    local trigger = TRIGGER_INFO[triggerKey] or TRIGGER_INFO.manual
    local difficultyKey = HoppdebaeseDB.difficulty
    local difficulty = DIFFICULTIES[difficultyKey] or DIFFICULTIES.medium
    local level = GetPlayerLevel(addon.pendingLevel)
    local tier = GetTier(level)
    local multiplier = difficulty.multiplier * trigger.multiplier
    local pool = {}
    local workoutCount = 0

    local rareChallenge = CHALLENGE_BY_ID.elephant
    if rareChallenge and rareChallenge.id ~= excludedID and math.random(100) == 1 then
        return BuildChallenge(rareChallenge, tier, 1, "easy", level)
    end

    if triggerKey == "profession" then
        for _, challenge in ipairs(EASY_CHALLENGES) do
            if challenge.id ~= excludedID and IsPromptAvailable(challenge) then table.insert(pool, challenge) end
        end
        for _, exercise in ipairs(EXERCISES) do
            if PROFESSION_EXERCISE_IDS[exercise.id]
                and exercise.id ~= excludedID
                and IsExerciseAvailable(exercise) then
                table.insert(pool, exercise)
            end
        end
        local selected = PickWeighted(pool)
        local isExercise = DAILY_GOALS[selected.id] ~= nil
        return BuildChallenge(selected, tier, isExercise and DIFFICULTIES.easy.multiplier or 1, "easy", level)
    end

    for _, exercise in ipairs(EXERCISES) do
        if exercise.id ~= excludedID and IsExerciseAvailable(exercise) then
            table.insert(pool, exercise)
            workoutCount = workoutCount + 1
        end
    end

    if workoutCount == 0 then
        -- Once every available workout is complete or resting, only wellness
        -- prompts remain for the rest of the day/session.
        for _, challengeID in ipairs(REST_CHALLENGE_IDS) do
            local challenge = CHALLENGE_BY_ID[challengeID]
            if challenge and challenge.id ~= excludedID and IsExerciseAvailable(challenge) then
                table.insert(pool, challenge)
            end
        end
    elseif triggerKey == "flight" or (triggerKey == "levelUp" and GetPlayerLevel(addon.pendingLevel) <= 10) then
        -- Flights and early level-ups also have a chance to roll a lighter break.
        for _, challenge in ipairs(EASY_CHALLENGES) do
            if challenge.id ~= excludedID and IsPromptAvailable(challenge) then
                table.insert(pool, challenge)
            end
        end
    end

    return BuildChallenge(PickWeighted(pool), tier, multiplier, difficultyKey, level)
end

local function GetPlayerName()
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    name = name or UnitName("player") or "Player"
    if not realm or realm == "" then
        if GetNormalizedRealmName then realm = GetNormalizedRealmName() end
        if (not realm or realm == "") and GetRealmName then realm = GetRealmName() end
    end
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function NormalizeCharacterName(name)
    local character, realm = (name or ""):match("^([^-]+)%-?(.*)$")
    if not character then return "" end
    character = string.lower(character)
    realm = string.lower(realm or ""):gsub("[%s%-']", "")
    return realm ~= "" and (character .. "-" .. realm) or character
end

local function IsCurrentPlayer(name)
    local normalizedName = NormalizeCharacterName(name)
    if normalizedName == NormalizeCharacterName(GetPlayerName()) then return true end

    -- Same-realm addon senders may omit the realm entirely.
    if not normalizedName:find("-", 1, true) then
        return normalizedName == NormalizeCharacterName(UnitName("player"))
    end
    return false
end

local function SendGuildMessage(message)
    if not IsInGuild() then return end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(MESSAGE_PREFIX, message, "GUILD")
    elseif SendAddonMessage then
        SendAddonMessage(MESSAGE_PREFIX, message, "GUILD")
    end
end

local function ToBase36(value)
    local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    value = math.min(math.max(0, math.floor(tonumber(value) or 0)), 9999999)
    if value == 0 then return "0" end
    local encoded = ""
    while value > 0 do
        local remainder = math.fmod(value, 36)
        encoded = digits:sub(remainder + 1, remainder + 1) .. encoded
        value = math.floor(value / 36)
    end
    return encoded
end

local function BuildMessageChunks(header, values)
    local messages = {}
    local current = header
    for _, value in ipairs(values) do
        local separator = current == header and "" or ","
        if #current + #separator + #value > 230 then
            table.insert(messages, current)
            current = header .. value
        else
            current = current .. separator .. value
        end
    end
    table.insert(messages, current)
    return messages
end

local function SerializeStats()
    local values = { "z=" .. ToBase36(HoppdebaeseDB.completedChallenges or 0) }
    for _, challenge in ipairs(ALL_CHALLENGES) do
        local amount = math.floor(tonumber(HoppdebaeseDB.stats[challenge.id]) or 0)
        if amount > 0 then
            table.insert(values, challenge.code .. "=" .. ToBase36(amount))
        end
    end
    return BuildMessageChunks("S|" .. HoppdebaeseDB.difficulty .. "|", values)
end

local function SerializeCompletionCounts()
    local values = {}
    for _, challenge in ipairs(ALL_CHALLENGES) do
        local count = math.floor(tonumber(HoppdebaeseDB.completionCounts[challenge.id]) or 0)
        if count > 0 then table.insert(values, challenge.code .. "=" .. ToBase36(count)) end
    end
    return BuildMessageChunks("C|", values)
end

local function BroadcastStats(force)
    local now = GetTime and GetTime() or 0
    if not force and addon.lastBroadcast and (now - addon.lastBroadcast) < 3 then return end
    addon.lastBroadcast = now
    for _, message in ipairs(SerializeStats()) do SendGuildMessage(message) end
    for _, message in ipairs(SerializeCompletionCounts()) do SendGuildMessage(message) end
end

local function EnsureGuildIdentity()
    local guildName = GetGuildInfo and GetGuildInfo("player") or nil
    if HoppdebaeseDB.guildName ~= guildName then
        HoppdebaeseDB.guildName = guildName
    end
end

local function RequestGuildStats(force)
    EnsureGuildIdentity()
    local now = GetTime and GetTime() or 0
    if not force and addon.lastRequest and (now - addon.lastRequest) < 10 then return end
    addon.lastRequest = now
    SendGuildMessage("Q|1")
    BroadcastStats(true)
end

local function StoreGuildStats(sender, message)
    if not sender or sender == "" then return end
    if IsCurrentPlayer(sender) then return end
    local difficulty, payload = message:match("^S|([^|]+)|(.*)$")
    if not difficulty or not DIFFICULTIES[difficulty] then return end

    local existing = HoppdebaeseDB.guildStats[sender]
    local stats = existing and existing.stats or {}
    local completed = existing and existing.completedChallenges or 0
    for pair in payload:gmatch("[^,]+") do
        local code, rawAmount = pair:match("^([%a]+)=([%da-z]+)$")
        local amount = math.min(tonumber(rawAmount, 36) or 0, 9999999)
        if code == "z" then
            completed = amount
        elseif CHALLENGE_BY_CODE[code] then
            stats[CHALLENGE_BY_CODE[code].id] = amount
        end
    end

    HoppdebaeseDB.guildStats[sender] = {
        difficulty = difficulty,
        completedChallenges = completed,
        stats = stats,
        completionCounts = existing and existing.completionCounts or {},
        updated = time and time() or 0,
    }
end

local function StoreGuildCompletionCounts(sender, message)
    if not sender or sender == "" then return end
    if IsCurrentPlayer(sender) then return end
    local payload = message:match("^C|(.*)$")
    if not payload then return end

    local existing = HoppdebaeseDB.guildStats[sender]
    local counts = existing and existing.completionCounts or {}
    for pair in payload:gmatch("[^,]+") do
        local code, rawCount = pair:match("^([%a]+)=([%da-z]+)$")
        local count = math.min(tonumber(rawCount, 36) or 0, 9999999)
        if CHALLENGE_BY_CODE[code] then counts[CHALLENGE_BY_CODE[code].id] = count end
    end

    local profile = existing or {
        difficulty = "medium",
        completedChallenges = 0,
        stats = {},
    }
    profile.completionCounts = counts
    profile.updated = time and time() or 0
    HoppdebaeseDB.guildStats[sender] = profile
end

local function CreditChallenge(challenge)
    if not challenge then return end
    HoppdebaeseDB.stats[challenge.id] = (HoppdebaeseDB.stats[challenge.id] or 0) + challenge.amount
    HoppdebaeseDB.completionCounts[challenge.id] = (HoppdebaeseDB.completionCounts[challenge.id] or 0) + 1
    HoppdebaeseDB.completedChallenges = (HoppdebaeseDB.completedChallenges or 0) + 1
    if DAILY_GOALS[challenge.id] then
        EnsureDailyState()
        local goal = GetDailyGoal(challenge.id)
        HoppdebaeseDB.daily.stats[challenge.id] = math.min(
            goal,
            (HoppdebaeseDB.daily.stats[challenge.id] or 0) + challenge.amount
        )
    end
    BroadcastStats(true)
    if addon.RefreshProgress then addon:RefreshProgress() end
end

local function RemoveTodo(todoID)
    for index, item in ipairs(HoppdebaeseDB.todo) do
        if item.todoID == todoID then
            table.remove(HoppdebaeseDB.todo, index)
            if addon.RefreshTodo then addon:RefreshTodo() end
            return true
        end
    end
    return false
end

local function CompleteTodo(todoID)
    for _, item in ipairs(HoppdebaeseDB.todo) do
        if item.todoID == todoID then
            CreditChallenge(item)
            if HoppdebaeseDB.announceCompletion and IsInGuild() and type(SendChatMessage) == "function" then
                SendChatMessage(string.format(
                    "Hoppdebäse completed from %s: %s - %s",
                    item.eventLabel or (TRIGGER_INFO[item.trigger] and TRIGGER_INFO[item.trigger].title) or "Workout Challenge",
                    item.text,
                    Pick(COMPLETION_QUOTES)
                ), "GUILD")
            end
            RemoveTodo(todoID)
            return
        end
    end
end

local function AddTodo(challenge)
    HoppdebaeseDB.nextTodoID = (HoppdebaeseDB.nextTodoID or 0) + 1
    local item = {
        todoID = HoppdebaeseDB.nextTodoID,
        id = challenge.id,
        code = challenge.code,
        name = challenge.name,
        text = challenge.text,
        amount = challenge.amount,
        unit = challenge.unit,
        icon = challenge.icon,
        trigger = addon.currentTrigger,
        eventLabel = addon.currentEventLabel,
        createdAt = time and time() or 0,
    }
    table.insert(HoppdebaeseDB.todo, item)
    addon.currentTodoID = item.todoID
    if addon.RefreshTodo then addon:RefreshTodo() end
end

local function AddBackdrop(frame, opacity)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.035, 0.045, 0.055, opacity or 0.96)
    frame:SetBackdropBorderColor(0.27, 0.72, 0.52, 1)
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 26)
    button:SetText(text)
    return button
end

local function AttachTooltip(frame, title, description)
    frame:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0.28)
        GameTooltip:AddLine(description, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function SaveWindowPosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    HoppdebaeseDB.window.point = point
    HoppdebaeseDB.window.relativePoint = relativePoint
    HoppdebaeseDB.window.x = x
    HoppdebaeseDB.window.y = y
    HoppdebaeseDB.window.width = frame:GetWidth()
    HoppdebaeseDB.window.height = frame:GetHeight()
end

local BOX_ROW_COUNT = 5
local BOX_CENTER_ROW = 3
local BOX_ROLL_DURATION = 4

local function SetBoxRowColor(row, challenge, selected)
    if not challenge or challenge.valueRatio == nil then
        row.background:SetVertexColor(0.08, 0.16, 0.18, selected and 0.95 or 0.72)
        return
    end

    local ratio = challenge.valueRatio
    local red, green, blue
    if ratio <= 0.5 then
        local blend = ratio * 2
        red = 0.10 + (0.45 * blend)
        green = 0.43 + (0.05 * blend)
        blue = 0.19 - (0.09 * blend)
    else
        local blend = (ratio - 0.5) * 2
        red = 0.55 + (0.08 * blend)
        green = 0.48 - (0.35 * blend)
        blue = 0.10
    end
    row.background:SetVertexColor(red, green, blue, selected and 0.96 or 0.72)
end

local function RefreshBoxRows()
    for index, row in ipairs(addon.boxRows or {}) do
        local challenge = addon.boxItems and addon.boxItems[index]
        row.text:SetText(challenge and challenge.text or "...")
        row.icon:SetTexture(challenge and challenge.icon or nil)
        SetBoxRowColor(row, challenge, index == BOX_CENTER_ROW)
    end
end

local function LayoutBox(frame)
    if not addon.boxVisual then return end
    local boxWidth = math.max(390, frame:GetWidth() - 70)
    local boxHeight = math.max(226, frame:GetHeight() - 150)
    local gap = 4
    local rowHeight = math.floor((boxHeight - ((BOX_ROW_COUNT - 1) * gap)) / BOX_ROW_COUNT)
    local iconSize = math.max(28, math.min(44, rowHeight - 8))

    addon.boxVisual:SetSize(boxWidth, boxHeight)
    for index, row in ipairs(addon.boxRows or {}) do
        row:SetSize(boxWidth, rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOP", 0, -((index - 1) * (rowHeight + gap)))
        row.icon:SetSize(iconSize, iconSize)
    end
end

local function FillBoxItems()
    addon.boxItems = {}
    for index = 1, BOX_ROW_COUNT do
        addon.boxItems[index] = RollChallenge(addon.currentTrigger)
    end
    RefreshBoxRows()
end

local function AdvanceBox()
    table.remove(addon.boxItems, 1)
    table.insert(addon.boxItems, RollChallenge(addon.currentTrigger))
    RefreshBoxRows()
end

local function StopBoxRoll()
    addon.rolling = false
    addon.rollElapsed = 0
    addon.rollStepElapsed = 0
    addon.currentChallenge = addon.boxItems[BOX_CENTER_ROW]
    local challengeDefinition = CHALLENGE_BY_ID[addon.currentChallenge.id]
    if challengeDefinition and challengeDefinition.cooldown then
        HoppdebaeseDB.promptCooldowns[addon.currentChallenge.id] = time and time() or 0
    end
    AddTodo(addon.currentChallenge)
    addon.todoFrame:Show()
    addon.todoFrame:Raise()
    if HoppdebaeseDB.announceGuild and IsInGuild() and type(SendChatMessage) == "function" then
        SendChatMessage(string.format(
            "Hoppdebäse challenge from %s: %s",
            addon.currentEventLabel or "Workout Challenge",
            addon.currentChallenge.text
        ), "GUILD")
    end
    addon.debugRollButton:Enable()
    addon.swapButton:Enable()
    addon.minimizeButton:Enable()
end

local function StartBoxRoll(delay)
    if addon.rolling then return end
    addon.rolling = true
    addon.rollDelay = delay or 0
    addon.rollElapsed = 0
    addon.rollStepElapsed = 0
    addon.currentChallenge = nil
    FillBoxItems()
    addon.debugRollButton:Disable()
    addon.swapButton:Disable()
    addon.minimizeButton:Disable()
end

local function CreateBoxVisual(parent)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(390, 226)
    box:SetPoint("TOP", 0, -68)
    addon.boxVisual = box
    addon.boxRows = {}

    for index = 1, BOX_ROW_COUNT do
        local row = CreateFrame("Frame", nil, box)
        row:SetSize(390, 40)
        row:SetPoint("TOP", 0, -((index - 1) * 44))

        local background = row:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetTexture("Interface\\Buttons\\WHITE8X8")
        background:SetVertexColor(0.07, 0.09, 0.10, 0.75)
        row.background = background

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("LEFT", 6, 0)
        row.icon = icon

        local text = row:CreateFontString(nil, "OVERLAY", index == BOX_CENTER_ROW and "GameFontNormalLarge" or "GameFontHighlight")
        text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
        text:SetPoint("RIGHT", -8, 0)
        text:SetJustifyH("LEFT")
        if index == BOX_CENTER_ROW then text:SetTextColor(1, 0.82, 0.28) end
        row.text = text

        if index == BOX_CENTER_ROW then
            local function CreateGlowEdge(pointA, pointB, width, height)
                local edge = row:CreateTexture(nil, "OVERLAY")
                edge:SetTexture("Interface\\Buttons\\WHITE8X8")
                edge:SetBlendMode("ADD")
                edge:SetVertexColor(1, 0.68, 0.12, 0.92)
                edge:SetPoint(pointA, row, pointA)
                edge:SetPoint(pointB, row, pointB)
                if width then edge:SetWidth(width) end
                if height then edge:SetHeight(height) end
                return edge
            end
            CreateGlowEdge("TOPLEFT", "TOPRIGHT", nil, 3)
            CreateGlowEdge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 3)
            CreateGlowEdge("TOPLEFT", "BOTTOMLEFT", 3, nil)
            CreateGlowEdge("TOPRIGHT", "BOTTOMRIGHT", 3, nil)
        end
        addon.boxRows[index] = row
    end

    local selected = box:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    selected:SetPoint("RIGHT", box, "LEFT", -3, 0)
    selected:SetText(">>")
    selected:SetTextColor(1, 0.82, 0.28)
    LayoutBox(parent)
end

local function CreateMainWindow()
    local frame = CreateFrame("Frame", "HoppdebaeseBoxFrame", UIParent, BACKDROP_TEMPLATE)
    frame:SetSize(math.max(HoppdebaeseDB.window.width, 460), math.max(HoppdebaeseDB.window.height, 400))
    frame:SetPoint(
        HoppdebaeseDB.window.point,
        UIParent,
        HoppdebaeseDB.window.relativePoint,
        HoppdebaeseDB.window.x,
        HoppdebaeseDB.window.y
    )
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(460, 400)
    else
        frame:SetMinResize(460, 400)
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition(self)
    end)
    frame:SetScript("OnSizeChanged", function(self)
        if HoppdebaeseDB then
            HoppdebaeseDB.window.width = self:GetWidth()
            HoppdebaeseDB.window.height = self:GetHeight()
        end
        LayoutBox(self)
    end)
    AddBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -22)
    title:SetTextColor(0.38, 0.95, 0.68)
    addon.titleText = title

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -7)
    subtitle:SetText("A brief break for your next bit of progress")

    CreateBoxVisual(frame)

    local debugRoll = CreateButton(frame, "Debug: Roll Box", 130)
    debugRoll:SetPoint("BOTTOMLEFT", 20, 24)
    debugRoll:SetScript("OnClick", function() StartBoxRoll(0) end)
    addon.debugRollButton = debugRoll

    local swap = CreateButton(frame, "Replace Exercise (Session)", 174)
    swap:SetPoint("LEFT", debugRoll, "RIGHT", 8, 0)
    swap:SetScript("OnClick", function()
        local previousID = addon.currentChallenge and addon.currentChallenge.id
        if addon.currentTodoID then RemoveTodo(addon.currentTodoID) end
        addon.currentTodoID = nil
        if previousID and DAILY_GOALS[previousID] then
            addon.sessionDisabled[previousID] = true
            if addon.RefreshRested then addon:RefreshRested() end
        end
        StartBoxRoll(0.15)
    end)
    AttachTooltip(
        swap,
        "Replace Exercise for This Session",
        "Replaces the current challenge and prevents that exercise from rolling again until you relog. Restore it from Rested Exercises."
    )
    addon.swapButton = swap

    local minimize = CreateButton(frame, "Minimize", 100)
    minimize:SetPoint("BOTTOMRIGHT", -20, 24)
    minimize:SetScript("OnClick", function() frame:Hide() end)
    addon.minimizeButton = minimize

    local settings = CreateButton(frame, "Settings", 76)
    settings:SetPoint("TOPRIGHT", -14, -14)
    settings:SetScript("OnClick", function() addon.settingsFrame:Show() end)

    local leaderboard = CreateButton(frame, "Leaderboard", 96)
    leaderboard:SetPoint("TOPLEFT", 14, -14)
    leaderboard:SetScript("OnClick", function() addon.leaderboardFrame:Show() end)

    local todo = CreateButton(frame, "Todo", 72)
    todo:SetPoint("LEFT", leaderboard, "RIGHT", 8, 0)
    todo:SetScript("OnClick", function() addon.todoFrame:Show() end)
    addon.todoButton = todo

    local rested = CreateButton(frame, "Rested", 82)
    rested:SetPoint("LEFT", todo, "RIGHT", 8, 0)
    rested:SetScript("OnClick", function() addon.restedFrame:Show() end)
    addon.restedButton = rested

    local progress = CreateButton(frame, "Progress", 80)
    progress:SetPoint("TOPLEFT", 14, -44)
    progress:SetScript("OnClick", function() addon.progressFrame:Show() end)

    local help = CreateButton(frame, "?", 28)
    help:SetPoint("RIGHT", settings, "LEFT", -6, 0)
    help:SetScript("OnClick", function() addon.helpFrame:Show() end)
    AttachTooltip(help, "Hoppdebäse Help", "Open button, exercise, and settings details.")

    local resize = CreateFrame("Button", nil, frame)
    resize:SetSize(20, 20)
    resize:SetPoint("BOTTOMRIGHT", -3, 3)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SaveWindowPosition(frame)
    end)

    frame:SetScript("OnUpdate", function(_, elapsed)
        if not addon.rolling then return end
        if addon.rollDelay > 0 then
            addon.rollDelay = addon.rollDelay - elapsed
            if addon.rollDelay > 0 then return end
            elapsed = -addon.rollDelay
            addon.rollDelay = 0
        end

        addon.rollElapsed = addon.rollElapsed + elapsed
        addon.rollStepElapsed = addon.rollStepElapsed + elapsed
        local progress = math.min(addon.rollElapsed / BOX_ROLL_DURATION, 1)
        local stepInterval = 0.030 + (progress * progress * progress * progress * 0.62)
        while addon.rollStepElapsed >= stepInterval do
            addon.rollStepElapsed = addon.rollStepElapsed - stepInterval
            AdvanceBox()
        end
        if addon.rollElapsed >= BOX_ROLL_DURATION then StopBoxRoll() end
    end)
    frame:Hide()
    addon.mainFrame = frame
end

local function CreateCheckButton(parent, text, x, y, getter, setter)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y)
    check:SetSize(24, 24)
    local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 3, 0)
    label:SetText(text)
    check:SetScript("OnShow", function(self) self:SetChecked(getter()) end)
    check:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    return check
end

local function GetShortName(name)
    if Ambiguate then return Ambiguate(name, "short") end
    return (name or "Unknown"):match("^[^-]+") or name
end

local function BuildLeaderboardText()
    local playerName = GetPlayerName()
    local participants = {
        {
            name = playerName,
            difficulty = HoppdebaeseDB.difficulty,
            completedChallenges = HoppdebaeseDB.completedChallenges or 0,
            stats = HoppdebaeseDB.stats,
            completionCounts = HoppdebaeseDB.completionCounts,
            isPlayer = true,
        },
    }

    for name, profile in pairs(HoppdebaeseDB.guildStats) do
        if not IsCurrentPlayer(name) and type(profile) == "table" and type(profile.stats) == "table" then
            table.insert(participants, {
                name = name,
                difficulty = profile.difficulty,
                completedChallenges = profile.completedChallenges or 0,
                stats = profile.stats,
                completionCounts = profile.completionCounts or {},
            })
        end
    end

    table.sort(participants, function(left, right)
        if left.completedChallenges == right.completedChallenges then return left.name < right.name end
        return left.completedChallenges > right.completedChallenges
    end)

    local lines = {}
    for rank, profile in ipairs(participants) do
        local difficulty = DIFFICULTIES[profile.difficulty] or DIFFICULTIES.medium
        local playerSuffix = profile.isPlayer and " |cff61f2ad(you)|r" or ""
        table.insert(lines, string.format(
            "|cffffc74d%d.|r |cffffffff%s|r%s  -  %d challenges  [%s]",
            rank,
            GetShortName(profile.name),
            playerSuffix,
            profile.completedChallenges,
            difficulty.label
        ))

        local totals = {}
        for _, challenge in ipairs(ALL_CHALLENGES) do
            local amount = tonumber(profile.stats[challenge.id]) or 0
            local count = profile.completionCounts and tonumber(profile.completionCounts[challenge.id]) or 0
            if amount > 0 then
                table.insert(totals, string.format(
                    "%s: %d %s (%dx)",
                    challenge.name,
                    amount,
                    challenge.unit,
                    count
                ))
            end
        end
        if #totals == 0 then
            table.insert(lines, "|cff999999  No completed workouts yet.|r")
        else
            table.insert(lines, "|cffc7d2cc  " .. table.concat(totals, "  |  ") .. "|r")
        end
        table.insert(lines, " ")
    end
    return table.concat(lines, "\n")
end

local function RefreshLeaderboard(requestUpdate)
    if requestUpdate then RequestGuildStats(true) end
    if not addon.leaderboardText then return end
    addon.leaderboardText:SetText(BuildLeaderboardText())
    addon.leaderboardContent:SetHeight(math.max(1, addon.leaderboardText:GetStringHeight() + 16))
end

local function CreateLeaderboardWindow()
    local frame = CreateFrame("Frame", "HoppdebaeseLeaderboard", UIParent, BACKDROP_TEMPLATE)
    frame:SetSize(650, 500)
    frame:SetPoint("CENTER", 50, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    AddBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -20)
    title:SetText("Hoppdebäse Guild Leaderboard")
    title:SetTextColor(0.38, 0.95, 0.68)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetText("Guild members appear after their addon answers a refresh request.")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -62)
    scroll:SetPoint("BOTTOMRIGHT", -42, 58)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(575, 1)
    scroll:SetScrollChild(content)
    addon.leaderboardContent = content

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 4, -4)
    text:SetWidth(555)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    addon.leaderboardText = text

    local refresh = CreateButton(frame, "Refresh Guild", 120)
    refresh:SetPoint("BOTTOMLEFT", 22, 20)
    refresh:SetScript("OnClick", function() RefreshLeaderboard(true) end)

    local exerciseLeaders = CreateButton(frame, "Exercise Top 3", 130)
    exerciseLeaders:SetPoint("BOTTOM", 0, 20)
    exerciseLeaders:SetScript("OnClick", function() addon.exerciseLeaderboardFrame:Show() end)

    local close = CreateButton(frame, "Close", 100)
    close:SetPoint("BOTTOMRIGHT", -22, 20)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnShow", function() RefreshLeaderboard(true) end)
    frame:Hide()
    addon.leaderboardFrame = frame
end

local function BuildExerciseLeaderboardText()
    local participants = {
        {
            name = GetPlayerName(),
            stats = HoppdebaeseDB.stats,
            isPlayer = true,
        },
    }
    for name, profile in pairs(HoppdebaeseDB.guildStats) do
        if not IsCurrentPlayer(name) and type(profile) == "table" and type(profile.stats) == "table" then
            table.insert(participants, { name = name, stats = profile.stats })
        end
    end

    local lines = {}
    for _, exercise in ipairs(EXERCISES) do
        local leaders = {}
        local total = 0
        for _, participant in ipairs(participants) do
            local amount = tonumber(participant.stats[exercise.id]) or 0
            total = total + amount
            if amount > 0 then
                table.insert(leaders, {
                    name = participant.name,
                    amount = amount,
                    isPlayer = participant.isPlayer,
                })
            end
        end
        table.sort(leaders, function(left, right)
            if left.amount == right.amount then return left.name < right.name end
            return left.amount > right.amount
        end)

        table.insert(lines, string.format(
            "|cffffc74d%s|r  |cff8ee6bcTotal: %d %s|r",
            exercise.name,
            total,
            exercise.unit
        ))
        if #leaders == 0 then
            table.insert(lines, "|cff888888  No guild progress yet.|r")
        else
            for rank = 1, math.min(3, #leaders) do
                local leader = leaders[rank]
                local suffix = leader.isPlayer and " |cff61f2ad(you)|r" or ""
                table.insert(lines, string.format(
                    "  %d. %s%s - %d %s",
                    rank,
                    GetShortName(leader.name),
                    suffix,
                    leader.amount,
                    exercise.unit
                ))
            end
        end
        table.insert(lines, " ")
    end
    return table.concat(lines, "\n")
end

local function RefreshExerciseLeaderboard(requestUpdate)
    if requestUpdate then RequestGuildStats(true) end
    if not addon.exerciseLeaderboardText then return end
    addon.exerciseLeaderboardText:SetText(BuildExerciseLeaderboardText())
    addon.exerciseLeaderboardContent:SetHeight(math.max(1, addon.exerciseLeaderboardText:GetStringHeight() + 16))
end

local function CreateExerciseLeaderboardWindow()
    local frame = CreateFrame("Frame", "HoppdebaeseExerciseLeaderboard", UIParent, BACKDROP_TEMPLATE)
    frame:SetSize(610, 580)
    frame:SetPoint("CENTER", 75, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    AddBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -20)
    title:SetText("Guild Exercise Top 3")
    title:SetTextColor(0.38, 0.95, 0.68)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetText("Top contributors and combined guild total for every exercise.")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -62)
    scroll:SetPoint("BOTTOMRIGHT", -42, 58)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(535, 1)
    scroll:SetScrollChild(content)
    addon.exerciseLeaderboardContent = content

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 4, -4)
    text:SetWidth(515)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    addon.exerciseLeaderboardText = text

    local refresh = CreateButton(frame, "Refresh Guild", 120)
    refresh:SetPoint("BOTTOMLEFT", 22, 20)
    refresh:SetScript("OnClick", function() RefreshExerciseLeaderboard(true) end)

    local close = CreateButton(frame, "Close", 100)
    close:SetPoint("BOTTOMRIGHT", -22, 20)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnShow", function() RefreshExerciseLeaderboard(true) end)
    frame:Hide()
    addon.exerciseLeaderboardFrame = frame
end

local function CreateMinimapButton()
    if not Minimap then return end
    local button = CreateFrame("Button", "HoppdebaeseMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -2, -18)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetAllPoints()

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICONS.weights)
    icon:SetPoint("TOPLEFT", 6, -6)
    icon:SetPoint("BOTTOMRIGHT", -6, 6)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    border:SetSize(54, 54)

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            addon.settingsFrame:Show()
        elseif IsShiftKeyDown and IsShiftKeyDown() then
            addon.leaderboardFrame:Show()
        else
            addon.todoFrame:Show()
        end
    end)
    AttachTooltip(
        button,
        "Hoppdebäse",
        "Left-click: Todo\nShift-left-click: Guild leaderboard\nRight-click: Settings"
    )
    addon.minimapButton = button
end

local function CreateTodoWindow()
    local frame = CreateFrame("Frame", "HoppdebaeseTodo", UIParent, BACKDROP_TEMPLATE)
    frame:SetSize(math.max(HoppdebaeseDB.todoWindow.width, 240), math.max(HoppdebaeseDB.todoWindow.height, 110))
    frame:SetPoint(
        HoppdebaeseDB.todoWindow.point,
        UIParent,
        HoppdebaeseDB.todoWindow.relativePoint,
        HoppdebaeseDB.todoWindow.x,
        HoppdebaeseDB.todoWindow.y
    )
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(240, 110)
    else
        frame:SetMinResize(240, 110)
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        HoppdebaeseDB.todoWindow.point = point
        HoppdebaeseDB.todoWindow.relativePoint = relativePoint
        HoppdebaeseDB.todoWindow.x = x
        HoppdebaeseDB.todoWindow.y = y
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.02, 0.10, 0.075, 0.38)
    frame:SetBackdropBorderColor(0.27, 0.72, 0.52, 0.72)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -11)
    title:SetText("Hoppdebäse Todo")
    title:SetTextColor(0.38, 0.95, 0.68)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("LEFT", title, "RIGHT", 8, 0)
    addon.todoSubtitle = subtitle

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 9, -34)
    scroll:SetPoint("BOTTOMRIGHT", -28, 12)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(485, 1)
    scroll:SetScrollChild(content)
    addon.todoContent = content
    addon.todoRows = {}

    local function LayoutTodo()
        local contentWidth = math.max(205, frame:GetWidth() - 42)
        content:SetWidth(contentWidth)
        for _, row in ipairs(addon.todoRows) do row:SetWidth(contentWidth - 5) end
    end

    function addon:RefreshTodo()
        if not self.todoRows then return end
        for _, row in ipairs(self.todoRows) do row:Hide() end

        for index, item in ipairs(HoppdebaeseDB.todo) do
            local row = self.todoRows[index]
            if not row then
                row = CreateFrame("Frame", nil, self.todoContent)
                row:SetSize(math.max(200, self.todoContent:GetWidth() - 5), 30)

                local background = row:CreateTexture(nil, "BACKGROUND")
                background:SetAllPoints()
                background:SetTexture("Interface\\Buttons\\WHITE8X8")
                background:SetVertexColor(0.08, 0.22, 0.17, 0.22)

                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(24, 24)
                row.icon:SetPoint("LEFT", 3, 0)

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
                row.text:SetPoint("RIGHT", -72, 0)
                row.text:SetJustifyH("LEFT")

                row.complete = CreateButton(row, "Complete", 66)
                row.complete:SetSize(66, 22)
                row.complete:SetPoint("RIGHT", -2, 0)
                row.complete:SetScript("OnClick", function(button) CompleteTodo(button.todoID) end)
                self.todoRows[index] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 1, -((index - 1) * 32))
            row.icon:SetTexture(item.icon)
            row.text:SetText(item.text)
            row.complete.todoID = item.todoID
            row:Show()
        end

        local count = #HoppdebaeseDB.todo
        self.todoContent:SetHeight(math.max(1, count * 32))
        self.todoSubtitle:SetText("(" .. count .. ")")
        if self.todoButton then self.todoButton:SetText("Todo (" .. count .. ")") end
    end

    local close = CreateButton(frame, "X", 24)
    close:SetSize(24, 20)
    close:SetPoint("TOPRIGHT", -7, -7)
    close:SetScript("OnClick", function() frame:Hide() end)

    local resize = CreateFrame("Button", nil, frame)
    resize:SetSize(20, 20)
    resize:SetPoint("BOTTOMRIGHT", -3, 3)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        HoppdebaeseDB.todoWindow.width = frame:GetWidth()
        HoppdebaeseDB.todoWindow.height = frame:GetHeight()
    end)

    frame:SetScript("OnSizeChanged", function(self)
        HoppdebaeseDB.todoWindow.width = self:GetWidth()
        HoppdebaeseDB.todoWindow.height = self:GetHeight()
        LayoutTodo()
    end)

    frame:SetScript("OnShow", function() addon:RefreshTodo() end)
    LayoutTodo()
    frame:Hide()
    addon.todoFrame = frame
end

local function CreateRestedWindow()
    local frame = CreateFrame("Frame", "HoppdebaeseRested", UIParent, BACKDROP_TEMPLATE)
    frame:SetSize(520, 430)
    frame:SetPoint("CENTER", 10, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    AddBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -20)
    title:SetText("Rested Exercises")
    title:SetTextColor(0.38, 0.95, 0.68)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    addon.restedSubtitle = subtitle

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -62)
    scroll:SetPoint("BOTTOMRIGHT", -42, 58)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(445, 1)
    scroll:SetScrollChild(content)
    addon.restedContent = content
    addon.restedRows = {}

    function addon:RefreshRested()
        if not self.restedRows then return end
        for _, row in ipairs(self.restedRows) do row:Hide() end

        local rested = {}
        for _, exercise in ipairs(EXERCISES) do
            if self.sessionDisabled[exercise.id] then table.insert(rested, exercise) end
        end

        for index, exercise in ipairs(rested) do
            local row = self.restedRows[index]
            if not row then
                row = CreateFrame("Frame", nil, self.restedContent)
                row:SetSize(440, 50)

                local background = row:CreateTexture(nil, "BACKGROUND")
                background:SetAllPoints()
                background:SetTexture("Interface\\Buttons\\WHITE8X8")
                background:SetVertexColor(0.07, 0.11, 0.12, 0.85)

                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(38, 38)
                row.icon:SetPoint("LEFT", 6, 0)

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.text:SetPoint("LEFT", row.icon, "RIGHT", 9, 0)
                row.text:SetPoint("RIGHT", -102, 0)
                row.text:SetJustifyH("LEFT")

                row.restore = CreateButton(row, "Restore", 84)
                row.restore:SetPoint("RIGHT", -7, 0)
                row.restore:SetScript("OnClick", function(button)
                    addon.sessionDisabled[button.exerciseID] = nil
                    addon:RefreshRested()
                    if addon.RefreshProgress then addon:RefreshProgress() end
                end)
                self.restedRows[index] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 2, -((index - 1) * 54))
            row.icon:SetTexture(exercise.icon)
            row.text:SetText(exercise.name)
            row.restore.exerciseID = exercise.id
            row:Show()
        end

        local count = #rested
        self.restedContent:SetHeight(math.max(1, count * 54))
        if count == 0 then
            self.restedSubtitle:SetText("No exercises are excluded for this login session.")
        else
            self.restedSubtitle:SetText(count == 1 and "1 exercise excluded until relogging" or (count .. " exercises excluded until relogging"))
        end
        if self.restedButton then self.restedButton:SetText("Rested (" .. count .. ")") end
    end

    local close = CreateButton(frame, "Close", 100)
    close:SetPoint("BOTTOMRIGHT", -22, 20)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnShow", function() addon:RefreshRested() end)
    frame:Hide()
    addon.restedFrame = frame
end

local function BuildHelpText()
    local lines = {
        "|cffffc74dCHALLENGE BOX BUTTONS|r",
        "|cffffffffDebug: Roll Box|r - Starts a manual test roll.",
        "|cffffffffReplace Exercise (Session)|r - Replaces the current Todo challenge and excludes that physical exercise until you relog. Use Rested to undo it.",
        "|cffffffffMinimize|r - Hides the challenge box without removing its Todo entry.",
        "|cffffffffTodo|r - Opens automatically after a roll and lists pending challenges. It can be resized and left open; Complete credits progress.",
        "|cffffffffRested|r - Lists exercises excluded for this login session. Restore makes one available again.",
        "|cffffffffProgress|r - Shows daily caps, session-rested status, and all-time totals.",
        "|cffffffffLeaderboard|r - Requests and displays participating guild members' totals.",
        "|cffffffffExercise Top 3|r - Shows the top three guild contributors and combined total for every exercise.",
        "|cffffffffSettings|r - Opens difficulty, trigger, sharing, and equipment options.",
        "|cffffffff?|r - Opens this reference.",
        "|cffffffffMinimap icon|r - Left-click Todo, Shift-left-click guild leaderboard, and right-click Settings.",
        "|cffffffffRefresh Guild|r - Requests current leaderboard data from online guild members using the addon.",
        "|cffffffffComplete|r - Finishes a Todo challenge, credits its progress, and removes it from Todo.",
        "|cffffffffRestore|r - Removes an exercise from the session-rested list so it can roll again.",
        "|cffffffffClose / Done|r - Closes the current secondary window without changing pending challenges.",
        " ",
        "|cffffc74dSETTINGS|r",
        "|cffffffffDifficulty|r - Easy uses 0.7x amounts, Medium 1x, Hard 1.5x, and Extreme 3x. Daily goals scale separately; Extreme is twice Hard.",
        "|cffffffffPlayer level-up|r - Rolls when your character gains a level.",
        "|cffffffffPlayer death|r - Rolls after death with a 1.35x event multiplier.",
        "|cffffffffFlight path starts|r - Rolls when selecting a taxi, using a lighter 0.75x multiplier.",
        "|cffffffffDungeon completion|r - Rolls for supported dungeon-completion events with a 1.2x multiplier.",
        "|cffffffffQuest interval|r - Choose a challenge every 3 to 15 completed quests; the default is 10.",
        "|cffffffffEvery 10 profession skill points|r - Rolls from a mix of wellness breaks and Easy exercises for all profession slots.",
        "|cffffffffRoll announcement|r - Posts the selected challenge and originating event to guild chat.",
        "|cffffffffCompletion announcement|r - Posts the completed challenge, event, and a random Swiss-German message.",
        "|cffffffffWorkout bench|r - Enables bench presses and helps unlock seated shoulder presses.",
        "|cffffffffPull-up bar|r - Enables pull-ups and dead hangs.",
        "|cffffffffDumbbells|r - Enables curls, rows, raises, triceps extensions, and dumbbell presses.",
        "|cffffffffTreadmill|r - Enables timed treadmill walks and runs.",
        "|cffffffffTest Box|r - Closes Settings and starts a manual roll.",
        " ",
        "|cffffc74dEXERCISES AND BREAKS|r",
    }

    local toolNames = {
        bench = "a workout bench",
        pullupBar = "a pull-up bar",
        dumbbells = "dumbbells",
        treadmill = "a treadmill",
    }

    for _, challenge in ipairs(ALL_CHALLENGES) do
        local equipment = ""
        if challenge.tool then
            equipment = " Requires " .. (toolNames[challenge.tool] or challenge.tool) .. "."
        elseif challenge.tools then
            local names = {}
            for _, tool in ipairs(challenge.tools) do
                table.insert(names, toolNames[tool] or tool)
            end
            equipment = " Requires " .. table.concat(names, " and ") .. "."
        end
        table.insert(lines, string.format(
            "|cffffffff%s|r - %s%s",
            challenge.name,
            CHALLENGE_DESCRIPTIONS[challenge.id] or "Follow the displayed amount with controlled form.",
            equipment
        ))
    end

    return table.concat(lines, "\n")
end

local function CreateHelpWindow()
    local frame = CreateFrame("Frame", "HoppdebaeseHelp", UIParent, BACKDROP_TEMPLATE)
    frame:SetSize(720, 600)
    frame:SetPoint("CENTER", -20, 10)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    AddBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -20)
    title:SetText("Hoppdebäse Help")
    title:SetTextColor(0.38, 0.95, 0.68)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -54)
    scroll:SetPoint("BOTTOMRIGHT", -42, 58)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(645, 1)
    scroll:SetScrollChild(content)

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 4, -4)
    text:SetWidth(625)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetText(BuildHelpText())
    content:SetHeight(math.max(1, text:GetStringHeight() + 16))

    local close = CreateButton(frame, "Close", 100)
    close:SetPoint("BOTTOMRIGHT", -22, 20)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:Hide()
    addon.helpFrame = frame
end

local function CreateProgressWindow()
    local frame = CreateFrame("Frame", "HoppdebaeseProgress", UIParent, BACKDROP_TEMPLATE)
    frame:SetSize(690, 590)
    frame:SetPoint("CENTER", -35, 10)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    AddBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -20)
    title:SetText("Daily Goals & All-Time Overview")
    title:SetTextColor(0.38, 0.95, 0.68)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    addon.progressSubtitle = subtitle

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -62)
    scroll:SetPoint("BOTTOMRIGHT", -42, 58)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(615, (#ALL_CHALLENGES * 48) + 10)
    scroll:SetScrollChild(content)
    addon.progressRows = {}

    for index, challenge in ipairs(ALL_CHALLENGES) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(600, 44)
        row:SetPoint("TOPLEFT", 4, -((index - 1) * 48))

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("TOPLEFT", 2, -2)
        name:SetText(challenge.name)

        local total = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        total:SetPoint("TOPRIGHT", -2, -3)
        total:SetJustifyH("RIGHT")

        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetPoint("BOTTOMLEFT", 2, 2)
        bar:SetPoint("BOTTOMRIGHT", -2, 2)
        bar:SetHeight(18)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

        local background = bar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetTexture("Interface\\Buttons\\WHITE8X8")
        background:SetVertexColor(0.08, 0.11, 0.10, 0.9)

        local value = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        value:SetPoint("CENTER")

        addon.progressRows[challenge.id] = {
            bar = bar,
            total = total,
            value = value,
        }
    end

    function addon:RefreshProgress()
        EnsureDailyState()
        local difficulty = DIFFICULTIES[HoppdebaeseDB.difficulty] or DIFFICULTIES.medium
        self.progressSubtitle:SetText(string.format(
            "%s difficulty  |  Daily goals reset each calendar day",
            difficulty.label
        ))

        for _, challenge in ipairs(ALL_CHALLENGES) do
            local row = self.progressRows[challenge.id]
            local allTimeAmount = tonumber(HoppdebaeseDB.stats[challenge.id]) or 0
            local completions = tonumber(HoppdebaeseDB.completionCounts[challenge.id]) or 0
            row.total:SetText(string.format(
                "All time: %d %s  |  %d challenges",
                allTimeAmount,
                challenge.unit,
                completions
            ))

            local goal = GetDailyGoal(challenge.id)
            if goal then
                local amount = GetDailyAmount(challenge.id)
                row.bar:SetMinMaxValues(0, goal)
                row.bar:SetValue(math.min(amount, goal))
                if amount >= goal then
                    row.bar:SetStatusBarColor(0.25, 0.72, 0.42)
                    row.value:SetText(string.format("%d / %d %s - goal complete, rest today", amount, goal, challenge.unit))
                elseif self.sessionDisabled[challenge.id] then
                    row.bar:SetStatusBarColor(0.48, 0.52, 0.50)
                    row.value:SetText(string.format("%d / %d %s - resting this session", amount, goal, challenge.unit))
                else
                    row.bar:SetStatusBarColor(0.88, 0.58, 0.16)
                    row.value:SetText(string.format("%d / %d %s", amount, goal, challenge.unit))
                end
            else
                row.bar:SetMinMaxValues(0, 1)
                row.bar:SetValue(1)
                row.bar:SetStatusBarColor(0.20, 0.48, 0.62)
                row.value:SetText("Wellness prompt - no daily cap")
            end
        end
    end

    local close = CreateButton(frame, "Close", 100)
    close:SetPoint("BOTTOMRIGHT", -22, 20)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnShow", function() addon:RefreshProgress() end)
    frame:Hide()
    addon.progressFrame = frame
end

local function CreateSettingsWindow()
    local frame = CreateFrame("Frame", "HoppdebaeseSettings", UIParent, BACKDROP_TEMPLATE)
    frame:SetSize(420, 670)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    AddBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -20)
    title:SetText("Hoppdebäse Settings")
    title:SetTextColor(0.38, 0.95, 0.68)

    local difficultyTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    difficultyTitle:SetPoint("TOPLEFT", 24, -58)
    difficultyTitle:SetText("Workout difficulty")

    addon.difficultyButtons = {}
    local function RefreshDifficultyButtons()
        for key, button in pairs(addon.difficultyButtons) do
            if key == HoppdebaeseDB.difficulty then button:Disable() else button:Enable() end
        end
    end
    for index, key in ipairs({ "easy", "medium", "hard", "extreme" }) do
        local difficultyKey = key
        local button = CreateButton(frame, DIFFICULTIES[key].label, 84)
        button:SetPoint("TOPLEFT", 24 + ((index - 1) * 92), -78)
        button:SetScript("OnClick", function()
            HoppdebaeseDB.difficulty = difficultyKey
            RefreshDifficultyButtons()
            BroadcastStats(true)
            if addon.RefreshProgress then addon:RefreshProgress() end
        end)
        addon.difficultyButtons[key] = button
    end
    frame:HookScript("OnShow", RefreshDifficultyButtons)

    local triggerTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    triggerTitle:SetPoint("TOPLEFT", 24, -122)
    triggerTitle:SetText("Challenge triggers")

    local triggers = {
        { key = "levelUp", text = "Player level-up" },
        { key = "death", text = "Player death (harder)" },
        { key = "flight", text = "Flight path starts (easier)" },
        { key = "dungeon", text = "Dungeon completion" },
        { key = "quests", text = "Quest completion interval" },
        { key = "professions", text = "Every 10 profession skill points" },
    }
    for index, info in ipairs(triggers) do
        local triggerKey = info.key
        CreateCheckButton(frame, info.text, 22, -136 - ((index - 1) * 30),
            function() return HoppdebaeseDB.triggers[triggerKey] end,
            function(value) HoppdebaeseDB.triggers[triggerKey] = value end)
    end

    local questSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    questSlider:SetPoint("TOPLEFT", 42, -316)
    questSlider:SetSize(250, 18)
    questSlider:SetMinMaxValues(3, 15)
    questSlider:SetValueStep(1)
    if questSlider.SetObeyStepOnDrag then questSlider:SetObeyStepOnDrag(true) end

    local questSliderText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    questSliderText:SetPoint("LEFT", questSlider, "RIGHT", 12, 0)
    questSlider:SetScript("OnValueChanged", function(_, value)
        value = math.max(3, math.min(15, math.floor(value + 0.5)))
        HoppdebaeseDB.questInterval = value
        questSliderText:SetText(value .. " quests")
    end)
    frame:HookScript("OnShow", function()
        local interval = math.max(3, math.min(15, tonumber(HoppdebaeseDB.questInterval) or 10))
        questSlider:SetValue(interval)
        questSliderText:SetText(interval .. " quests")
    end)
    addon.questSlider = questSlider

    local sharingTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sharingTitle:SetPoint("TOPLEFT", 24, -360)
    sharingTitle:SetText("Sharing")

    CreateCheckButton(frame, "Announce rolled challenge in guild chat", 22, -374,
        function() return HoppdebaeseDB.announceGuild end,
        function(value) HoppdebaeseDB.announceGuild = value end)

    CreateCheckButton(frame, "Announce completed challenge in guild chat", 22, -404,
        function() return HoppdebaeseDB.announceCompletion end,
        function(value) HoppdebaeseDB.announceCompletion = value end)

    local toolsTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toolsTitle:SetPoint("TOPLEFT", 24, -446)
    toolsTitle:SetText("Equipment available at home")

    for index, info in ipairs(TOOL_LABELS) do
        local toolKey = info.key
        CreateCheckButton(frame, info.text, 22, -460 - ((index - 1) * 30),
            function() return HoppdebaeseDB.tools[toolKey] end,
            function(value) HoppdebaeseDB.tools[toolKey] = value end)
    end

    local close = CreateButton(frame, "Done", 100)
    close:SetPoint("BOTTOMRIGHT", -20, 18)
    close:SetScript("OnClick", function() frame:Hide() end)

    local test = CreateButton(frame, "Test Box", 110)
    test:SetPoint("BOTTOMLEFT", 20, 18)
    test:SetScript("OnClick", function()
        frame:Hide()
        addon:ShowChallenge("manual")
    end)

    frame:Hide()
    addon.settingsFrame = frame
end

function addon:ShowChallenge(triggerKey, level)
    local info = TRIGGER_INFO[triggerKey] or TRIGGER_INFO.manual
    self.currentTrigger = triggerKey
    self.pendingLevel = level
    if triggerKey == "profession" and self.pendingProfession then
        self.currentEventLabel = string.format(
            "%s Skill %d",
            self.pendingProfession.name,
            self.pendingProfession.milestone
        )
    elseif triggerKey == "quest" then
        self.currentEventLabel = string.format("%d Quests Complete", HoppdebaeseDB.questInterval or 10)
    else
        self.currentEventLabel = info.title
    end
    self.titleText:SetText(self.currentEventLabel)
    self.mainFrame:Show()
    self.mainFrame:Raise()
    StartBoxRoll(0.45)
end

local function RegisterOptionalEvent(eventName)
    -- Clients differ in which completion events they expose; invalid events are ignored.
    pcall(addon.RegisterEvent, addon, eventName)
end

local function ScanProfessionSkills(allowChallenge)
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return end

    local professionIndices = { GetProfessions() }
    local reachedMilestone
    for slot = 1, 6 do
        local professionIndex = professionIndices[slot]
        if professionIndex then
            local name, _, rank = GetProfessionInfo(professionIndex)
            rank = tonumber(rank)
            if name and rank then
                local previousRank = tonumber(HoppdebaeseDB.professionRanks[name])
                if allowChallenge and previousRank and rank > previousRank then
                    local previousMilestone = math.floor(previousRank / 10)
                    local currentMilestone = math.floor(rank / 10)
                    if currentMilestone > previousMilestone then
                        reachedMilestone = {
                            name = name,
                            milestone = currentMilestone * 10,
                        }
                    end
                end
                HoppdebaeseDB.professionRanks[name] = rank
            end
        end
    end

    if reachedMilestone and HoppdebaeseDB.triggers.professions then
        addon.pendingProfession = reachedMilestone
        addon:ShowChallenge("profession")
    end
end

addon:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= ADDON_NAME then return end
        InitializeDatabase()
        if not DIFFICULTIES[HoppdebaeseDB.difficulty] then HoppdebaeseDB.difficulty = "medium" end
        EnsureGuildIdentity()
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(MESSAGE_PREFIX)
        elseif RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(MESSAGE_PREFIX)
        end
        CreateSettingsWindow()
        CreateLeaderboardWindow()
        CreateExerciseLeaderboardWindow()
        CreateProgressWindow()
        CreateTodoWindow()
        CreateRestedWindow()
        CreateHelpWindow()
        CreateMainWindow()
        CreateMinimapButton()
        self:RefreshTodo()
        self:RefreshRested()
        RegisterOptionalEvent("LFG_COMPLETION_REWARD")
        RegisterOptionalEvent("DUNGEON_COMPLETED")
        RegisterOptionalEvent("CHALLENGE_MODE_COMPLETED")
        RegisterOptionalEvent("SCENARIO_COMPLETED")
        RegisterOptionalEvent("SKILL_LINES_CHANGED")

        SLASH_HOPPDEBASE1 = "/hopp"
        SLASH_HOPPDEBASE2 = "/hoppdebaese"
        SLASH_HOPPDEBASE3 = "/gfw"
        SlashCmdList.HOPPDEBASE = function(message)
            local command = string.lower((message or ""):match("^%s*(.-)%s*$"))
            if command == "settings" or command == "options" then
                self.settingsFrame:Show()
            elseif command == "leaderboard" or command == "guild" then
                self.leaderboardFrame:Show()
            elseif command == "exercises" or command == "top3" then
                self.exerciseLeaderboardFrame:Show()
            elseif command == "progress" or command == "overview" then
                self.progressFrame:Show()
            elseif command == "todo" or command == "tasks" then
                self.todoFrame:Show()
            elseif command == "rested" or command == "excluded" then
                self.restedFrame:Show()
            elseif command == "help" or command == "?" then
                self.helpFrame:Show()
            elseif command == "test" or command == "box" then
                self:ShowChallenge("manual")
            else
                print("|cff61f2adHoppdebäse|r: /hopp settings, /hopp todo, /hopp rested, /hopp help, /hopp progress, /hopp leaderboard, /hopp top3, /hopp test")
            end
        end
        return
    end

    if not HoppdebaeseDB then return end
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix ~= MESSAGE_PREFIX or channel ~= "GUILD" then return end
        if message == "Q|1" then
            BroadcastStats(false)
        elseif message:sub(1, 2) == "S|" then
            StoreGuildStats(sender, message)
            if self.leaderboardFrame and self.leaderboardFrame:IsShown() then RefreshLeaderboard(false) end
            if self.exerciseLeaderboardFrame and self.exerciseLeaderboardFrame:IsShown() then RefreshExerciseLeaderboard(false) end
        elseif message:sub(1, 2) == "C|" then
            StoreGuildCompletionCounts(sender, message)
            if self.leaderboardFrame and self.leaderboardFrame:IsShown() then RefreshLeaderboard(false) end
            if self.exerciseLeaderboardFrame and self.exerciseLeaderboardFrame:IsShown() then RefreshExerciseLeaderboard(false) end
        end
    elseif event == "PLAYER_LOGIN" then
        ScanProfessionSkills(false)
        RequestGuildStats(false)
    elseif event == "PLAYER_GUILD_UPDATE" then
        RequestGuildStats(false)
    elseif event == "QUEST_TURNED_IN" then
        HoppdebaeseDB.questsCompleted = (HoppdebaeseDB.questsCompleted or 0) + 1
        local interval = math.max(3, math.min(15, tonumber(HoppdebaeseDB.questInterval) or 10))
        if HoppdebaeseDB.triggers.quests and HoppdebaeseDB.questsCompleted % interval == 0 then
            self:ShowChallenge("quest")
        end
    elseif event == "SKILL_LINES_CHANGED" then
        ScanProfessionSkills(true)
    elseif event == "PLAYER_LEVEL_UP" and HoppdebaeseDB.triggers.levelUp then
        self:ShowChallenge("levelUp", ...)
    elseif event == "PLAYER_DEAD" and HoppdebaeseDB.triggers.death then
        self:ShowChallenge("death")
    elseif (event == "LFG_COMPLETION_REWARD" or event == "DUNGEON_COMPLETED")
        and HoppdebaeseDB.triggers.dungeon then
        self:ShowChallenge("dungeon")
    elseif (event == "CHALLENGE_MODE_COMPLETED" or event == "SCENARIO_COMPLETED")
        and HoppdebaeseDB.triggers.dungeon then
        self:ShowChallenge("dungeon")
    end
end)

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("CHAT_MSG_ADDON")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_GUILD_UPDATE")
addon:RegisterEvent("QUEST_TURNED_IN")
addon:RegisterEvent("PLAYER_LEVEL_UP")
addon:RegisterEvent("PLAYER_DEAD")

-- Taxi travel has no consistent event in Classic clients. Hooking the protected
-- action after it runs is secure and precisely identifies a selected flight path.
if type(hooksecurefunc) == "function" and type(TakeTaxiNode) == "function" then
    hooksecurefunc("TakeTaxiNode", function()
        if HoppdebaeseDB and HoppdebaeseDB.triggers.flight then
            addon:ShowChallenge("flight")
        end
    end)
end