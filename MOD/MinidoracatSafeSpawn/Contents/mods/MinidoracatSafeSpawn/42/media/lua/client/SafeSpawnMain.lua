---
--- MinidoracatSafeSpawn - Safe Spawn Protection System
--- Ported from GhostAfterDead by xk
--- Adapted for Build 42 by Minidoracat
--- Features: 登入/重生隱身保護（真實秒數倒數）+ 管理員手動隱形切換
---

print("[MinidoracatSafeSpawn] Loading SafeSpawnMain.lua...")

-- ============================================================================
-- Helper Functions
-- ============================================================================

--- Safely get SandboxVars for MinidoracatSafeSpawn
--- @return table|nil The SandboxVars table or nil if not available
local function getSandboxVars()
    if not SandboxVars then
        return nil
    end
    return SandboxVars.MinidoracatSafeSpawn
end

--- Safely get a sandbox variable value with default
--- @param key string The variable key
--- @param default any The default value if not available
--- @return any The variable value or default
local function getSandboxVar(key, default)
    local vars = getSandboxVars()
    if not vars then
        return default
    end
    local value = vars[key]
    if value == nil then
        return default
    end
    return value
end

-- ============================================================================
-- Global Variables
-- ============================================================================

-- 新增狀態一律 local，避免擴大既有的 _G 污染（見 AGENTS.md KNOWN ISSUES）
local ghostEndMs = nil  -- 保護截止時間（真實時間 ms；nil = 尚未起算，第一個 OnTick 才起算）
local ghostDurationSec = nil  -- 本次保護時長（秒），enableProtection 決定
local lastShownSecond = nil  -- 上次顯示過倒數的秒數（避免同一秒重複顯示 halo）
local invisChecked = nil  -- forced setInvisible 生效性哨兵（nil = 尚未檢查，僅 MP 檢查一次）
local NEW_CHAR_HOURS = 0.1  -- 存活未滿 0.1 遊戲小時（6 遊戲分鐘）視為新角色
newGhostTime = 60  -- 新角色保護秒數（現實時間）
oldGhostTime = 30  -- 老角色保護秒數（現實時間）
enterGhost = false
isOnTickRegistered = false  -- 追蹤 OnTick 監聽器是否已註冊
enableGhostSent = false  -- 追蹤 enableGhost 命令是否已發送
ghostRefreshCounter = 0  -- 定期刷新計數器
GHOST_REFRESH_INTERVAL = 300  -- 每 300 tick（約 5 秒）重新發送一次指令
adminGhostToggle = false  -- 管理員手動切換的隱形狀態
spawnProtectActive = false  -- 重生保護是否進行中（與 adminGhostToggle 為兩個獨立的「啟用原因」）

-- Forward declarations（前向宣告，解決函式互相引用的順序問題）
local OnGhostTick
local enableProtection
local reconcileGhostState

-- ============================================================================
-- Core Functions
-- ============================================================================

--- Reset ghost mode state
local function resetGhostMode()
    ghostEndMs = nil
    lastShownSecond = nil
    ghostRefreshCounter = 0
    -- print("[MinidoracatSafeSpawn] [DEBUG] resetGhostMode: 狀態已重置")
end

