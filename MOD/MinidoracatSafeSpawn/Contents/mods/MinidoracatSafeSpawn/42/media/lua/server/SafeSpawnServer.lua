---
--- MinidoracatSafeSpawn - Server-side Command Handler
--- claim：舊角色登入保護的次數上限（沙盒 NormalGhostLimit／NormalGhostWindowMinutes），准了才記下時間。
--- restore：保護到期時回報伺服器端的隱形真值。登入／重生保護只在 client 本機生效（覆蓋層），
--- 伺服器端的隱形只由原版機制改動：管理面板、/invisible、本 MOD 管理員選單走的 ExtraInfo。
---

print("[MinidoracatSafeSpawn] Loading SafeSpawnServer.lua...")

-- 帳號 → 計算時段內每次准許的時間（getTimestamp()，伺服器時鐘的秒，舊的在前）。Global ModData 由引擎
-- 跟世界一起存讀：開服 IsoWorld.init 讀回，定期存檔／save／正常關服的 ServerMap.QueuedSaveAll 寫入
-- （ServerMap.java:409）。當機時上次存檔之後的紀錄會遺失。
local CLAIMS = "MinidoracatSafeSpawn_NormalGhostClaims"

--- 舊角色登入申請：時段內次數沒到上限就准並記下時間，到了就拒並回報還要等幾分鐘。
--- 開了上限時附上幾秒後恢復 1 次（准：最舊一筆過期；拒：時段內剩 limit - 1 筆），准時另附還剩幾次；
--- client 把秒數換成玩家電腦的時鐘顯示。
--- 只回數字，提示文字由 client 組：專用伺服器的 Translator 沒有 MOD 的鍵，也不知道玩家的時區。
local function onClaim(player)
    local vars = SandboxVars and SandboxVars.MinidoracatSafeSpawn
    local limit = vars and tonumber(vars.NormalGhostLimit) or 0
    local windowSec = (vars and tonumber(vars.NormalGhostWindowMinutes) or 60) * 60
    local name, now = player:getUsername(), getTimestamp()
    local book = {}  -- 重建：丟掉時段外的時間，空了就拿掉整個帳號（表只留最近時段內有申請的人）
    for user, stamps in pairs(ModData.getOrCreate(CLAIMS)) do
        local kept = {}
        for _, t in ipairs(stamps) do
            if now - t < windowSec then kept[#kept + 1] = t end
        end
        if #kept > 0 then book[user] = kept end
    end
    local mine = book[name] or {}
    local granted, waitMinutes = limit <= 0 or #mine < limit, 0
    local left, refillSec
    if granted then
        mine[#mine + 1] = now
        book[name] = mine
        if limit > 0 then left, refillSec = limit - #mine, mine[1] + windowSec - now end
    else  -- 等到時段內只剩 limit - 1 筆
        refillSec = mine[#mine - limit + 1] + windowSec - now
        waitMinutes = math.max(1, math.ceil(refillSec / 60))
    end
    ModData.add(CLAIMS, book)
    sendServerCommand(player, "MinidoracatSafeSpawn", "claim",
        { granted = granted, waitMinutes = waitMinutes, left = left, refillSec = refillSec })
    print("[MinidoracatSafeSpawn] Server: claim " .. tostring(name) .. " " .. (granted and "granted" or "denied")
        .. " " .. #mine .. "/" .. limit .. (granted and "" or " wait=" .. waitMinutes .. "m"))
end

local function onClientCommand(module, command, player, args)
    if module ~= "MinidoracatSafeSpawn" then return end
    if not player then return end
    if command == "claim" then
        onClaim(player)
        return
    end
    if command ~= "restore" then return end

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
