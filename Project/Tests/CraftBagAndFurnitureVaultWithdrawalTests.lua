local function SetStorageBagConstants()
    BAG_BACKPACK = 1
    BAG_BANK = 2
    BAG_SUBSCRIBER_BANK = 3
    BAG_HOUSE_BANK_ONE = 4
    BAG_HOUSE_BANK_TWO = 5
    BAG_HOUSE_BANK_THREE = 6
    BAG_HOUSE_BANK_FOUR = 7
    BAG_HOUSE_BANK_FIVE = 8
    BAG_HOUSE_BANK_SIX = 9
    BAG_HOUSE_BANK_SEVEN = 10
    BAG_HOUSE_BANK_EIGHT = 11
    BAG_HOUSE_BANK_NINE = 12
    BAG_HOUSE_BANK_TEN = 13
    BAG_GUILDBANK = 14
    BAG_VIRTUAL = 15
    BAG_FURNITURE_VAULT = 16
end

local function GetWithdrawalItems(items)
    local withdrawals = {}
    for _, item in ipairs(items) do
        if item.label:find("^Withdraw ") then
            table.insert(withdrawals, item)
        end
    end
    return withdrawals
end

local function GetStowItems(items)
    local stows = {}
    for _, item in ipairs(items) do
        if item.label:find("^Stow ") then
            table.insert(stows, item)
        end
    end
    return stows
end

local function CreateContextMenuEnvironment(bagId, stackCount, bankOpen, guildBankOpen, canStow, gemmable)
    SetStorageBagConstants()
    local menuItems = {}
    local transfers = {}
    local stows = {}
    local registeredDialogs = {}
    local shownDialogs = {}
    local hookCallback
    local itemLink = "|H1:item:1001|h[Test Item]|h"

    InventoryCompanion = {
        GetActiveTrackedItems = function() return {} end,
        CanUseGuildBankPartialDeposits = function() return false end,
        CanUseGuildBankPartialWithdrawals = function() return false end,
        UpdateEventRegistry = function() end,
        RefreshItemTrackerPanel = function() end,
        TransferContextItem = function(sourceBag, sourceSlot, amount, sourceCount, sourceItemLink)
            table.insert(transfers, { sourceBag, sourceSlot, amount, sourceCount, sourceItemLink })
        end,
        StowContextItem = function(sourceSlot, amount, sourceCount, sourceItemLink, gemmableConfirmed)
            table.insert(stows, { sourceSlot, amount, sourceCount, sourceItemLink, gemmableConfirmed })
        end,
    }

    MENU_ADD_OPTION_LABEL = "menu option"
    ZO_PreHook = function(functionName, callback)
        assert(functionName == "ZO_InventorySlot_ShowContextMenu")
        hookCallback = callback
    end
    zo_callLater = function(callback) callback() end
    ZO_Inventory_GetBagAndIndex = function() return bagId, 27 end
    GetItemId = function() return 1001 end
    GetItemLink = function() return itemLink end
    GetItemLinkIcon = function() return "item-icon" end
    GetItemInfo = function() return 1001, stackCount end
    IsBankOpen = function() return bankOpen end
    IsGuildBankOpen = function() return guildBankOpen end
    IsHouseBankBag = function() return false end
    HasCraftBagAccess = function() return canStow ~= false end
    CanItemBeVirtual = function() return canStow ~= false end
    IsItemStolen = function() return false end
    SHARED_INVENTORY = {
        GenerateSingleSlotData = function()
            return { isGemmable = gemmable == true }
        end,
    }
    GAMEPAD_DIALOGS = { BASIC = "basic" }
    SI_CONFIRM_STOW_GEMIFIABLE_TITLE = "Stow gemmable item?"
    SI_CONFIRM_STOW_GEMIFIABLE_TEXT = "Confirm stowing this item."
    SI_YES = "Yes"
    SI_NO = "No"
    ZO_Dialogs_RegisterCustomDialog = function(name, definition)
        registeredDialogs[name] = definition
    end
    ZO_Dialogs_ShowPlatformDialog = function(name, data)
        table.insert(shownDialogs, { name, data })
    end
    AddCustomMenuItem = function(label, callback)
        table.insert(menuItems, { label = label, callback = callback })
    end
    ShowMenu = function() end

    assert(loadstring(ContextMenusSource, "Core\\ContextMenus.lua"))()
    InventoryCompanion.InitContextMenus()
    assert(hookCallback, "Context-menu hook was not registered")
    hookCallback({})

    return {
        menuItems = menuItems,
        transfers = transfers,
        stows = stows,
        registeredDialogs = registeredDialogs,
        shownDialogs = shownDialogs,
        bankOpen = bankOpen,
        guildBankOpen = guildBankOpen,
    }
