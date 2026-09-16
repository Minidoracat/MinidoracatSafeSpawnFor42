# 更新日誌

本專案所有重要變更將記錄於此檔案。

格式遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，
版本號遵循 [語義化版本](https://semver.org/spec/v2.0.0.html)。

## [42.20.2-1.5.0] - 2026-08-10

### 新增
- **日本語対応**：遊戲內字串（沙盒選項、倒數提示、管理員選單）與 Steam 商店描述新增日文（JP），與 EN/CH/CN 鍵集同步。

### 修復
- **保護時間在快時鐘伺服器上嚴重縮水**：以往倒數按「遊戲分鐘」計算，伺服器時間加速時「3 分鐘」實際只有十幾秒——即玩家回報「時間算快、幾秒就結束」的問題。現在改以**現實秒數**計時，並從載入完成、角色可操作後才開始倒數；倒數提示改為每 10 秒一次、最後 5 秒逐秒。

> 技術要點：`EveryOneMinute` 是遊戲分鐘（MP 快時鐘日長 1.5h 下 1 遊戲分 ≈ 3.78 實秒）。改用 `getTimestampMs()` 真實毫秒、倒數邏輯移入 `OnGhostTick`；`ghostEndMs` 延後到第一個 OnTick 才起算，避開 ConnectPacket 旗標快照時序與載入時間損耗。

- **保護期間殭屍仍會朝玩家走來**：以往殭屍看得到受保護玩家、會一路靠近，只有攻擊被擋下，腳步聲也照常吸引殭屍。現在保護期間殭屍完全看不到、聽不到你，不會再圍過來。

> 技術要點：42.20.2 反編譯確認 `setGhostMode` 即 `setInvisible`（同一 `CheatType.INVISIBLE` 旗標），單參數版被 role capability gate 對非管理員強制清除。client 端改用 `setInvisible(b, isForced=true)` 兩參數版寫入本機旗標（Kahlua `MultiLuaJavaInvoker` 依 arity 分派，已正向驗證）：本機模擬的殭屍不再經 `spottedNew` / `DoFootstepSound` 感知玩家；殭屍目標清除保留為退路；一次性 read-back 哨兵在 forced 失效時留 WARN log。

### 變更
- **沙盒選項單位改為現實秒並更名**：「舊角色／新角色隱身時間」現在以秒（現實時間）設定，預設 30／60、範圍 1–600。**既有伺服器請重新設定**：舊版設定值會失效並回落新預設。

> 技術要點：`NormalGhostTime` / `NewStartTime` → `NormalGhostSeconds` / `NewStartSeconds`。刻意更換鍵名讓舊存檔的分鐘值（3/10）查無新鍵而回落新預設，避免被靜默重解讀成 3 秒/10 秒；三語 Sandbox.json 同步更名。日後再改語意必換鍵名。

### 移除
- 清理移植殘留的無效程式碼。

> 技術要點：刪除 `temporaryUpdate`（從未註冊）、`showGhostDown`、`GhostCountDown` 與 `EveryOneMinute` 註冊、`allowGhostMode` / `ghostTime` 全域變數；新增狀態變數一律 `local`。

### 備註
- **已知限制**：多人時由其他玩家客戶端模擬的殭屍不受影響（引擎限制，與舊版相同）；單機（無 -debug）保護僅靠殭屍目標清除；保護期間角色短暫具有原版隱身的移動特性。

> 技術要點：安全邊界詳見 AGENTS.md ANTI-PATTERNS——forced 旗標嚴禁在 `OnGameStart` / `OnNewGame` 同步路徑寫入（`ConnectPacket` 的 `getExtraInfoFlags()` 快照會被伺服器 forced 套用並廣播，其他玩家整場看不到該玩家）、嚴禁在伺服器端使用（`PlayerCheats` 經 `IsoGameCharacter` save/load 存入角色檔，`ConnectedPacket` 重連時 forced 回寫）。本版經 42.20.2 反編譯源碼稽核＋Claude 三 lane（base / silent-failure / 註解查核）與 Codex review-plus 雙邊獨立 review，兩個 BLOCKING（ConnectPacket 旗標洩漏、沙盒鍵語意變更無遷移）於發布前修復。

## [42.19.0-1.4.1] - 2026-06-14

### 修復
- **管理員隱形與重生倒數互相覆蓋**：重構幽靈狀態機，將「重生保護」與「管理員手動隱形」拆為兩個獨立旗標（`spawnProtectActive` / `adminGhostToggle`），由新增的 `reconcileGhostState()` 統一調和；只有兩個原因都關閉時才真正解除保護。修復管理員在倒數期間切換隱形後，原本的重生保護被永久取消、HUD 卻仍顯示倒數的問題。同時讓 `enableProtection()` 重新武裝 `allowGhostMode` / `ghostTime`，避免保護到期後在同一 session 再次啟用時倒數不再執行、保護永久卡住。
- **每 tick 全 cell 殭屍掃描效能問題**：`OnGhostTick` 改為只清除「目標正鎖定本玩家」的殭屍（`zombie:getTarget() == player`），不再對整個 cell 的每隻殭屍呼叫 `setTarget(nil)`。保護效果不變，但大幅降低每 tick 成本與不必要的 `networkAi.extraUpdate` 觸發。

### 變更
- **減少伺服器 log 洗版**：`enableGhost` 的定期刷新（每 300 tick）原本每次都讓伺服器印出「Ghost mode ENABLED for ...」。改為伺服器端記錄每位玩家的幽靈狀態，只在狀態「真正改變」（啟用 / 解除）時才寫 log；定期刷新仍照常重新套用作為安全網，但不再洗版。

### 備註
- 經 PZ 42.19.0 反編譯源碼稽核（Claude + Codex 雙邊獨立驗證）：所有 PZ API 簽名相容、MOD 不會崩潰。`setGhostMode` / `setInvisible` / `setZombiesDontAttack` 受 B42 role capability 系統管制（非管理員在 client 與 server 端皆會被設回 false）為已知限制；非管理員的實際保護依賴上述殭屍目標清除機制。完整稽核結果見 `AGENTS.md` 的「KNOWN ISSUES」。

## [1.4.0] - 2026-04-04

### 修復
- **隱形保護未真正生效**：修復多人伺服器上殭屍仍會攻擊受保護玩家的問題
  - 根本原因：B42 殭屍 AI 在客戶端執行，伺服器端設定的 `setGhostMode`/`setZombiesDontAttack`/`setInvisible` 不會同步到客戶端
  - 解決方案（管理員）：在客戶端每 tick 刷新 `setGhostMode`/`setZombiesDontAttack`/`setInvisible`，管理員完全隱形
  - 解決方案（非管理員）：每 tick 清除附近殭屍的攻擊目標，防止殭屍攻擊（PZ 引擎限制：非管理員無法在客戶端呼叫隱形 API）
- **God Mode 不再阻止保護啟動**：移除 `init()` 和 `GhostCountDown()` 中的 God Mode 跳過邏輯，GodMod 和隱形保護現為獨立功能
- **`player:Say()` 改為 `player:setHaloNote()`**：倒數訊息不再發出聲音吸引殭屍

### 新增
- **管理員右鍵選單**：管理員右鍵地面可看到「SafeSpawn 管理工具」子選單
  - 開啟/關閉隱形模式：即時切換，方便測試
  - 顯示保護狀態：顯示所有內部變數（`enterGhost`、`ghostTime`、`enableGhostSent` 等）
  - 權限檢查使用 PZ 全域函式 `isAdmin()`，非管理員不可見
- **伺服器端增加 `setInvisible` 調用**：三層保護 `setGhostMode` + `setZombiesDontAttack` + `setInvisible`
- **定期刷新機制**：每 300 tick 重新發送伺服器指令，防止狀態被引擎重置
- **三語翻譯**：管理員選單 UI 支援英文、繁體中文、簡體中文

### 變更
- 翻譯文案更新：「無敵狀態」→「隱身保護」，「你現在可以被看見了」→「隱身保護已結束」

## [1.3.1] - 2026-04-03

### 修復
- **多人伺服器保護完全無效**：修復 `sendClientCommand` 缺少 `player` 參數導致伺服器端從未執行保護的嚴重問題
  - 根本原因：所有 `sendClientCommand` 呼叫皆缺少第一個 `player` 參數（3 參數 vs 官方規範的 4 參數），導致指令被靜默丟棄
  - 影響：多人伺服器上倒計時和半透明效果正常顯示（客戶端），但 `setGhostMode()` / `setZombiesDontAttack()` 從未在伺服器端執行，玩家仍會被殭屍攻擊
  - 解決方案：所有 `sendClientCommand` 呼叫修正為 `sendClientCommand(player, module, command, args)` 4 參數格式

## [1.3.0] - 2026-04-03

### 修復
- **管理員幽靈模式卡死**：修復 God Mode 管理員登入後永久卡在隱身狀態的問題
  - 根本原因：`GhostCountDown()` 偵測到 `isGodMod()` 為 true 時直接 `return`，導致倒計時永遠不會執行，幽靈模式無法解除
  - 解決方案 1：`init()` 新增 God Mode 前置檢查，God Mode 玩家直接跳過保護啟動
  - 解決方案 2：`GhostCountDown()` 中 God Mode 玩家立即清除幽靈狀態（安全網，處理保護期間切換 God Mode 的情況）

### 變更
- **本地化格式升級**：翻譯檔案從 `.txt`（Lua table）格式遷移至 `.json` 格式，符合 B42.15+ 規範
  - `Sandbox_XX.txt` → `Sandbox.json`
  - `UI_XX.txt` → `UI.json`
  - 影響語言：EN、CH、CN
- **版本需求更新**：`versionMin` 從 42.13.1 提升至 42.16.1

## [1.2.0] - 2026-01-29

### 修復
- **多人伺服器非管理員玩家保護無效**：修復一般玩家登入後保護完全不生效的問題
  - 根本原因 1：Lua 函式前向引用 — `enableProtection()` 和 `OnGhostTick` 在定義前被呼叫，導致 `Object tried to call nil` 崩潰
  - 解決方案：新增前向宣告（`local OnGhostTick` / `local enableProtection`），確保函式在呼叫時已可見
  - 根本原因 2：`setGhostMode()` 從客戶端呼叫對非管理員玩家無效，伺服器拒絕未授權的狀態變更
  - 解決方案：新增伺服器端檔案 `SafeSpawnServer.lua`，透過 `sendClientCommand` / `OnClientCommand` 標準模式，由伺服器端執行 `setGhostMode()` 和 `setZombiesDontAttack()`
  - 根本原因 3：`enableGhost` 指令在 `OnGameStart` 期間發送，此時網路連線尚未建立，指令被靜默丟棄
  - 解決方案：改由 `OnGhostTick` 延遲發送，透過 `enableGhostSent` 旗標確保指令僅發送一次
  - 視覺效果改為基於本地 `enterGhost` 變數，不再依賴伺服器端 `isGhostMode()` 同步狀態

### 新增
- `SafeSpawnServer.lua` — 伺服器端命令處理器，接收客戶端的 ghost mode 請求
- 單人/多人自動切換：多人模式使用 `sendClientCommand`，單人模式保持直接呼叫

### 技術細節
- 架構從純客戶端改為客戶端-伺服器混合模式
- 客戶端負責：倒數計時、視覺效果（alpha）、發送保護請求
- 伺服器端負責：執行 `setGhostMode()` / `setZombiesDontAttack()`（需要伺服器權限）
- 使用 `isClient()` 判斷執行環境，確保單人遊戲相容性

## [1.1.0] - 2026-01-25

### 修復
- **管理員隱身模式衝突**：修復保護結束後無法開啟管理員隱身功能的問題
  - 根本原因：`OnGhostTick` 全域註冊，保護結束後仍持續每 tick 呼叫 `setGhostMode(false)`
  - 解決方案：改為動態註冊/移除 OnTick，僅在保護期間啟用
  - 新增 `isOnTickRegistered` 狀態追蹤，防止重複註冊監聽器
  - 在 `GhostCountDown()` 和 `OnPlayerDeath()` 中加入清理邏輯
  - 保護結束時正確恢復透明度至 1.0

### 變更
- 改善翻譯清晰度：將「老角色」改為「舊角色」，更易理解
- 更新時間單位描述：從「分鐘」改為「遊戲內分鐘」，明確說明為遊戲時間

## [1.0.0] - 2026-01-25

### 新增
- MinidoracatSafeSpawn 首次發布，支援 Project Zomboid Build 42
- **重生保護系統**：玩家重生時提供幽靈模式保護
  - 可設定新角色保護時間（預設：10 遊戲內分鐘）
  - 可設定舊角色保護時間（預設：3 遊戲內分鐘）
  - 可透過沙盒選項啟用/停用功能
- **視覺回饋**：保護期間玩家呈半透明狀態（alpha 0.5）
- **語音倒數**：剩餘保護時間語音提示
- **多人連線支援**：完整支援專用伺服器與多人遊戲
- **多語系支援**：支援英文、簡體中文、繁體中文

### 技術細節
- 移植自 GhostAfterDead（作者：xk）
- 簡化架構：移除技能系統、特性系統、書籍分發
- Build 42 相容：使用 `Events.OnGameStart` 取代已棄用的 `Events.OnLoad`
- 防禦性程式設計：所有外部呼叫皆使用 `pcall()` 包裝，確保多人連線穩定性

---

## 版本歷史摘要

| 版本 | 日期 | 重點 |
|------|------|------|
| 42.20.2-1.5.0 | 2026-08-10 | 倒數改真實秒數（沙盒鍵更名 NormalGhostSeconds/NewStartSeconds，預設 30/60）、非管理員實效隱身（forced 本機旗標，殭屍不再靠近）、新增日文（JP）、死碼清理；對齊 PZ 42.20.2 稽核 |
| 42.19.0-1.4.1 | 2026-06-14 | 修復狀態機互相覆蓋與全 cell 掃描效能、減少 server log 洗版；對齊 PZ 42.19.0 相容性稽核（版本號改採 `{PZ版本}-{Mod版本}` 格式） |
| 1.4.0 | 2026-04-04 | 修復隱形未生效、新增管理員工具選單、翻譯文案更新 |
| 1.3.1 | 2026-04-03 | 修復 sendClientCommand 缺少 player 參數導致多人保護無效 |
| 1.3.0 | 2026-04-03 | 修復管理員幽靈卡死、本地化格式升級至 JSON |
| 1.2.0 | 2026-01-29 | 修復多人伺服器非管理員保護無效 |
| 1.1.0 | 2026-01-25 | 修復管理員隱身模式衝突 |
| 1.0.0 | 2026-01-25 | Build 42 首次發布 |
