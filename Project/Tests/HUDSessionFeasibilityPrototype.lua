local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, entry in pairs(value) do result[key] = Copy(entry, seen) end
    return result
end

local function SavedVarsInterface(raw)
    return setmetatable({}, {
        __index = raw,
        __newindex = function(_, key, value) raw[key] = value end,
    })
end

local function ReplaceFields(target, source)
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(source) do target[key] = Copy(value) end
end

local function NewProfile()
    return {
        version = 10,
        useCharacterItemList = false,
        trackerOffsetX = 50,
        currencyPreferences = {
            [2] = { notify = true, locations = { bank = { hidden = false } } },
        },
        capacityPreferences = { bag = { notify = true, showCompact = true } },
        progressBarPreferences = { ["capacity:bag"] = { showBar = true, offsetX = 70 } },
        progressBarAlertColors = { warning = { r = 1, g = 0.5, b = 0, a = 1 } },
        trackedItems = { ore = { count = 4 } },
        trackedRules = { ore = { enabled = true } },
        filterShow = true,
        bankItemDelay = 100,
    }
end

local hudFields = {
    "trackerOffsetX",
    "currencyPreferences",
    "capacityPreferences",
    "progressBarPreferences",
    "progressBarAlertColors",
}

local function SnapshotHud(profile)
    local snapshot = {}
    for _, key in ipairs(hudFields) do snapshot[key] = Copy(profile[key]) end
    return snapshot
end

local function TestDirectEditSnapshot()
    local raw = NewProfile()
    local profile = SavedVarsInterface(raw)
    local openingSnapshot = SnapshotHud(profile)
    profile.hudEditRecovery = {
        startedAt = 123456,
        snapshot = Copy(openingSnapshot),
    }

    profile.trackerOffsetX = 91
    profile.currencyPreferences[2].locations.bank.hidden = true
    raw.trackedItems.ore.count = 8
    for _, key in ipairs(hudFields) do profile[key] = Copy(openingSnapshot[key]) end
    profile.hudEditRecovery = nil
    assert(raw.trackerOffsetX == 50, "A+: Cancel restores a direct scalar HUD edit")
    assert(raw.currencyPreferences[2].locations.bank.hidden == false,
        "A+: Cancel restores nested preferences without aliasing")
    assert(raw.trackedItems.ore.count == 8, "A+: scoped Cancel preserves unrelated tracking updates")

    local activeRaw = NewProfile()
    local activeProfile = SavedVarsInterface(activeRaw)
    local before = SnapshotHud(activeProfile)
    activeProfile.hudEditRecovery = { startedAt = 123456, snapshot = Copy(before) }
    activeProfile.trackerOffsetX = 91
    activeProfile.currencyPreferences[2].locations.bank.hidden = true
    local diskAtSave = Copy(activeRaw)
    assert(diskAtSave.trackerOffsetX == 91
        and diskAtSave.hudEditRecovery.startedAt == 123456
        and diskAtSave.hudEditRecovery.snapshot.trackerOffsetX == 50
        and diskAtSave.hudEditRecovery.snapshot.currencyPreferences[2].locations.bank.hidden == false,
        "A+: a save boundary persists preview, active marker, and original nested snapshot together")

    local restoredAtStartup = Copy(diskAtSave)
    local startupProfile = SavedVarsInterface(restoredAtStartup)
    local recovery = startupProfile.hudEditRecovery
    assert(recovery ~= nil and startupProfile.trackerOffsetX == 91,
        "A+: startup can detect a saved active session and offer resume")
    for _, key in ipairs(hudFields) do startupProfile[key] = Copy(recovery.snapshot[key]) end
    startupProfile.hudEditRecovery = nil
    assert(restoredAtStartup.trackerOffsetX == 50
        and restoredAtStartup.currencyPreferences[2].locations.bank.hidden == false,
        "A+: startup recovery restores the saved pre-session HUD settings")

    local doneRaw = Copy(diskAtSave)
    local doneProfile = SavedVarsInterface(doneRaw)
    doneProfile.trackerOffsetX = 91
    doneProfile.hudEditRecovery = nil
    local diskAfterDoneSave = Copy(doneRaw)
    assert(diskAfterDoneSave.trackerOffsetX == 91 and diskAfterDoneSave.hudEditRecovery == nil,
        "A+: Done followed by a save boundary persists edits without a recovery marker")

    local crashLive = NewProfile()
    local diskBeforeSession = Copy(crashLive)
    crashLive.hudEditRecovery = { startedAt = 123456, snapshot = SnapshotHud(crashLive) }
    crashLive.trackerOffsetX = 91
    crashLive.currencyPreferences[2].locations.bank.hidden = true
    local stateAfterCrash = Copy(diskBeforeSession)
    assert(stateAfterCrash.trackerOffsetX == 50 and stateAfterCrash.hudEditRecovery == nil
        and stateAfterCrash.currencyPreferences[2].locations.bank.hidden == false,
        "A+: crash before logout leaves the previously saved settings unchanged")

    local accountRaw, characterRaw = NewProfile(), NewProfile()
    characterRaw.trackerOffsetX = 150
    local account, character = SavedVarsInterface(accountRaw), SavedVarsInterface(characterRaw)
    account.hudEditRecovery = { startedAt = 123456, snapshot = SnapshotHud(account) }
    account.trackerOffsetX = 91
    local accountRecovery = account.hudEditRecovery
    for _, key in ipairs(hudFields) do account[key] = Copy(accountRecovery.snapshot[key]) end
    account.hudEditRecovery = nil
    assert(accountRaw.trackerOffsetX == 50 and character.trackerOffsetX == 150,
        "A+: automatic profile-switch cancellation restores only the originating profile")
    print("PASS A+: saved recovery record supports save/startup restore and preserves crash semantics")
