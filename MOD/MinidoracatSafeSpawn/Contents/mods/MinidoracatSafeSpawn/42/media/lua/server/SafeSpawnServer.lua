---
--- MinidoracatSafeSpawn - Server-side Command Handler
--- 保護到期時回報伺服器端的隱形真值。登入／重生保護只在 client 本機生效（覆蓋層），
--- 伺服器端的隱形只由原版機制改動：管理面板、/invisible、本 MOD 管理員選單走的 ExtraInfo。
---

print("[MinidoracatSafeSpawn] Loading SafeSpawnServer.lua...")

local function onClientCommand(module, command, player, args)
    if module ~= "MinidoracatSafeSpawn" or command ~= "restore" then return end
    if not player then return end

    -- gated setter 寫回原值：有 ToggleInvisibleHimself 的人不變；沒有的被引擎設回 false
    -- （外洩旗標，例：舊版握手快照被 forced 套用）。伺服器端絕不用 forced 兩參數版：
    -- PlayerCheats 會存進角色檔，重連時 ConnectedPacket 再 forced 回寫 client，變成永久隱形。
    pcall(function() player:setInvisible(player:isInvisible()) end)
    local invisible = player:isInvisible()
    sendServerCommand(player, "MinidoracatSafeSpawn", "restore", { invisible = invisible })
    print("[MinidoracatSafeSpawn] Server: restore " .. tostring(player:getUsername())
        .. " invisible=" .. tostring(invisible))
end

Events.OnClientCommand.Add(onClientCommand)

print("[MinidoracatSafeSpawn] SafeSpawnServer.lua loaded successfully")