--- Set ghost mode for player
--- @param player IsoPlayer The player to modify
--- @param isGhost boolean Whether to enable ghost mode
local function doGhost(player, isGhost)
    if not player then return end
    -- B42（42.20.2 反編譯）：setGhostMode 即 setInvisible 的別名（同一 CheatType.INVISIBLE
    -- 旗標，IsoPlayer.java:1063-1073）。單參數版受 role capability 管制——非管理員無論在
    -- 哪端呼叫都被強制設回 false。兩參數 forced 版（setInvisible(b, isForced)）繞過檢查，
    -- 僅寫入本機旗標：殭屍 AI 在「殭屍擁有權 client」執行（NetworkZombieManager.canSpotted），
    -- 登入點附近的殭屍通常由本玩家 client 模擬 → spottedNew 直接跳過 ghost 玩家（不看到、
    -- 不鎖定），DoFootstepSound 不再產生吸引殭屍的 WorldSound（不聽到）。
    -- 安全邊界（缺一不可）：
    -- 1. 遊戲進行中本機旗標不會上傳（PlayerPacket 不含 cheat flags），但 ConnectPacket 的
    --    登入快照「會」帶 getExtraInfoFlags()——OnGameStart/OnNewGame 是在 sendPlayerConnect
    --    之前同步觸發（IngameState.enter），因此絕不可在那些事件的同步路徑寫入旗標，
    --    否則會被伺服器 forced 套用並廣播，其他玩家將整場看不到本玩家。
    --    旗標一律由第一個 OnTick（必在握手完成後）寫入，見 reconcileGhostState。
    -- 2. 伺服器端絕不可用 forced 版：PlayerCheats 經 IsoGameCharacter save/load（5295/5405）
    --    存入伺服器端角色檔，且 ConnectedPacket 會把伺服器旗標 forced 回寫 client。
    -- 3. 單機（無 -debug）時 PlayerCheats.isCheatAllowed 擋掉所有 cheat 旗標寫入，
    --    此呼叫為 no-op，保護退回 OnGhostTick 的殭屍目標清除機制。
    pcall(function() player:setInvisible(isGhost, true) end)
    -- capability-gated 安全網：管理員 / debug 模式下仍有效
    pcall(function() player:setZombiesDontAttack(isGhost) end)
    -- 多人模式下也通知伺服器（盡力而為；非管理員在伺服器端會被 capability gate 擋下，
    -- 實效保護靠本機 forced 旗標 + 殭屍目標清除）
    if isClient() then
        if isGhost then
            sendClientCommand(player, "MinidoracatSafeSpawn", "enableGhost", {})
        else
            sendClientCommand(player, "MinidoracatSafeSpawn", "disableGhost", {})
        end
        -- print("[MinidoracatSafeSpawn] [DEBUG] 已發送伺服器指令: " .. (isGhost and "enableGhost" or "disableGhost"))
    end
end

--- Sync sandbox variables from settings
--- 選項鍵名 *Seconds 是 v1.5.0 語意變更（遊戲分鐘 → 現實秒）時刻意更換的：
--- 舊存檔持久化的 NormalGhostTime/NewStartTime（分鐘值 3/10）查無新鍵，
--- 自然回落秒制新預設 30/60，避免被靜默重解讀成 3 秒/10 秒。
local function syncSandBoxVar()
    if not getSandboxVars() then
        print("[MinidoracatSafeSpawn] WARN: SandboxVars 未就緒，使用預設 "
            .. tostring(oldGhostTime) .. "/" .. tostring(newGhostTime) .. "s")
        return
    end
    oldGhostTime = getSandboxVar("NormalGhostSeconds", 30)
    newGhostTime = getSandboxVar("NewStartSeconds", 60)
end

--- Start or end ghost mode
--- @param isGhost boolean Whether to enter ghost mode
local function startGhost(isGhost)
    enterGhost = isGhost
end

--- Initialize player with ghost mode
--- @param player IsoPlayer The player to initialize
local function init(player)
    if not player then
        print("[MinidoracatSafeSpawn] init: player is nil, skipping")
        return
    end
    
    if not getSandboxVar("EnableGhostOnSpawn", true) then
        print("[MinidoracatSafeSpawn] init: EnableGhostOnSpawn is disabled")
        return
    end

    enableProtection(player)
    print("[MinidoracatSafeSpawn] Ghost mode activated for player")
end

--- OnGameStart event handler (Build 42 replacement for OnLoad)
local function OnGameStart()
    print("[MinidoracatSafeSpawn] OnGameStart triggered - initializing ghost protection...")
    init(getPlayer())
end

