# Minidoracat Safe Spawn（安全重生保護）

Project Zomboid **Build 42** 安全重生保護模組。玩家登入或重生時獲得暫時的幽靈（ghost / invisible）保護，緩衝期間殭屍不會攻擊；管理員可透過右鍵選單即時切換隱形。所有功能由沙盒選項開關。

> 開發者 / AI agent 請先讀 [AGENTS.md](AGENTS.md)：完整知識庫（架構、初始化流程、慣例、已知問題、版本發布流程、42.20.2 相容性稽核）。

## MOD 資訊

| 項目 | 內容 |
|------|------|
| **名稱** | Minidoracat Safe Spawn |
| **Mod ID** | `MinidoracatSafeSpawn` |
| **Workshop ID** | [`3653490664`](https://steamcommunity.com/sharedfiles/filedetails/?id=3653490664) |
| **Mod 版本** | 42.20.2-1.5.0 |
| **支援版本** | Build 42.16.1+（已對 42.20.2 完成 API 相容性稽核） |
| **作者** | Minidoracat |
| **架構** | client-server 混合（Lua） |
| **移植來源** | GhostAfterDead（作者：xk），已簡化移除技能 / 特性 / 書籍系統 |

## 功能特色

- **登入保護**：玩家登入 / 重生時自動啟用幽靈保護
- **新角色加成**：新角色獲得較長的保護時間（預設 60 秒現實時間）
- **舊角色保護**：回歸角色獲得較短的保護時間（預設 30 秒現實時間）
- **視覺回饋**：保護期間玩家呈半透明（alpha 0.5）
- **倒數提示**：以 HaloNote 顯示剩餘保護時間（不發出聲音吸引殭屍）
- **管理員工具**：管理員右鍵選單可即時切換隱形、查看保護狀態
- **多人連線**：完整支援專用伺服器與多人遊戲
- **多語系**：English (EN)、繁體中文 (CH)、簡體中文 (CN)、日本語 (JP)

## 沙盒選項

| 選項 | 型別 | 預設 | 說明 |
|------|------|------|------|
| 啟用登入保護 | boolean | 開啟 | 重生 / 登入時是否啟用保護 |
| 舊角色保護時間 | integer (1–600) | 30 | 舊角色保護時間（秒，現實時間） |
| 新角色保護時間 | integer (1–600) | 60 | 新角色保護時間（秒，現實時間） |

## 安裝

從 Steam Workshop 訂閱：[Minidoracat Safe Spawn](https://steamcommunity.com/sharedfiles/filedetails/?id=3653490664)，並在遊戲的 Mods 選單中啟用。專用伺服器請將 `MinidoracatSafeSpawn` 加入 `Mods=` 與 `WorkshopItems=` 設定。

## 本地開發

| 工具 | 用途 |
|------|------|
| `link_workshop.bat` | 手動同步、狀態檢查與歸檔卸載實體副本；不建立連結、不要求提權 |
| `PZ_Test.bat` | 暗色點選視窗，啟動前增量同步並記住本專案的選擇；保留 Steam／no-Steam／Debug 與多人組合，詳見 `../pz-family-docs/tools.md` |

若 PZ 不在預設安裝路徑，請用環境變數 `PZ_PATH` 指向遊戲目錄，不必修改共用啟動腳本。

## 專案結構（摘要）

```
MOD/MinidoracatSafeSpawn/Contents/mods/MinidoracatSafeSpawn/42/   # PZ 模組根目錄
├── mod.info
├── media/sandbox-options.txt                                     # 3 個沙盒選項
└── media/lua/
    ├── client/SafeSpawnMain.lua                                  # 客戶端主邏輯
    ├── server/SafeSpawnServer.lua                                # 伺服器端命令處理
    └── shared/Translate/{EN,CH,CN}/{Sandbox,UI}.json            # 三語翻譯
```

完整結構與檔案說明見 [AGENTS.md](AGENTS.md)。

## 版本發布

發布新版本須同步更新 7 個檔案（兩個 `mod.info` + `workshop.txt` + `STEAM_DESCRIPTION.md` + `STEAM_DESCRIPTION_EN.md` + `README.md` + `CHANGELOG.md`），並以 `scripts/gen_steam_changelog.py` 產生 `STEAM_CHANGELOG.md`。詳細流程見 [AGENTS.md](AGENTS.md) 的「版本發布流程」。更新紀錄見 [CHANGELOG.md](CHANGELOG.md)。

## 致謝

- 原始概念與實作移植自 **GhostAfterDead**（作者：xk）。

### 發布到 Workshop

雙擊 `Publish_Workshop.bat`：先確認 Steam 用戶端已以作者帳號登入（未登入會喚起 Steam 並等你登入後重試），
再選擇更新 MOD 內容（含 `STEAM_CHANGELOG.md` 更新說明）／GIF 封面／簡介／全部；提交後回查 Steam，
任一不符即以非零碼結束。設定在 `scripts/workshop_publish.json`（Workshop ID、簡介語言槽來源、GIF 路徑）。

```
uv run --no-project python -B scripts/publish_workshop.py --mode all --yes       # 自動化／AI；或 content / preview / description
uv run --no-project python -B scripts/publish_workshop.py --mode all --dry-run   # 只檢查、顯示計畫
```

退出碼：`0` 成功／`2` 參數或取消／`3` 未登入、帳號不是擁有者／`4` 前置檢查失敗／`5` 提交失敗／`6` 已提交但回查不符。
網頁動態封面放 `MOD/<資料夾>/workshop/preview.gif`（不在 `Contents/`，不會下載給玩家）；遊戲內上傳器仍用 `preview.png`，
且每次會把網頁封面覆回靜態，需要動態封面時一律改用本工具發布。

## 授權

本專案以 [MIT License](LICENSE) 釋出，copyright 2026 Minidoracat。

MIT 覆蓋 Minidoracat 自有著作（MOD 程式碼與資料定義、`scripts/` 工具、專案文件，
以及依自訂提示詞產製的原創概念封面美術 `preview.png`／`poster.png`／`workshop/preview.gif`）。
下列內容不在 MIT 範圍，完整界定見 [NOTICE](NOTICE)：

- **Project Zomboid** 引擎、API、遊戲素材與商標屬 The Indie Stone；Steamworks API 屬 Valve，兩者皆不隨本專案散布。
- **移植來源** Steam Workshop id 2772690680「无敌2.0 GhostAfterDeath」（Workshop 擁有者：多罗猫；
  本專案程式碼內沿用的署名為「xk」）—— 該作品未找到任何可覆蓋再散布的授權聲明，
  本專案不對其原始著作主張任何授權；現行程式碼已大幅改寫，MIT 僅就改寫部分主張權利。
