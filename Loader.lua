local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local currentPlaceId = game.PlaceId

local REGISTRY_URL =
    "https://raw.githubusercontent.com/LunarLightG/LunarHub/refs/heads/main/games.json"

local CACHE_BUST = "?t=" .. tostring(os.time())

local function notify(text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "LunarHub",
            Text = tostring(text),
            Duration = duration or 5
        })
    end)
end

local function getGameName()
    local name = "Unknown Game"

    pcall(function()
        local info = MarketplaceService:GetProductInfo(currentPlaceId)

        if info and info.Name then
            name = info.Name
        end
    end)

    return name
end

local function findGame(games)
    if type(games) ~= "table" then
        return nil
    end

    for _, gameInfo in ipairs(games) do
        if type(gameInfo) == "table" then
            local placeIds = gameInfo.placeIds

            if type(placeIds) == "table" then
                for _, placeId in ipairs(placeIds) do
                    if tonumber(placeId) == tonumber(currentPlaceId) then
                        return gameInfo
                    end
                end
            end
        end
    end

    return nil
end

local function loadGame(gameInfo)
    local gameName = tostring(gameInfo.name or gameInfo.id or "Unknown Game")
    local scriptUrl = gameInfo.scriptUrl
    local status = tostring(gameInfo.status or "active")

    if status ~= "active" then
        notify(gameName .. "\nกำลังปิดปรับปรุง", 7)
        return
    end

    if type(scriptUrl) ~= "string" or scriptUrl == "" then
        notify("ไม่พบ Script URL", 7)
        warn("[LunarHub] Missing Script URL")
        return
    end

    notify("กำลังโหลด\n" .. gameName, 4)

    local okHttp, source = pcall(function()
        return game:HttpGet(scriptUrl .. CACHE_BUST)
    end)

    if not okHttp then
        notify("โหลด Script ไม่สำเร็จ", 7)
        warn("[LunarHub] HTTP Error:", source)
        return
    end

    if type(source) ~= "string" or source == "" then
        notify("Script ว่างเปล่า", 7)
        warn("[LunarHub] Empty Script")
        return
    end

    local okCompile, scriptFunction = pcall(function()
        return loadstring(source)
    end)

    if not okCompile or type(scriptFunction) ~= "function" then
        notify("Compile Error", 7)
        warn("[LunarHub] Compile Error:", scriptFunction)
        return
    end

    local okRun, runError = pcall(function()
        scriptFunction()
    end)

    if not okRun then
        notify("Runtime Error", 7)
        warn("[LunarHub] Runtime Error:", runError)
        return
    end

    notify("โหลดสำเร็จ\n" .. gameName, 4)

    print("[LunarHub] Loaded:", gameName)
    print("[LunarHub] PlaceId:", currentPlaceId)
    print("[LunarHub] Version:", tostring(gameInfo.version or "Unknown"))
end

notify("กำลังตรวจหาเกม...", 3)

local okRegistry, registrySource = pcall(function()
    return game:HttpGet(REGISTRY_URL .. CACHE_BUST)
end)

if not okRegistry then
    notify("โหลด games.json ไม่สำเร็จ", 7)
    warn("[LunarHub] Registry Error:", registrySource)
    return
end

if type(registrySource) ~= "string" or registrySource == "" then
    notify("games.json ว่างเปล่า", 7)
    warn("[LunarHub] Empty Registry")
    return
end

local okJson, games = pcall(function()
    return HttpService:JSONDecode(registrySource)
end)

if not okJson or type(games) ~= "table" then
    notify("games.json ไม่ถูกต้อง", 7)
    warn("[LunarHub] JSON Error:", games)
    return
end

local matchedGame = findGame(games)

if matchedGame then
    loadGame(matchedGame)
else
    local gameName = getGameName()

    notify(
        "เกมนี้ยังไม่รองรับ\n"
        .. gameName
        .. "\nPlaceId: "
        .. tostring(currentPlaceId),
        8
    )

    warn(
        "[LunarHub] Unsupported Game:",
        gameName,
        "| PlaceId:",
        currentPlaceId
    )
end