--- Player death handler
--- @param _ any Unused parameter
local function OnPlayerDeath(_)
    resetGhostMode()
    -- 死亡清乾淨兩個原因，再由 reconcile 統一解除保護（移除 OnTick、enterGhost=false）
    spawnProtectActive = false
    adminGhostToggle = false
    reconcileGhostState(getPlayer())
end

--- New game handler
--- @param player IsoPlayer The player
--- @param square IsoGridSquare The spawn square
local function OnNewGame(player, square)
    if not getSandboxVar("EnableGhostOnSpawn", true) then
        return
    end
    
    if not player then return end
    
    local hasOnlineID = false
    local idSuccess, onlineID = pcall(function() return player:getOnlineID() end)
    if idSuccess and onlineID ~= nil then
        hasOnlineID = true
    end
    
    if hasOnlineID then
        enableProtection(player)
    end
end

--- Ghost tick handler - updates ghost state every tick
--- 使用定期刷新機制確保伺服器端隱形狀態持續有效
--- @param numberTicks number Number of ticks
OnGhostTick = function(numberTicks)
    local curPlayer = getPlayer()
    if not curPlayer then return end

    -- 重生保護倒數（真實時間）。OnGhostTick 只在保護作用中才註冊，
    -- 所以倒數只要掛在這裡即可，不需要獨立的 EveryOneMinute 監聽器。
    if spawnProtectActive then
        local now = getTimestampMs()
        if not ghostEndMs then
            -- 第一個 OnTick 才起算：此時 sendPlayerConnect 握手必已完成、玩家開始能操作
            ghostEndMs = now + (ghostDurationSec or newGhostTime) * 1000
        end
        if now >= ghostEndMs then
            -- 到期：只清除 spawn 這個原因；OnTick / 隱形是否保留交給 reconcile
            -- （管理員可能仍開著手動隱形，此時不應強制解除）
            spawnProtectActive = false
            ghostEndMs = nil
            reconcileGhostState(curPlayer)
            if not adminGhostToggle then
                pcall(function() curPlayer:setHaloNote(getText("UI_over_ghost_time")) end)
            end
            return
        end
        local remaining = math.ceil((ghostEndMs - now) / 1000)
        if remaining ~= lastShownSecond then
            lastShownSecond = remaining
            -- 每 10 秒提示一次，最後 5 秒逐秒倒數，避免 halo 洗版
            if not adminGhostToggle and (remaining <= 5 or remaining % 10 == 0) then
                pcall(function() curPlayer:setHaloNote(getText("UI_ghost_time_count_down", remaining)) end)
            end
        end
    end

    if isClient() then
        if enterGhost then
            -- 每 tick 在客戶端本地刷新旗標（forced 版繞過 capability gate，見 doGhost 註解）
            pcall(function() curPlayer:setInvisible(true, true) end)
            pcall(function() curPlayer:setZombiesDontAttack(true) end)

            -- 一次性哨兵：forced 旗標依賴引擎的兩參數 overload dispatch，一旦未來版本
            -- 改簽名/移除 overload，pcall 會靜默吞錯、保護核心蒸發。read-back 驗證一次，
            -- 失效即留 log（保護仍有殭屍目標清除當退路）。僅 MP 檢查（SP 本來就寫不進去）。
            if invisChecked == nil then
                local invOk, inv = pcall(function() return curPlayer:isInvisible() end)
                if invOk then
                    invisChecked = inv and true or false
                    if not inv then
                        print("[MinidoracatSafeSpawn] WARN: forced setInvisible 未生效（引擎版本不相容？），退回殭屍目標清除保護")
                    end
                end
            end

            -- 定期發送伺服器指令保持伺服器端同步
            ghostRefreshCounter = ghostRefreshCounter + 1
            if not enableGhostSent or ghostRefreshCounter >= GHOST_REFRESH_INTERVAL then
                sendClientCommand(curPlayer, "MinidoracatSafeSpawn", "enableGhost", {})
                -- if not enableGhostSent then
                --     print("[MinidoracatSafeSpawn] [DEBUG] 首次發送 enableGhost 指令到伺服器")
                -- else
                --     print("[MinidoracatSafeSpawn] [DEBUG] 定期刷新 enableGhost 指令（每 " .. GHOST_REFRESH_INTERVAL .. " tick）")
                -- end
                enableGhostSent = true
                ghostRefreshCounter = 0
            end
        end
    else
        doGhost(curPlayer, enterGhost)
    end

    if enterGhost then
        pcall(function() curPlayer:setAlpha(0.5) end)

        -- 非管理員保護的核心機制：只清除「正鎖定本玩家」的殭屍目標。
        -- 不再對整個 cell 的每隻殭屍呼叫 setTarget(nil)——保護效果相同，
        -- 但避免每 tick 對大量無關殭屍呼叫 setTarget 並觸發 networkAi.extraUpdate。
        pcall(function()
            local cell = curPlayer:getCell()
            if not cell then return end
            local zombies = cell:getZombieList()
            if not zombies then return end
            for i = 0, zombies:size() - 1 do
                local zombie = zombies:get(i)
                if zombie and zombie:getTarget() == curPlayer then
                    zombie:setTarget(nil)
                end
            end
        end)
    else
        pcall(function() curPlayer:setAlpha(1.0) end)
    end