end

local function CreateTransferEnvironment(
    sourceBag, stackCount, bankOpen, guildBankOpen, emptySlot, simulateMoves, initialBackpackStacks, gemmable)
    SetStorageBagConstants()
    local moveCalls = {}
    local messages = {}
    local alerts = {}
    local sounds = {}
    local errors = {}
    local warnings = {}
    local currentSourceCount = stackCount
    local backpackStacks = {}
    for slotIndex, count in pairs(initialBackpackStacks or {}) do
        backpackStacks[slotIndex] = count
    end
    local itemLink = "|H1:item:1001|h[Test Item]|h"
    local currentItemLink = itemLink
    local afterRequestMove

    InventoryCompanion = {
        Name = "InventoryCompanion_TransferTests",
        accountWide = { houseBankNames = {} },
        Utils = {
            UserMessage = function(chat, hud)
                table.insert(messages, { chat, hud })
            end,
            UserError = function(chat, hud)
                table.insert(errors, { chat, hud })
            end,
            UserWarning = function(message)
                table.insert(warnings, message)
            end,
        },
    }

    IsBankOpen = function() return bankOpen end
    IsGuildBankOpen = function() return guildBankOpen end
    HasCraftBagAccess = function() return true end
    CanItemBeVirtual = function() return true end
    IsItemStolen = function() return false end
    SHARED_INVENTORY = {
        GenerateSingleSlotData = function() return { isGemmable = gemmable == true } end,
    }
    GetItemInfo = function(bagId, slotIndex)
        if bagId == sourceBag and slotIndex == 27 and currentSourceCount > 0 then
            return 1001, currentSourceCount
        end
        if bagId == BAG_BACKPACK and backpackStacks[slotIndex] then
            return 1001, backpackStacks[slotIndex]
        end
        return nil, 0
    end
    GetItemId = function(bagId, slotIndex)
        if bagId == sourceBag and slotIndex == 27 and currentSourceCount > 0 then return 1001 end
        if bagId == BAG_BACKPACK and backpackStacks[slotIndex] then return 1001 end
        return nil
    end
    GetItemLink = function(bagId, slotIndex)
        if bagId == sourceBag and slotIndex == 27 then return currentItemLink end
        if bagId == BAG_BACKPACK and backpackStacks[slotIndex] then return currentItemLink end
        return nil
    end
    GetItemLinkName = function() return "Test Item" end
    GetBagSize = function(bagId)
        assert(bagId == BAG_BACKPACK, "Withdrawal target must be the backpack")
        return 5
    end
    GetSlotStackSize = function(bagId, slotIndex)
        assert(bagId == BAG_BACKPACK)
        return backpackStacks[slotIndex] or 0, 200
    end
    FindFirstEmptySlotInBag = function(bagId)
        assert(bagId == BAG_BACKPACK)
        if simulateMoves then
            if emptySlot and not backpackStacks[emptySlot] then return emptySlot end
            for slotIndex = 0, 4 do
                if not backpackStacks[slotIndex] then return slotIndex end
            end
            return nil
        end
        return emptySlot
    end
    ZO_Alert = function(...) table.insert(alerts, { ... }) end
    PlaySound = function(sound) table.insert(sounds, sound) end
    CallSecureProtected = function(functionName, ...)
        local call = { functionName, ... }
        table.insert(moveCalls, call)
        if simulateMoves and functionName == "RequestMoveItem" then
            local targetSlot = call[5]
            local requestedAmount = call[6]
            local space = 200 - (backpackStacks[targetSlot] or 0)
            local movedAmount = math.min(requestedAmount, space, currentSourceCount)
            currentSourceCount = currentSourceCount - movedAmount
            backpackStacks[targetSlot] = (backpackStacks[targetSlot] or 0) + movedAmount
        end
        if functionName == "RequestMoveItem" and afterRequestMove then
            afterRequestMove(#moveCalls)
        end
        return true
    end
    zo_callLater = function(callback) callback() end
    SOUNDS = { DIALOG_ACCEPT = "accept", NEGATIVE_CLICK = "negative" }
    UI_ALERT_CATEGORY_ERROR = "error"
    SI_INVENTORY_ERROR_INVENTORY_FULL = "inventory full"
    SI_INVENTORY_ERROR_BANK_FULL = "bank full"

    assert(loadstring(BankTransfersSource, "Banking\\BankTransfers.lua"))()
    return {
        addon = InventoryCompanion,
        moveCalls = moveCalls,
        messages = messages,
        alerts = alerts,
        sounds = sounds,
        errors = errors,
        warnings = warnings,
        backpackStacks = backpackStacks,
        itemLink = itemLink,
        afterRequestMove = function(callback) afterRequestMove = callback end,
        setSourceItemLink = function(newItemLink) currentItemLink = newItemLink end,
        sourceCount = function() return currentSourceCount end,
    }
end

function GetCraftBagAndFurnitureVaultWithdrawalTests()
    SetStorageBagConstants()
    return {
        {
            name = "Craft Bag and Furniture Vault context menus offer 1 and N-1",
            run = function()
                for _, sourceBag in ipairs({ BAG_VIRTUAL, BAG_FURNITURE_VAULT }) do
                    local environment = CreateContextMenuEnvironment(sourceBag, 6, false, false)
                    local withdrawals = GetWithdrawalItems(environment.menuItems)
                    assert(#withdrawals == 2, "Both partial-withdrawal options must be present")
                    assert(withdrawals[1].label == "Withdraw 1 (of 6)")
                    assert(withdrawals[2].label == "Withdraw 5 (of 6)")

                    withdrawals[1].callback()
                    withdrawals[2].callback()
                    assert(#environment.transfers == 2)
                    assert(environment.transfers[1][1] == sourceBag
                        and environment.transfers[1][2] == 27
                        and environment.transfers[1][3] == 1
                        and environment.transfers[1][4] == 6
                        and environment.transfers[1][5] == "|H1:item:1001|h[Test Item]|h")
                    assert(environment.transfers[2][1] == sourceBag
                        and environment.transfers[2][2] == 27
                        and environment.transfers[2][3] == 5
                        and environment.transfers[2][4] == 6
                        and environment.transfers[2][5] == "|H1:item:1001|h[Test Item]|h")
                end
            end,
        },
        {
            name = "Large Craft Bag and Furniture Vault stacks offer 1, 200, and batched N-1",
            run = function()
                for _, sourceBag in ipairs({ BAG_VIRTUAL, BAG_FURNITURE_VAULT }) do
                    local environment = CreateContextMenuEnvironment(sourceBag, 450, false, false)
                    local withdrawals = GetWithdrawalItems(environment.menuItems)
                    assert(#withdrawals == 3)
                    assert(withdrawals[1].label == "Withdraw 1 (of 450)")
                    assert(withdrawals[2].label == "Withdraw 200 (one stack)")
                    assert(withdrawals[3].label == "Withdraw 449 (of 450, 3 stacks)")

                    for _, item in ipairs(withdrawals) do item.callback() end
                    assert(#environment.transfers == 3)
                    assert(environment.transfers[1][3] == 1)
                    assert(environment.transfers[2][3] == 200)
                    assert(environment.transfers[3][3] == 449)
                end
            end,
        },
        {
            name = "New partial withdrawals work with a bank open but not a guild bank",
            run = function()
                for _, sourceBag in ipairs({ BAG_VIRTUAL, BAG_FURNITURE_VAULT }) do
                    local bank = CreateContextMenuEnvironment(sourceBag, 3, true, false)
                    assert(#GetWithdrawalItems(bank.menuItems) == 2,
                        "A standard bank being open must not hide these options")

                    local guildBank = CreateContextMenuEnvironment(sourceBag, 3, false, true)
                    assert(#GetWithdrawalItems(guildBank.menuItems) == 0,
                        "Do not add these options while the guild bank is open")
                end
            end,
        },
        {
            name = "Eligible backpack stacks offer Stow 1, N-1, and N",
            run = function()
                local environment = CreateContextMenuEnvironment(BAG_BACKPACK, 6, false, false)
                local stows = GetStowItems(environment.menuItems)
                assert(#stows == 3)
                assert(stows[1].label == "Stow 1 (of 6)")
                assert(stows[2].label == "Stow 5 (of 6)")
                assert(stows[3].label == "Stow 6 (of 6)")

                stows[1].callback()
                stows[2].callback()
                stows[3].callback()
                assert(#environment.stows == 3)
                assert(environment.stows[1][1] == 27 and environment.stows[1][2] == 1
                    and environment.stows[1][3] == 6
                    and environment.stows[1][4] == "|H1:item:1001|h[Test Item]|h")
                assert(environment.stows[2][1] == 27 and environment.stows[2][2] == 5
                    and environment.stows[2][3] == 6
                    and environment.stows[2][4] == "|H1:item:1001|h[Test Item]|h")
                assert(environment.stows[3][1] == 27 and environment.stows[3][2] == 6
                    and environment.stows[3][3] == 6
                    and environment.stows[3][4] == "|H1:item:1001|h[Test Item]|h")
            end,
        },
        {
            name = "Existing standard-bank deposits remain unchanged",
            run = function()
                local environment = CreateContextMenuEnvironment(BAG_BACKPACK, 6, true, false)
                local deposits = {}
                for _, item in ipairs(environment.menuItems) do
                    if item.label:find("^Deposit ") then table.insert(deposits, item) end
                end
                assert(#deposits == 2)
                deposits[1].callback()
                deposits[2].callback()
                assert(#environment.transfers == 2)
                assert(environment.transfers[1][1] == BAG_BACKPACK and environment.transfers[1][3] == 1)
                assert(environment.transfers[2][1] == BAG_BACKPACK and environment.transfers[2][3] == 5)
            end,
        },
        {
            name = "Stow excludes unavailable items and confirms gemmable items",
            run = function()
                assert(#GetStowItems(CreateContextMenuEnvironment(BAG_BACKPACK, 6, false, false, false).menuItems) == 0)
                local gemmable = CreateContextMenuEnvironment(BAG_BACKPACK, 6, false, false, true, true)
                local stows = GetStowItems(gemmable.menuItems)
                assert(#stows == 3)
                stows[1].callback()
                stows[3].callback()
                assert(#gemmable.shownDialogs == 2)
                assert(gemmable.shownDialogs[1][1] == "INVENTORYCOMPANION_PARTIAL_STOW_GEMMIFIABLE")
                assert(gemmable.shownDialogs[1][2].amount == 1)
                assert(gemmable.shownDialogs[2][2].amount == 6)
                assert(gemmable.shownDialogs[2][2].sourceItemLink == "|H1:item:1001|h[Test Item]|h")
                local dialog = gemmable.registeredDialogs[gemmable.shownDialogs[1][1]]
                assert(dialog.title.text == "Stow gemmable item?")
                dialog.buttons[1].callback({ data = gemmable.shownDialogs[2][2] })
                assert(#gemmable.stows == 1)
                assert(gemmable.stows[1][1] == 27 and gemmable.stows[1][2] == 6
                    and gemmable.stows[1][3] == 6
                    and gemmable.stows[1][4] == "|H1:item:1001|h[Test Item]|h"
                    and gemmable.stows[1][5] == true)
                assert(#GetStowItems(CreateContextMenuEnvironment(BAG_BACKPACK, 6, false, true).menuItems) == 0)
            end,
        },
        {
            name = "Single-item Craft Bag and Furniture Vault stacks have no partial choices",
            run = function()
                for _, sourceBag in ipairs({ BAG_VIRTUAL, BAG_FURNITURE_VAULT }) do
                    local environment = CreateContextMenuEnvironment(sourceBag, 1, false, false)
                    assert(#GetWithdrawalItems(environment.menuItems) == 0)
                end
            end,
        },
        {
            name = "Partial storage withdrawals request the exact amount into the backpack",
            run = function()
                for _, sourceBag in ipairs({ BAG_VIRTUAL, BAG_FURNITURE_VAULT }) do
                    local environment = CreateTransferEnvironment(sourceBag, 6, false, false, 4, true)
                    environment.addon.TransferContextItem(sourceBag, 27, 5, 6, environment.itemLink)
                    assert(#environment.moveCalls == 1)
                    local request = environment.moveCalls[1]
                    assert(request[1] == "RequestMoveItem")
                    assert(request[2] == sourceBag and request[3] == 27)
                    assert(request[4] == BAG_BACKPACK and request[5] == 4 and request[6] == 5)
                    assert(#environment.messages == 1 and #environment.alerts == 0)
                end
            end,
        },
        {
            name = "Full-stack storage withdrawals succeed when the source slot empties",
            run = function()
                for _, sourceBag in ipairs({ BAG_VIRTUAL, BAG_FURNITURE_VAULT }) do
                    local environment = CreateTransferEnvironment(sourceBag, 6, false, false, 4, true)
                    environment.addon.TransferContextItem(sourceBag, 27, 6, 6, environment.itemLink)
                    assert(#environment.moveCalls == 1 and environment.moveCalls[1][6] == 6)
                    assert(environment.sourceCount() == 0)
                    assert(environment.backpackStacks[4] == 6)
                    assert(#environment.errors == 0 and #environment.messages == 1)
                end
            end,
        },
        {
            name = "Large storage withdrawals request successive batches of at most 200",
            run = function()
                for _, sourceBag in ipairs({ BAG_VIRTUAL, BAG_FURNITURE_VAULT }) do
                    local environment = CreateTransferEnvironment(sourceBag, 450, false, false, nil, true)
                    environment.addon.TransferContextItem(sourceBag, 27, 449, 450, environment.itemLink)
                    assert(#environment.moveCalls == 3)
                    assert(environment.moveCalls[1][6] == 200)
                    assert(environment.moveCalls[2][6] == 200)
                    assert(environment.moveCalls[3][6] == 49)
                    assert(environment.moveCalls[1][5] == 0)
                    assert(environment.moveCalls[2][5] == 1)
                    assert(environment.moveCalls[3][5] == 2)
                    assert(environment.sourceCount() == 1)
                    assert(environment.backpackStacks[0] == 200)
                    assert(environment.backpackStacks[1] == 200)
                    assert(environment.backpackStacks[2] == 49)
                    assert(#environment.errors == 0)
                    assert(#environment.messages == 1)
                end
            end,
        },
        {
            name = "Large storage withdrawal stops if the source item changes between batches",
            run = function()
                local environment = CreateTransferEnvironment(BAG_VIRTUAL, 450, false, false, nil, true)
                environment.afterRequestMove(function(moveCount)
                    if moveCount == 1 then
                        environment.setSourceItemLink("|H1:item:2002|h[Other Item]|h")
                    end
                end)
                environment.addon.TransferContextItem(
                    BAG_VIRTUAL, 27, 449, 450, environment.itemLink)
                assert(#environment.moveCalls == 1)
                assert(environment.sourceCount() == 250)
                assert(environment.backpackStacks[0] == 200)
                assert(#environment.errors == 1)
                assert(environment.errors[1][1]:find("source stack changed", 1, true))
                assert(environment.errors[1][1]:find("Check your backpack and source storage", 1, true))
            end,
        },
        {
            name = "Large withdrawal reports a stopped partial transfer when backpack space runs out",
            run = function()
                local environment = CreateTransferEnvironment(BAG_VIRTUAL, 1002, false, false, nil, true)
                environment.addon.TransferContextItem(BAG_VIRTUAL, 27, 1001, 1002, environment.itemLink)
                assert(#environment.moveCalls == 5)
                assert(environment.sourceCount() == 2)
                assert(#environment.errors == 1)
                assert(environment.errors[1][1]:find("1000 of 1001", 1, true))
            end,
        },
        {
            name = "A partial backpack stack is skipped when it cannot fit an exact withdrawal",
            run = function()
                local environment = CreateTransferEnvironment(
                    BAG_VIRTUAL, 500, false, false, nil, true, { [0] = 150 })
                environment.addon.TransferContextItem(BAG_VIRTUAL, 27, 100, 500, environment.itemLink)
                assert(#environment.moveCalls == 1)
                assert(environment.moveCalls[1][5] == 1)
                assert(environment.moveCalls[1][6] == 100)
                assert(environment.sourceCount() == 400)
                assert(environment.backpackStacks[0] == 150)
                assert(environment.backpackStacks[1] == 100)
                assert(#environment.errors == 0)
            end,
        },
        {
            name = "Partial Craft Bag stow splits the requested amount into the virtual bag",
            run = function()
                local environment = CreateTransferEnvironment(BAG_BACKPACK, 6, false, false, 4)
                environment.addon.StowContextItem(27, 5, 6, environment.itemLink)
                assert(#environment.moveCalls == 2)
                assert(environment.moveCalls[1][1] == "PickupInventoryItem")
                assert(environment.moveCalls[1][2] == BAG_BACKPACK
                    and environment.moveCalls[1][3] == 27
                    and environment.moveCalls[1][4] == 5)
                assert(environment.moveCalls[2][1] == "PlaceInInventory")
                assert(environment.moveCalls[2][2] == BAG_VIRTUAL and environment.moveCalls[2][3] == 0)
                assert(#environment.errors == 0 and #environment.messages == 1)
            end,
        },
        {
            name = "Full-stack Craft Bag stow transfers the entire stack",
            run = function()
                local environment = CreateTransferEnvironment(BAG_BACKPACK, 6, false, false, 4)
                environment.addon.StowContextItem(27, 6, 6, environment.itemLink)
                assert(#environment.moveCalls == 2)
                assert(environment.moveCalls[1][1] == "PickupInventoryItem")
                assert(environment.moveCalls[1][2] == BAG_BACKPACK
                    and environment.moveCalls[1][3] == 27
                    and environment.moveCalls[1][4] == 6)
                assert(environment.moveCalls[2][1] == "PlaceInInventory")
                assert(environment.moveCalls[2][2] == BAG_VIRTUAL and environment.moveCalls[2][3] == 0)
                assert(#environment.errors == 0 and #environment.messages == 1)
            end,
        },
        {
            name = "Gemmable partial Stow requires confirmation in the transfer helper",
            run = function()
                local environment = CreateTransferEnvironment(BAG_BACKPACK, 6, false, false, 4,
                    false, nil, true)
                environment.addon.StowContextItem(27, 5, 6, environment.itemLink)
                assert(#environment.moveCalls == 0 and #environment.errors == 1)
                environment.addon.StowContextItem(27, 5, 6, environment.itemLink, true)
                assert(#environment.moveCalls == 2 and #environment.errors == 1)
            end,
        },
        {
            name = "Virtual-storage withdrawal rejects a changed source item",
            run = function()
                local environment = CreateTransferEnvironment(BAG_VIRTUAL, 6, false, false, 4, true)
                environment.setSourceItemLink("|H1:item:2002|h[Other Item]|h")
                environment.addon.TransferContextItem(
                    BAG_VIRTUAL, 27, 5, 6, "|H1:item:1001|h[Test Item]|h")
                assert(#environment.moveCalls == 0)
                assert(#environment.errors == 1)
                assert(environment.errors[1][1]:find("source stack changed", 1, true))
            end,
        },
        {
            name = "Virtual-storage withdrawal rejects a changed source count",
            run = function()
                local environment = CreateTransferEnvironment(BAG_VIRTUAL, 6, false, false, 4, true)
                environment.addon.TransferContextItem(
                    BAG_VIRTUAL, 27, 5, 7, environment.itemLink)
                assert(#environment.moveCalls == 0)
                assert(#environment.errors == 1)
                assert(environment.errors[1][1]:find("source stack changed", 1, true))
            end,
        },
        {
            name = "Craft Bag Stow rejects a changed item after confirmation",
            run = function()
                local environment = CreateTransferEnvironment(
                    BAG_BACKPACK, 6, false, false, 4, false, nil, true)
                environment.setSourceItemLink("|H1:item:2002|h[Other Item]|h")
                environment.addon.StowContextItem(
                    27, 5, 6, "|H1:item:1001|h[Test Item]|h", true)
                assert(#environment.moveCalls == 0)
                assert(#environment.errors == 1)
                assert(environment.errors[1][1]:find("backpack stack changed", 1, true))
            end,
        },
        {
            name = "Bank-only source guards and guild-bank suppression remain",
            run = function()
                local bank = CreateTransferEnvironment(BAG_BANK, 6, false, false, 4)
                bank.addon.TransferContextItem(BAG_BANK, 27, 1, 6, bank.itemLink)
                assert(#bank.moveCalls == 0, "A bank source still requires the bank to be open")

                local guildBank = CreateTransferEnvironment(BAG_VIRTUAL, 6, false, true, 4)
                guildBank.addon.TransferContextItem(BAG_VIRTUAL, 27, 1, 6, guildBank.itemLink)
                assert(#guildBank.moveCalls == 0, "New-source actions are blocked while the guild bank is open")
            end,
        },
        {
            name = "Partial storage withdrawal reports a full backpack without a move",
            run = function()
                local environment = CreateTransferEnvironment(BAG_VIRTUAL, 6, false, false, nil)
                environment.addon.TransferContextItem(BAG_VIRTUAL, 27, 5, 6, environment.itemLink)
                assert(#environment.moveCalls == 0)
                assert(#environment.messages == 0)
                assert(#environment.alerts == 1)
                assert(environment.alerts[1][1] == UI_ALERT_CATEGORY_ERROR)
                assert(environment.alerts[1][3] == SI_INVENTORY_ERROR_INVENTORY_FULL)
            end,
        },
    }
end
