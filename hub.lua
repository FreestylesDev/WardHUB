--==================================================
-- Demonfall Hub (Clean + Debug + Discord Logger)
-- Upload-ready | Raw-executable
--==================================================

--========================
-- CONFIG
--========================
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1463366559165579335/Vm7zuN-JxH4-ymbnLYpEd-CnEykovDgCS0A5sYYQ16AFb_aSKdDj9xHMbeOAExe7xNWk"

--========================
-- SERVICES
--========================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

--========================
-- LOAD RAYFIELD
--========================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

--========================
-- DEBUG STATE
--========================
_G.DebugLog = {}
_G.LastStackTrace = nil
_G.DebugEnabled = true

--========================
-- LOGGER CORE
--========================
local function log(msg)
    local line = os.date("[%H:%M:%S] ") .. tostring(msg)
    table.insert(_G.DebugLog, line)
    if _G.DebugEnabled then print(line) end
end

local function logError(msg)
    local line = os.date("[%H:%M:%S][ERROR] ") .. tostring(msg)
    table.insert(_G.DebugLog, line)
    warn(line)
end

--========================
-- REDACTION
--========================
local function redact(text)
    text = text:gsub("https://discord.com/api/webhooks/%S+", "[REDACTED_WEBHOOK]")
    text = text:gsub("https?://[%w%p]+", "[REDACTED_URL]")
    text = text:gsub("[%w%+/=]{20,}", "[REDACTED_TOKEN]")
    return text
end

--========================
-- DISCORD WEBHOOK
--========================
local lastSent = 0
local function sendDiscord(title, content)
    if os.clock() - lastSent < 5 then return end
    lastSent = os.clock()

    task.spawn(function()
        pcall(function()
            game:HttpPostAsync(
                DISCORD_WEBHOOK,
                HttpService:JSONEncode({
                    embeds = {{
                        title = title,
                        description = content,
                        color = 15158332,
                        footer = { text = "Demonfall Hub Debug" },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                    }}
                }),
                Enum.HttpContentType.ApplicationJson
            )
        end)
    end)
end

--========================
-- STACK TRACE HANDLER
--========================
local function handleError(err, context)
    local trace = debug.traceback(tostring(err), 2)
    _G.LastStackTrace = {
        time = os.date(),
        context = context,
        error = tostring(err),
        trace = trace
    }

    logError(context .. ": " .. err)
    sendDiscord(
        "❌ Script Error - " .. context,
        "```lua\n" .. redact(trace) .. "\n```"
    )
end

--========================
-- SAFE CALLBACK
--========================
local function WrapCallback(name, fn)
    return function(...)
        log("CALLBACK -> " .. name)
        local ok, res = xpcall(function()
            return fn(...)
        end, function(err)
            handleError(err, "Callback: " .. name)
        end)
        if ok then return res end
    end
end

--========================
-- SAFE LOOP
--========================
local function StartLoop(name, delay, fn)
    task.spawn(function()
        log("Loop started: " .. name)
        while true do
            local ok = xpcall(fn, function(err)
                handleError(err, "Loop: " .. name)
                task.wait(1)
            end)
            task.wait(delay or 0.2)
        end
    end)
end

--========================
-- UI WINDOW
--========================
local Window = Rayfield:CreateWindow({
    Name = "Demonfall Hub",
    LoadingTitle = "Demonfall",
    LoadingSubtitle = "Clean Debug Hub",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "DemonfallHub",
        FileName = "Config"
    }
})

--========================
-- FLAGS
--========================
_G.AutoFarm = false

--========================
-- AUTOFARM TAB
--========================
local FarmTab = Window:CreateTab("AutoFarm")

FarmTab:CreateToggle({
    Name = "Auto Farm",
    CurrentValue = false,
    Callback = WrapCallback("AutoFarm Toggle", function(v)
        _G.AutoFarm = v
    end)
})

StartLoop("AutoFarm", 0.3, function()
    if not _G.AutoFarm then return end
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = hrp.CFrame * CFrame.new(0, 0, -1)
    end
end)

--========================
-- DEBUG TAB
--========================
local DebugTab = Window:CreateTab("Debug")

DebugTab:CreateToggle({
    Name = "Enable Debug",
    CurrentValue = true,
    Callback = function(v)
        _G.DebugEnabled = v
        log("Debug: " .. (v and "ON" or "OFF"))
    end
})

DebugTab:CreateButton({
    Name = "Dump Logs (Console)",
    Callback = function()
        print("===== DEBUG LOG =====")
        for i, v in ipairs(_G.DebugLog) do
            print(i, redact(v))
        end
    end
})

DebugTab:CreateButton({
    Name = "Send Last Error to Discord",
    Callback = function()
        if _G.LastStackTrace then
            sendDiscord(
                "📤 Manual Error Report",
                "```lua\n" .. redact(_G.LastStackTrace.trace) .. "\n```"
            )
        else
            log("No error recorded")
        end
    end
})

log("Demonfall Hub loaded successfully")
