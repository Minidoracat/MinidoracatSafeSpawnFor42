<!-- Steam 討論區貼文稿源（英文）；簡介只放摘要，詳細內容以本串為準 -->
<!-- 討論串網址：https://steamcommunity.com/workshop/filedetails/discussion/3653490664/586187095760095658/ -->
<!-- 標題：📖 Safe Spawn Guide: Protection, Settings & Known Limitations -->

[b]繁體中文版：[/b][url=https://steamcommunity.com/workshop/filedetails/discussion/3653490664/586187095760095624/]Safe Spawn 完整說明：保護機制、設定與已知限制[/url]

[h2]🚀 Quick start[/h2]
[list]
[*] Requires Build 42.16.1+ and no other mods. Works in singleplayer, multiplayer and on dedicated servers; in multiplayer the server must enable this mod.
[*] Languages: Traditional Chinese, Simplified Chinese, English, Japanese, Korean, Russian, Spanish, Portuguese, Turkish, French, Polish, German (please report any translation issues).
[*] Applies to every player; no admin privileges needed.
[/list]
[olist]
[*] Subscribe and enable the mod (in multiplayer, the server owner adds it to the server).
[*] Protection starts automatically when you log in or respawn: your character turns semi-transparent and the remaining seconds appear overhead.
[*] Once "Spawn protection ended" appears overhead, your character is back to normal and zombies notice you as usual.
[*] To change the durations, open the "Safe Spawn Protection" page in Sandbox Options (see "Settings" below).
[/olist]

[h2]🛡️ Features in detail[/h2]
[h3]When protection starts and ends[/h3]
[list]
[*] [b]Start[/b]: turns on automatically when you log in (load a save or join a server) and when you respawn as a new character after dying. It does not turn on if "Enable Ghost on Spawn" is off.
[*] [b]End[/b]: ends automatically when the countdown reaches 0; "Spawn protection ended" appears overhead and the transparency goes away.
[*] [b]Death[/b]: dying clears all protection state, and your new character gets a fresh protection period.
[/list]

[h3]What zombies do during protection[/h3]
[list]
[*] Zombies can't see you or hear your footsteps and won't attack, so they no longer walk up to you; any zombie that targets you keeps losing its target.
[*] In multiplayer, these effects apply to zombies simulated by your own game, which usually includes the ones around your spawn point. See "Known limitations" for the exceptions.
[/list]

[h3]Real-time countdown[/h3]
[list]
[*] Measured in real seconds, so a faster server clock doesn't shorten your protection.
[*] Starts only after loading finishes and you can control your character; loading and connection time don't eat into it.
[/list]

[h3]New vs. returning characters[/h3]
[list]
[*] [b]New character[/b]: a freshly created character (survived less than about 6 in-game minutes) uses "New Character Ghost Time", default 60 seconds.
[*] [b]Returning character[/b]: an existing character logging back in uses "Veteran Ghost Time", default 30 seconds.
[/list]

[h3]Countdown hints[/h3]
[list]
[*] Overhead text shows "Spawn Protection: Ns" every 10 seconds, then every second for the last 5.
[*] It's text only; your character doesn't speak, so no sound attracts zombies.
[/list]

[h3]Semi-transparency[/h3]
Your character is semi-transparent while protected, so you can tell at a glance that protection is still on; it turns opaque again when protection ends.

[h3]Admin tools[/h3]
[list]
[*] Admins (and moderators in multiplayer) get a "SafeSpawn Admin Tools" submenu when right-clicking in the world; regular players don't see it.
[*] [b]Enable / Disable Invisibility[/b]: toggles invisibility manually with no time limit, until you turn it off or your character dies. While it's on, the spawn countdown keeps running but its hints are hidden.
[*] Manual invisibility and spawn protection are independent: turning manual invisibility off while spawn protection is still counting down doesn't cancel spawn protection.
[*] [b]Show Protection Status[/b]: shows the internal state (invisible or not, seconds remaining, etc.) overhead and in the log, which helps with bug reports.
[*] Admin tools don't depend on "Enable Ghost on Spawn" and still work when it's off.
[/list]

[h2]⚙️ Settings (Sandbox Options)[/h2]
Found on the "Safe Spawn Protection" page of Sandbox Options; in multiplayer the server owner sets them.
[list]
[*] [b]Enable Ghost on Spawn[/b]: turns login and respawn protection on or off. Default: on.
[*] [b]Veteran Ghost Time[/b]: protection for returning characters, in real seconds. Default 30, range 1–600.
[*] [b]New Character Ghost Time[/b]: protection for new characters, in real seconds. Default 60, range 1–600.
[/list]
If you edit a dedicated server's sandbox settings file directly, the keys are EnableGhostOnSpawn, NormalGhostSeconds and NewStartSeconds under MinidoracatSafeSpawn.

[h2]⚠️ Known limitations[/h2]
[list]
[*] [b]Other players nearby[/b]: in multiplayer, if another player is right next to your spawn point, zombies simulated by their game aren't affected by your protection and may still notice and attack you. This is an engine limitation: protection state isn't synced to other players' games.
[*] [b]Weaker in singleplayer[/b]: in singleplayer without -debug, the game doesn't allow the invisibility state to be set, so protection only clears zombies' targets on you; zombies may still see you and come closer.
[*] [b]Movement traits[/b]: while protected, your character briefly has vanilla invisibility movement traits, such as no slowdown from terrain or trees and no collision with other characters.
[/list]

[h2]❓ FAQ[/h2]
[b]Q: I still get bitten or attacked during protection?[/b]
A: First update both the game and the mod. Older versions had issues such as protection not working at all in multiplayer and zombies still walking up to you; these were fixed across 1.3.1–1.5.0. If it still happens on the latest version, common causes are:
[list]
[*] Another player is nearby and the attacking zombie is simulated by their game (see "Known limitations").
[*] You're in singleplayer, where protection only clears targets (see "Known limitations").
[*] Protection has already ended: check whether "Spawn protection ended" appeared overhead.
[*] The server doesn't have this mod enabled, or the server owner turned off "Enable Ghost on Spawn".
[/list]
If none of these apply, report it with your log file as described under "How to report".

[b]Q: Our server upgraded from a version before 1.5.0 and the protection time looks wrong?[/b]
A: Since 1.5.0 the duration unit changed from in-game minutes to real seconds, and the sandbox options were renamed along with it. Old values are ignored and fall back to the new defaults (30/60 seconds) instead of being misread as 3 or 10 seconds. If you had customized the durations, set them again once.

[b]Q: Protection is much shorter than configured and ends after a few seconds?[/b]
A: Before 1.5.0 the timer used in-game minutes, so protection shrank badly on servers with a faster clock. Since 1.5.0 it uses real seconds; update to the latest version and re-set the durations as in the previous answer.

[b]Q: The countdown shows "%1 minutes"?[/b]
A: That's the old text from before 1.5.0; since 1.5.0 it shows the remaining seconds. Update both the game and the mod to the latest version.

[b]Q: Is a log message from this mod?[/b]
A: Every line this mod writes to the log starts with [MinidoracatSafeSpawn]. Messages without that prefix come from other mods or the game itself.

[h2]📝 How to report[/h2]
[list]
[*] [url=https://github.com/Minidoracat/MinidoracatSafeSpawnFor42/issues]GitHub Issues[/url]: include your game and mod versions, singleplayer or multiplayer, what happened, and the log lines containing [MinidoracatSafeSpawn] (players: %USERPROFILE%\Zomboid\console.txt; servers: server-console.txt; remove private server details).
[*] [url=https://discord.gg/Gur2V67]Discord[/url]
[/list]
