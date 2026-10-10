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
enterGhost = false  -- 本機覆蓋層是否作用中（與 spawnProtectActive 同步；E2E 情境讀它）
isOnTickRegistered = false  -- 追蹤 OnTick 監聽器是否已註冊
adminGhostToggle = false  -- 管理員用選單設定的原版隱形；保護期間本機旗標被覆蓋，選單標籤與到期換回都看它
spawnProtectActive = false  -- 登入／重生保護是否進行中（本機覆蓋層的唯一原因）

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
    -- print("[MinidoracatSafeSpawn] [DEBUG] resetGhostMode: 狀態已重置")
end

--- 撤掉保護覆蓋層：本機隱形換回 adminGhostToggle（管理員用選單設定的原版隱形；其他人一律 false）。
--- MP 再向伺服器要真值：原版管理面板、/invisible 在保護期間的變更只在伺服器端（回覆見 OnServerCommand）。
--- @param player IsoPlayer
--- @param askServer boolean 到期時 true；角色死亡不必
local function releaseOverlay(player, askServer)
    pcall(function() player:setInvisible(adminGhostToggle) end)  -- gated：沒有隱形權限的一律 false
    pcall(function() player:setAlpha(1.0) end)
    if askServer and isClient() then
        sendClientCommand(player, "MinidoracatSafeSpawn", "restore", {})
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
    -- 角色已死：撤掉本機覆蓋層就好（新角色不帶舊的隱形），不必向伺服器要真值
    spawnProtectActive = false
    adminGhostToggle = false
    reconcileGhostState(getPlayer(), false)
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