end

--- 調和幽靈狀態：依 spawnProtectActive / adminGhostToggle 兩個獨立原因，
--- 決定 OnTick 註冊與隱形開關。只有「兩個原因都關閉」時才真正解除保護，
--- 避免管理員手動切換與重生倒數互相覆蓋（彼此清除對方所需的 OnTick / enterGhost）。
--- @param player IsoPlayer|nil 目前玩家（可為 nil，僅跳過視覺套用）
reconcileGhostState = function(player)
    local desired = spawnProtectActive or adminGhostToggle
    startGhost(desired)
    if desired then
        if not isOnTickRegistered then
            Events.OnTick.Add(OnGhostTick)
            isOnTickRegistered = true
        end
    else
        if isOnTickRegistered then
            Events.OnTick.Remove(OnGhostTick)
            isOnTickRegistered = false
        end
        enableGhostSent = false
        ghostRefreshCounter = 0
    end
    -- 啟用方向刻意「不」在此立即寫入旗標：reconcile 會在 OnGameStart/OnNewGame 的
    -- 同步路徑被呼叫，而那是在 sendPlayerConnect 之前——此時寫入 forced 旗標會被
    -- ConnectPacket 的 getExtraInfoFlags() 快照帶上伺服器並 forced 廣播給所有 client，
    -- 造成其他玩家整場看不到本玩家（見 doGhost 安全邊界 1）。
    -- 啟用方向的旗標/alpha 由第一個 OnGhostTick 寫入；解除方向立即清理無此風險。
    if player and not desired then
        doGhost(player, false)
        pcall(function() player:setAlpha(1.0) end)
    end
end

--- Enable spawn protection for player
--- @param player IsoPlayer|nil 目前玩家（呼叫端傳入；nil 時退回 getPlayer()）
enableProtection = function(player)
    player = player or getPlayer()
    spawnProtectActive = true
    syncSandBoxVar()
    -- 新角色（剛出生，存活未滿 NEW_CHAR_HOURS 遊戲小時）給較長的 NewStartSeconds，
    -- 老角色（重登）給 NormalGhostSeconds；倒數以真實時間計（getTimestampMs）
    local hoursSurvived = 0
    local hoursSuccess, hours = pcall(function() return player:getHoursSurvived() end)
    if hoursSuccess and hours then
        hoursSurvived = hours
    else
        print("[MinidoracatSafeSpawn] WARN: getHoursSurvived 失敗，以新角色時長處理")
    end
    ghostDurationSec = (hoursSurvived < NEW_CHAR_HOURS) and newGhostTime or oldGhostTime
    -- 截止時間刻意不在此計算：第一個 OnTick 才起算，避免把載入/握手時間吃進保護，
    -- 也確保 forced 旗標絕不在 ConnectPacket 快照前寫入（見 doGhost / reconcile 註解）
    ghostEndMs = nil
    lastShownSecond = nil
    enableGhostSent = false
    ghostRefreshCounter = 0
    reconcileGhostState(player)
    print("[MinidoracatSafeSpawn] Protection enabled for " .. tostring(ghostDurationSec)
        .. "s (real time; normal=" .. tostring(oldGhostTime) .. "s new=" .. tostring(newGhostTime) .. "s)")