end

local function TestFullProfileWorkingCopy()
    local raw = NewProfile()
    local profile = SavedVarsInterface(raw)
    local naiveProxyCopy = Copy(profile)
    assert(next(naiveProxyCopy) == nil,
        "B: pairs-based copying of the repository's empty forwarding proxy sees no root fields")

    local working = Copy(raw)
    local function GetSettingsProfile() return working end
    GetSettingsProfile().trackerOffsetX = 91
    GetSettingsProfile().trackedItems.ore.count = 8

    raw.trackedRules.externalUpdate = { enabled = true }
    raw.unrelatedSetting = "changed outside the working copy"
    ReplaceFields(raw, working)
    assert(raw.trackerOffsetX == 91, "B: Done commits HUD edits")
    assert(raw.trackedItems.ore.count == 8,
        "B: full-profile Done also commits unrelated state changed through the shared accessor")
    assert(raw.trackedRules.externalUpdate == nil and raw.unrelatedSetting == nil,
        "B: full-profile Done overwrites unrelated writes made directly to the saved profile")

    local cancelRaw = NewProfile()
    local cancelWorking = Copy(cancelRaw)
    cancelWorking.trackerOffsetX = 91
    cancelWorking.trackedItems.ore.count = 8
    cancelWorking = nil
    assert(cancelRaw.trackerOffsetX == 50 and cancelRaw.trackedItems.ore.count == 4,
        "B: Cancel/reload discards the transient full-profile copy")
    local accountRaw, characterRaw = NewProfile(), NewProfile()
    local accountCopy = Copy(accountRaw)
    accountCopy.trackerOffsetX = 91
    accountCopy = nil
    local activeProfile = SavedVarsInterface(characterRaw)
    assert(accountRaw.trackerOffsetX == 50 and activeProfile.trackerOffsetX == 50,
        "B: automatic profile-switch cancellation cannot commit into the newly selected profile")
    print("PASS B: staging is transient, but full-profile copy/commit has proxy and overwrite scope risks")
end

local function MigrateHudSection(profile)
    local hud = {}
    for _, key in ipairs(hudFields) do
        hud[key] = Copy(profile[key])
        profile[key] = nil
    end
    profile.hud = hud
end

local function TestHudSectionWorkingCopy()
    local raw = NewProfile()
    MigrateHudSection(raw)
    local profile = SavedVarsInterface(raw)
    local workingHud = Copy(profile.hud)

    workingHud.trackerOffsetX = 91
    workingHud.currencyPreferences[2].locations.bank.hidden = true
    workingHud.currencyPreferences[2].notify = false
    raw.trackedItems.ore.count = 8
    assert(raw.hud.trackerOffsetX == 50
        and raw.hud.currencyPreferences[2].locations.bank.hidden == false,
        "C: nested HUD edits remain transient before Done")
    profile.hud = Copy(workingHud)
    assert(raw.hud.trackerOffsetX == 91
        and raw.hud.currencyPreferences[2].locations.bank.hidden == true
        and raw.hud.currencyPreferences[2].notify == false,
        "C: section commit includes nested settings and notification choices")
    assert(raw.trackedItems.ore.count == 8 and raw.bankItemDelay == 100,
        "C: section commit preserves non-HUD updates")
    assert(raw.currencyPreferences == nil and raw.trackerOffsetX == nil,
        "C: migration moves the legacy fields into the section")

    local cancelRaw = NewProfile()
    MigrateHudSection(cancelRaw)
    local cancelWorkingHud = Copy(cancelRaw.hud)
    cancelWorkingHud.trackerOffsetX = 91
    cancelWorkingHud = nil
    assert(cancelRaw.hud.trackerOffsetX == 50,
        "C: Cancel/reload discards the transient section copy")
    local accountRaw, characterRaw = NewProfile(), NewProfile()
    MigrateHudSection(accountRaw)
    MigrateHudSection(characterRaw)
    characterRaw.hud.trackerOffsetX = 150
    local accountHudCopy = Copy(accountRaw.hud)
    accountHudCopy.trackerOffsetX = 91
    accountHudCopy = nil
    local activeProfile = SavedVarsInterface(characterRaw)
    assert(accountRaw.hud.trackerOffsetX == 50 and activeProfile.hud.trackerOffsetX == 150,
        "C: automatic profile-switch cancellation isolates both profile sections")
    print("PASS C: isolated section staging commits only HUD fields and preserves non-HUD updates")
end

TestDirectEditSnapshot()
TestFullProfileWorkingCopy()
TestHudSectionWorkingCopy()
print("3/3 synthetic HUD-session feasibility prototypes passed (Lua 5.1)")