--- 保護期間每 tick：倒數、蓋回本機覆蓋層、清掉正鎖定本玩家的殭屍目標。只在保護作用中註冊。
--- @param numberTicks number Number of ticks
OnGhostTick = function(numberTicks)
    local curPlayer = getPlayer()
    if not curPlayer then return end

    -- 握手閘門：重生時 OnNewGame 之後，新角色要等 AddCoopPlayer 跟伺服器往返完才放進
    -- IsoPlayer.players[]（42.21.0 AddCoopPlayer.java:142-153），這段期間 getPlayer() 已是新角色、
    -- OnTick 照跑，而 SendPlayerConnect 會快照旗標上傳（見下方覆蓋層的安全邊界 1）。
    -- 角色進入世界前一律不動作，倒數也不起算。
    if getSpecificPlayer(curPlayer:getPlayerNum()) ~= curPlayer then return end

    local now = getTimestampMs()
    if not ghostEndMs then
        -- 第一個過閘門的 tick：本 MOD 還沒寫任何旗標，ConnectedPacket 也已套上伺服器 role
        -- （同步路徑的 player:getRole() 仍是預設 user，IsoPlayer.java:330），讀到的就是真值。
        local ok, keep = pcall(function()
            return curPlayer:isInvisible()
                and curPlayer:getRole():hasCapability(Capability.ToggleInvisibleHimself)
        end)
        adminGhostToggle = ok and keep == true
        if adminGhostToggle then
            -- 本來就隱形、身分也有隱形權限（原版管理面板／指令開的，存在伺服器角色檔、登入時載回）：
            -- 使用者要求不跑倒數（2026-10-10）。覆蓋層還沒寫過，只撤 OnTick。
            -- 沒有 ToggleInvisibleHimself 卻帶著隱形＝外洩旗標，照常保護，到期由伺服器 gated setter 清掉。
            spawnProtectActive = false
            reconcileGhostState(nil, false)
            print("[MinidoracatSafeSpawn] Already invisible (ToggleInvisibleHimself); spawn protection skipped")
            pcall(function() curPlayer:setHaloNote(getText("UI_admin_ghost_enabled")) end)
            return
        end
        -- 過了握手閘門才起算：角色已進入世界、開始能操作（真實時間，不掛 EveryOneMinute）
        ghostEndMs = now + (ghostDurationSec or newGhostTime) * 1000
    end
    if now >= ghostEndMs then
        -- 到期：撤掉覆蓋層、換回真值（管理員在保護期間用選單開的隱形會留著）
        spawnProtectActive = false
        ghostEndMs = nil
        reconcileGhostState(curPlayer, true)
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

    -- 本機覆蓋層：每 tick 蓋回 forced 隱形旗標（ExtraInfo、原版管理面板都可能把它寫回去）。
    -- setGhostMode 是 setInvisible 的別名（同一 CheatType.INVISIBLE 旗標）。單參數版受 role capability 管制，
    -- 沒有 ToggleInvisibleHimself 的人寫不進去；兩參數 forced 版繞過檢查、只寫本機旗標。殭屍 AI 在
    -- 「殭屍擁有權 client」執行（NetworkZombieManager.canSpotted），登入點附近的殭屍通常由本玩家 client 模擬：
    -- ghost 玩家不被發現、已鎖定的目標被清掉、不會被攻擊（42.21.0 IsoZombie.java:868、1100、2070），
    -- DoFootstepSound 也不再發出吸引殭屍的聲音。
    -- 安全邊界（缺一不可）：
    -- 1. 遊戲進行中本機旗標不會上傳（PlayerPacket 不含 cheat flags），但連線握手的快照「會」帶
    --    getExtraInfoFlags()，伺服器 forced 套用並廣播給所有人（GameServer.receivePlayerConnect）：
    --    登入是 ConnectPacket（OnGameStart/OnNewGame 在 sendPlayerConnect 之前同步觸發，IngameState.enter），
    --    重生是 ConnectCoopPacket stage 2（AddCoopPlayer 跨好幾個 frame 等伺服器回覆，期間 OnTick 照跑）。
    --    此時寫入＝其他玩家整場看不到本玩家，保護結束也不會恢復。所以只在握手閘門之後寫。
    -- 2. 不碰伺服器端旗標：伺服器端隱形的玩家，移動不會轉給一般玩家（PlayerPacket.java:192），
    --    其他人看到的是定在原地的人，而且會存進角色檔。保護只在本機生效，其他玩家始終看得到受保護的人。
    -- 3. 單機（無 -debug）時 PlayerCheats.isCheatAllowed 擋掉所有 cheat 旗標寫入，
    --    覆蓋層是 no-op，保護只剩下方的殭屍目標清除。
    pcall(function() curPlayer:setInvisible(true, true) end)

    -- 一次性哨兵：forced 旗標依賴引擎的兩參數 overload dispatch，一旦未來版本
    -- 改簽名/移除 overload，pcall 會靜默吞錯、保護核心蒸發。read-back 驗證一次，
    -- 失效即留 log（保護仍有殭屍目標清除當退路）。僅 MP 檢查（SP 本來就寫不進去）。
    if isClient() and invisChecked == nil then
        local invOk, inv = pcall(function() return curPlayer:isInvisible() end)
        if invOk then
            invisChecked = inv and true or false
            if not inv then
                print("[MinidoracatSafeSpawn] WARN: forced setInvisible 未生效（引擎版本不相容？），退回殭屍目標清除保護")
            end
        end
    end

    pcall(function() curPlayer:setAlpha(0.5) end)

    -- 只清除「正鎖定本玩家」的殭屍目標（SP 非 debug 時這是唯一的保護）。
    -- 不對整個 cell 的每隻殭屍呼叫 setTarget(nil)：效果相同，但避免每 tick 對大量無關殭屍
    -- 呼叫 setTarget 並觸發 networkAi.extraUpdate。
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
end

--- 依 spawnProtectActive 掛／撤 OnTick（本機覆蓋層的唯一原因）。
--- 啟用方向刻意不在此寫入旗標：OnGameStart／OnNewGame 的同步路徑在連線握手快照之前，此時寫入會被
--- 伺服器 forced 廣播（見 OnGhostTick 覆蓋層的安全邊界 1）；旗標由 OnGhostTick 過了握手閘門才寫。
--- @param player IsoPlayer|nil 撤銷時要換回旗標的玩家；nil＝覆蓋層還沒寫過，只撤 OnTick
--- @param askServer boolean 撤銷時是否向伺服器要隱形真值（到期才要）
reconcileGhostState = function(player, askServer)
    enterGhost = spawnProtectActive
    if spawnProtectActive then
        if not isOnTickRegistered then
            Events.OnTick.Add(OnGhostTick)
            isOnTickRegistered = true
        end
        return
    end
    if not isOnTickRegistered then return end  -- 沒有保護在跑：不碰旗標
    Events.OnTick.Remove(OnGhostTick)
    isOnTickRegistered = false
    if player then releaseOverlay(player, askServer) end
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
    -- 截止時間刻意不在此計算：OnGhostTick 過了握手閘門才起算，避免把載入/握手時間吃進保護，
    -- 也確保 forced 旗標絕不在連線快照前寫入（見 OnGhostTick 覆蓋層的安全邊界 1）
    ghostEndMs = nil
    lastShownSecond = nil
    reconcileGhostState(player, false)
    print("[MinidoracatSafeSpawn] Protection enabled for " .. tostring(ghostDurationSec)
        .. "s (real time; normal=" .. tostring(oldGhostTime) .. "s new=" .. tostring(newGhostTime) .. "s)")