end

-- ============================================================================
-- Admin Context Menu（管理員右鍵選單）
-- ============================================================================

--- 管理員切換隱形模式的回呼函式
local function onAdminToggleGhost(player)
    if not player then return end
    adminGhostToggle = not adminGhostToggle
    -- print("[MinidoracatSafeSpawn] [DEBUG] 管理員手動切換隱形: " .. tostring(adminGhostToggle))

    -- 只切換「管理員」這個原因；OnTick / 隱形開關交給 reconcile。
    -- 若重生保護仍在進行（spawnProtectActive），關閉管理員隱形不會中斷重生保護。
    reconcileGhostState(player)

    if adminGhostToggle then
        pcall(function() player:setHaloNote(getText("UI_admin_ghost_enabled")) end)
    else
        pcall(function() player:setHaloNote(getText("UI_admin_ghost_disabled")) end)
    end
end

--- 管理員顯示保護狀態的回呼函式
local function onAdminShowStatus(player)
    if not player then return end
    local remainSec = "nil"
    if ghostEndMs then
        remainSec = tostring(math.max(0, math.ceil((ghostEndMs - getTimestampMs()) / 1000)))
    end
    local statusMsg = string.format(
        "[SafeSpawn] enterGhost=%s | spawnProtectActive=%s | remain=%ss | enableGhostSent=%s | isOnTickRegistered=%s | adminGhostToggle=%s | ghostRefreshCounter=%s",
        tostring(enterGhost),
        tostring(spawnProtectActive),
        remainSec,
        tostring(enableGhostSent),
        tostring(isOnTickRegistered),
        tostring(adminGhostToggle),
        tostring(ghostRefreshCounter)
    )
    print("[MinidoracatSafeSpawn] [DEBUG] " .. statusMsg)
    pcall(function() player:setHaloNote(statusMsg) end)
end

--- 右鍵選單填充 - 管理員專用選項
local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test then return true end
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- 僅管理員可見（使用 PZ 全域函式 isAdmin）
    local hasAccess = false
    pcall(function()
        if isAdmin() then
            hasAccess = true
        elseif isClient() and getAccessLevel() == "moderator" then
            hasAccess = true
        end
    end)
    if not hasAccess then return end

    -- 建立子選單
    local mainOption = context:addOption(getText("UI_admin_menu_title"))
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(mainOption, subMenu)

    -- 隱形切換選項
    local ghostLabel
    if adminGhostToggle then
        ghostLabel = getText("UI_admin_ghost_disable")
    else
        ghostLabel = getText("UI_admin_ghost_enable")
    end
    subMenu:addOption(ghostLabel, player, onAdminToggleGhost)

    -- 顯示保護狀態選項
    subMenu:addOption(getText("UI_admin_show_status"), player, onAdminShowStatus)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-- ============================================================================
-- Event Registration (Build 42 Compatible)
-- ============================================================================

Events.OnGameStart.Add(OnGameStart)
Events.OnNewGame.Add(OnNewGame)
Events.OnPlayerDeath.Add(OnPlayerDeath)

print("[MinidoracatSafeSpawn] SafeSpawnMain.lua loaded successfully")
