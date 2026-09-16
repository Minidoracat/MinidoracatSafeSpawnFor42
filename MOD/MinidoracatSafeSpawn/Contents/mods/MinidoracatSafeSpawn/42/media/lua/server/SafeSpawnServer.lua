---
--- MinidoracatSafeSpawn - Server-side Command Handler
--- Handles ghost mode state changes that require server authority
---

print("[MinidoracatSafeSpawn] Loading SafeSpawnServer.lua...")

-- 記錄每位玩家目前的幽靈狀態。client 端會每 GHOST_REFRESH_INTERVAL tick 重送 enableGhost
-- 作為安全網；這裡仍每次重新套用（cheap，確保伺服器端狀態），但只在狀態「真正改變」時
-- 才 print，避免定期刷新洗版 log（每位受保護玩家原本每 ~300 tick 就會多一行 log）。
local ghostState = {}

local function onClientCommand(module, command, player, args)
    if module ~= "MinidoracatSafeSpawn" then return end
    if not player then return end

    local key = tostring(player:getUsername())

    if command == "enableGhost" then
        player:setGhostMode(true)
        player:setZombiesDontAttack(true)
        pcall(function() player:setInvisible(true) end)
        if ghostState[key] ~= true then
            ghostState[key] = true
            print("[MinidoracatSafeSpawn] Server: Ghost mode ENABLED for " .. key)
        end

    elseif command == "disableGhost" then
        player:setGhostMode(false)
        player:setZombiesDontAttack(false)
        pcall(function() player:setInvisible(false) end)
        if ghostState[key] ~= false then
            ghostState[key] = false
            print("[MinidoracatSafeSpawn] Server: Ghost mode DISABLED for " .. key)
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)

print("[MinidoracatSafeSpawn] SafeSpawnServer.lua loaded successfully")
