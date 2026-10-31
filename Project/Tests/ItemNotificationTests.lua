local this = InventoryCompanion
local utils = this.Utils

function this.GetItemNotificationTests()
    return {
        {
            name = "Item destination limiter never redirects chat-only or HUD-only bursts",
            run = function()
                for _, destination in ipairs({ "chat", "hud" }) do
                    local clock = 1000
                    utils.BeginMessageCapture(function() return clock end)
                    for index = 1, 10 do
                        utils.UserWarning(destination == "chat" and ("chat" .. index) or nil,
                            destination == "hud" and ("hud" .. index) or nil, true)
                        clock = clock + 10
                    end
                    local messages = utils.EndMessageCapture()
                    for _, message in ipairs(messages) do
                        if destination == "chat" then
                            assert(message.hud == nil, "Chat-only burst must not generate a HUD prompt")
                        else
                            assert(message.chat == nil, "HUD-only burst must not redirect to chat")
                        end
                    end
                end
            end,
        },
        {
            name = "Item destination duplicates preserve selected outputs and other callers",
            run = function()
                utils.BeginMessageCapture(function() return 1000 end)
                utils.UserWarning(nil, "hud", true)
                utils.UserWarning(nil, "hud", true)
                utils.UserWarning("chat", nil, true)
                local messages = utils.EndMessageCapture()
                assert(messages[2].suppressed and messages[2].chat == nil, "HUD duplicate stays HUD-only")
                assert(messages[3].chat == "chat" and messages[3].hud == nil, "Chat-only stays chat-only")
                local clock = 1000
                utils.BeginMessageCapture(function() return clock end)
                for index = 1, 6 do
                    utils.UserWarning("currency" .. index, "currency HUD" .. index)
                    clock = clock + 10
                end
                messages = utils.EndMessageCapture()
                assert(messages[6].hud == "...check chat for more!", "Existing currency/capacity limiter remains unchanged")
            end,
        },
    }
end
