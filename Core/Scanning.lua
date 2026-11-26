-- Core/InventoryCompanion_Scanning.lua
InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

this.Scanning = this.Scanning or {}
local scanning = this.Scanning

--- Read one occupied slot into the scanner's item shape, or nil when it is empty.
function scanning.ReadSlot(bagId, slotIndex)
    local itemId = GetItemId(bagId, slotIndex)
    if not itemId or itemId <= 0 then return nil end
    local link = GetItemLink(bagId, slotIndex)
    if not link or link == "" then return nil end
    local currentCount, maxCount = GetSlotStackSize(bagId, slotIndex)
    return {
        bagId = bagId,
        slotIndex = slotIndex,
        itemId = itemId,
        link = link,
        icon = GetItemLinkIcon(link),
        count = currentCount,
        maxCount = maxCount,
    }
end

--- Scan a list of bags and return a structured table of item instances/slots, optionally filtered by a select function.
function scanning.GetBagContents(bagIdList, selectFunc, checkpoint)
    local contents = {}

    local function AddSlot(bagId, slotIndex)
        local itemData = scanning.ReadSlot(bagId, slotIndex)
        if itemData and (not selectFunc or selectFunc(itemData)) then
            table.insert(contents, itemData)
        end
    end

    for _, bagId in ipairs(bagIdList) do
        if bagId == BAG_VIRTUAL then
            -- Special handling for Craft Bag iterator
            local slotIndex = GetNextVirtualBagSlotId(nil)
            while slotIndex do
                if checkpoint then checkpoint() end
                AddSlot(bagId, slotIndex)
                slotIndex = GetNextVirtualBagSlotId(slotIndex)
            end
        else
            -- Standard contiguous bags (Backpack, Banks, Chests)
            local bagSize = GetBagSize(bagId)
            for slotIndex = 0, bagSize - 1 do
                if checkpoint then checkpoint() end
                AddSlot(bagId, slotIndex)
            end
        end
    end

    return contents
end