end

-- ============================================================================
-- Admin Context Menu（管理員右鍵選單）
-- ============================================================================

--- 選單上的「隱形中」：保護期間本機旗標是覆蓋層，改看 adminGhostToggle
--- @param player IsoPlayer
--- @return boolean
local function menuInvisible(player)
    if spawnProtectActive then return adminGhostToggle end
    local ok, inv = pcall(function() return player:isInvisible() end)
    return ok and inv == true
end

--- 管理員切換隱形：跟原版管理面板（ISAdminPowerUI 的 SAVE）同一條路——gated setter 寫本機，
--- sendPlayerExtraInfo 讓伺服器驗 ToggleInvisibleHimself、寫進角色檔並廣播 ExtraInfo，其他玩家才看得到變化。
--- 保護期間本機旗標仍由 OnGhostTick 蓋回，到期換回這裡設定的值。
local function onAdminToggleGhost(player)
    if not player then return end
    adminGhostToggle = not menuInvisible(player)
    pcall(function() player:setInvisible(adminGhostToggle) end)
    if isClient() then
        pcall(function() sendPlayerExtraInfo(player) end)
    end
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
    local invOk, inv = pcall(function() return player:isInvisible() end)
    local statusMsg = string.format(
        "[SafeSpawn] invisible=%s | spawnProtectActive=%s | remain=%ss | enterGhost=%s | isOnTickRegistered=%s | adminGhostToggle=%s",
        tostring(invOk and inv),
        tostring(spawnProtectActive),
        remainSec,
        tostring(enterGhost),
        tostring(isOnTickRegistered),
        tostring(adminGhostToggle)
    )
    print("[MinidoracatSafeSpawn] [DEBUG] " .. statusMsg)
    pcall(function() player:setHaloNote(statusMsg) end)
end

--- 右鍵選單：有隱形權限（ToggleInvisibleHimself）的人才看得到
local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test then return true end
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- 選單做的就是原版隱形，伺服器也用同一個權限驗證（ExtraInfoPacket.processServer）。
    -- 不用 isAdmin()：identity 比較，42.21 MP 的 admin 帳號也回 false（2026-10-10 E2E 實測）。
    local ok, capable = pcall(function()
        return player:getRole():hasCapability(Capability.ToggleInvisibleHimself)
    end)
    if not (ok and capable) then return end

    local mainOption = context:addOption(getText("UI_admin_menu_title"))
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(mainOption, subMenu)

    local ghostLabel = menuInvisible(player) and getText("UI_admin_ghost_disable") or getText("UI_admin_ghost_enable")
    subMenu:addOption(ghostLabel, player, onAdminToggleGhost)
    subMenu:addOption(getText("UI_admin_show_status"), player, onAdminShowStatus)
end

--- 伺服器回報隱形真值（保護到期時要的，見 releaseOverlay）
local function OnServerCommand(module, command, args)
    if module ~= "MinidoracatSafeSpawn" or command ~= "restore" then return end
    if spawnProtectActive or type(args) ~= "table" then return end  -- 回覆前又開始新一段保護：覆蓋層照舊
    local player = getPlayer()
    if not player then return end
    adminGhostToggle = args.invisible == true
    pcall(function() player:setInvisible(adminGhostToggle) end)  -- gated：沒有隱形權限的一律 false
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-- ============================================================================
-- Event Registration (Build 42 Compatible)
-- ============================================================================

Events.OnGameStart.Add(OnGameStart)
Events.OnNewGame.Add(OnNewGame)
Events.OnPlayerDeath.Add(OnPlayerDeath)
Events.OnServerCommand.Add(OnServerCommand)

print("[MinidoracatSafeSpawn] SafeSpawnMain.lua loaded successfully")
