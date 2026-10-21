<!-- 指南網址：https://steamcommunity.com/sharedfiles/filedetails/?id=3817838849 -->
<!-- Steam guide source (English): the full reference for this mod; the Workshop description only summarizes. Format and sync: pz-family-docs/release.md「完整說明：Steam 指南」 -->
<!-- 標題：📖 Safe Spawn Mod Guide: Protection, Settings & Known Limitations -->
<!-- 摘要：Guide to the Minidoracat Safe Spawn mod: when login and respawn protection starts and ends, what zombies do while you're protected, admin tools, sandbox options, known limitations and FAQ. -->
=== 🚀 Quick start
[b]繁體中文版：[/b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=3817838819]安全重生保護 MOD 完整說明[/url]

The mod on Steam Workshop:
https://steamcommunity.com/sharedfiles/filedetails/?id=3653490664
[list]
[*] [b]Requirements[/b]: Build 42.16.1+, no other mods.
[*] [b]Game modes[/b]: singleplayer, multiplayer and dedicated servers; in multiplayer the server must enable this mod.
[*] [b]Who's protected[/b]: every player; no admin privileges needed.
[*] [b]Languages[/b]: Traditional Chinese, Simplified Chinese, English, Japanese, Korean, Russian, Spanish, Portuguese, Turkish, French, Polish, German (please report any translation issues).
[/list]
[olist]
[*] [b]Enable it[/b]: subscribe and enable the mod (in multiplayer, the server owner adds it to the server).
[*] [b]Automatic start[/b]: protection starts when you log in or respawn; your character turns semi-transparent and the remaining seconds appear overhead.
[*] [b]Protection ends[/b]: once "Spawn protection ended" appears overhead, your character is back to normal and zombies notice you as usual.
[*] [b]Change the durations[/b]: open the "Safe Spawn Protection" page in Sandbox Options (see "Sandbox options").
[/olist]
=== 🧰 When protection starts and ends
[h3]Start and end[/h3]
[list]
[*] [b]Start[/b]: turns on automatically when you log in (load a save or join a server) and when you respawn as a new character after dying. It does not turn on if "Enable Ghost on Spawn" is off.
[*] [b]End[/b]: ends automatically when the countdown reaches 0; "Spawn protection ended" appears overhead and the transparency goes away.
[*] [b]Death[/b]: dying clears all protection state, and your new character gets a fresh protection period.
[*] [b]Limit[/b]: the server owner can limit how many times a returning character gets login protection within a set period (multiplayer only; no limit by default). When a login does get protection, the countdown text gets a second line, "Spawn protection uses left: X (+1 at HH:MM)", where HH:MM is the time on your computer's clock. Once the limit is used up, you get no protection for that login and "Spawn protection limit reached. Available again at HH:MM (in about N min)" appears overhead. New characters and respawns after death aren't affected.
[*] [b]Already invisible[/b]: if your character is already invisible when you log in or respawn (for example, an admin turned it on in the vanilla admin panel) and your role is allowed to be invisible, protection doesn't start and there's no countdown. Your invisibility stays as it is, with a one-time "Invisibility ENABLED" note overhead.
[/list]
[h3]New vs. returning characters[/h3]
[table]
[tr][th]Character[/th][th]Condition[/th][th]Option used[/th][th]Default[/th][/tr]
[tr][td]New[/td][td]Freshly created (survived less than about 6 in-game minutes)[/td][td]New Character Ghost Time[/td][td]60 s[/td][/tr]
[tr][td]Returning[/td][td]Existing character logging back in[/td][td]Veteran Ghost Time[/td][td]30 s[/td][/tr]
[/table]
[h3]Real-time countdown[/h3]
[list]
[*] [b]Real seconds[/b]: a faster server clock doesn't shorten your protection.
[*] [b]When it starts counting[/b]: only after loading finishes and you can control your character; loading and connection time don't eat into it.
[/list]
=== 🧰 While you're protected
[h3]What zombies do[/h3]
[list]
[*] [b]Can't see or hear you[/b]: zombies can't see you or hear your footsteps and won't attack, so they no longer walk up to you.
[*] [b]Targets cleared[/b]: any zombie that targets you keeps losing its target.
[*] [b]Multiplayer[/b]: these effects apply to zombies simulated by your own game, which usually includes the ones around your spawn point. See "Known limitations" for the exceptions.
[*] [b]Only in your own game[/b]: other players always see you moving normally, and that includes admins.
[/list]
[h3]Countdown hints[/h3]
[list]
[*] [b]Overhead text[/b]: shows "Spawn Protection: Ns" as soon as protection starts, then every 10 seconds, then every second for the last 5. If the server owner set a limit, a second line shows the uses left and when one comes back (see "Limit").
[*] [b]Silent[/b]: it's text only; your character doesn't speak, so no sound attracts zombies.
[/list]
[h3]Semi-transparency[/h3]
[list]
[*] Your character is semi-transparent while protected, so you can tell at a glance that protection is still on; it turns opaque again when protection ends.
[/list]
=== 🧰 Admin tools
[list]
[*] [b]Who sees them[/b]: roles that are allowed to toggle their own invisibility (admin, moderator, GM, observer, or a custom role with that permission) get a "SafeSpawn Admin Tools" submenu when right-clicking in the world; regular players don't see it.
[*] [b]Independent of the protection switch[/b]: they still work when "Enable Ghost on Spawn" is off.
[/list]
[h3]Enable / Disable Invisibility[/h3]
[list]
[*] [b]Same as vanilla[/b]: the same as "Invisible" in the vanilla admin panel: other players can't see you, and it stays on after you log back in until you turn it off.
[*] [b]During the countdown[/b]: you can turn it on then too; the countdown keeps running with its hints hidden, and you stay invisible after protection ends.
[*] [b]Independent[/b]: manual invisibility and spawn protection don't affect each other; turning manual invisibility off while spawn protection is still counting down doesn't cancel spawn protection.
[/list]
[h3]Show Protection Status[/h3]
[list]
[*] Shows the internal state (invisible or not, seconds remaining, etc.) overhead and in the log, which helps with bug reports.
[/list]
[h3]With the vanilla admin panel[/h3]
[list]
[*] If you open the vanilla admin panel while protected, "Invisible" shows as checked (that's the protection); saving the panel then turns invisibility on for real.
[/list]
=== ⚙️ Sandbox options
[list]
[*] [b]Where[/b]: the "Safe Spawn Protection" page of Sandbox Options.
[*] [b]Who sets them[/b]: the server owner, in multiplayer.
[/list]
[table]
[tr][th]Option[/th][th]What it does[/th][th]Default[/th][th]Range[/th][th]Settings file key[/th][/tr]
[tr][td]Enable Ghost on Spawn[/td][td]Turns login and respawn protection on or off[/td][td]On[/td][td]–[/td][td]EnableGhostOnSpawn[/td][/tr]
[tr][td]Veteran Ghost Time[/td][td]Protection for returning characters, in real seconds[/td][td]30[/td][td]1–600[/td][td]NormalGhostSeconds[/td][/tr]
[tr][td]Veteran Ghost Limit[/td][td]How many times a returning character can get protection within the limit window; 0 = no limit; multiplayer only[/td][td]0[/td][td]0–20[/td][td]NormalGhostLimit[/td][/tr]
[tr][td]Veteran Ghost Limit Window[/td][td]Length of the Veteran Ghost Limit window, in real minutes[/td][td]60[/td][td]1–1440[/td][td]NormalGhostWindowMinutes[/td][/tr]
[tr][td]New Character Ghost Time[/td][td]Protection for new characters, in real seconds[/td][td]60[/td][td]1–600[/td][td]NewStartSeconds[/td][/tr]
[/table]
[list]
[*] [b]Settings file keys[/b]: if you edit a dedicated server's sandbox settings file directly, the keys are under MinidoracatSafeSpawn.
[/list]
=== ⚠️ Known limitations
[list]
[*] [b]Other players nearby[/b]: in multiplayer, if another player is right next to your spawn point, zombies simulated by their game aren't affected by your protection and may still notice and attack you. This is an engine limitation: protection state isn't synced to other players' games.
[*] [b]Weaker in singleplayer[/b]: in singleplayer without -debug, the game doesn't allow the invisibility state to be set, so protection only clears zombies' targets on you; zombies may still see you and come closer.
[*] [b]Movement traits[/b]: while protected, your character briefly has vanilla invisibility movement traits, such as no slowdown from terrain or trees and no collision with other characters.
[/list]
=== ❓ FAQ
[h3]I still get bitten or attacked during protection?[/h3]
[list]
[*] First update both the game and the mod. Older versions had issues such as protection not working at all in multiplayer and zombies still walking up to you; these were fixed across 1.3.1–1.5.0.
[*] If it still happens on the latest version, common causes are:
[list]
[*] Another player is nearby and the attacking zombie is simulated by their game (see "Known limitations").
[*] You're in singleplayer, where protection only clears targets (see "Known limitations").
[*] Protection has already ended: check whether "Spawn protection ended" appeared overhead.
[*] The server doesn't have this mod enabled, or the server owner turned off "Enable Ghost on Spawn".
[/list]
[*] If none of these apply, report it with your log file as described under "How to report".
[/list]
[h3]Our server upgraded from a version before 1.5.0 and the protection time looks wrong?[/h3]
[list]
[*] Since 1.5.0 the duration unit changed from in-game minutes to real seconds, and the sandbox options were renamed along with it.
[*] Old values are ignored and fall back to the new defaults (30/60 seconds) instead of being misread as 3 or 10 seconds.
[*] If you had customized the durations, set them again once.
[/list]
[h3]Protection is much shorter than configured and ends after a few seconds?[/h3]
[list]
[*] Before 1.5.0 the timer used in-game minutes, so protection shrank badly on servers with a faster clock.
[*] Since 1.5.0 it uses real seconds; update to the latest version and re-set the durations as in the previous answer.
[/list]
[h3]The countdown shows "%1 minutes"?[/h3]
[list]
[*] That's the old text from before 1.5.0; since 1.5.0 it shows the remaining seconds.
[*] Update both the game and the mod to the latest version.
[/list]
[h3]No protection when I logged in, and the overhead text says the limit is reached?[/h3]
[list]
[*] The server owner turned on "Veteran Ghost Limit": a returning character only gets protection for a few logins within a set period, and once that's used up, the login gets no protection.
[*] The HH:MM in the overhead text is the time on your computer's clock. Log in after that and you'll be protected again.
[*] Reconnecting after a disconnect counts as a login and uses one up.
[*] New characters and respawns after death aren't affected by this limit.
[*] Your character still looks see-through: that's the game's own connection buffer, not this mod's protection. It clears as soon as you take a step, or about 15 seconds after logging in.
[/list]
[h3]Is a log message from this mod?[/h3]
[list]
[*] Every line this mod writes to the log starts with [MinidoracatSafeSpawn].
[*] Messages without that prefix come from other mods or the game itself.
[/list]
=== 💬 How to report
[list]
[*] [b][url=https://github.com/Minidoracat/MinidoracatSafeSpawnFor42/issues]GitHub Issues[/url][/b]: please include
[list]
[*] your game and mod versions
[*] singleplayer or multiplayer
[*] what happened
[*] the log lines containing [MinidoracatSafeSpawn] (players: %USERPROFILE%\Zomboid\console.txt; servers: server-console.txt; remove private server details)
[/list]
[*] [b][url=https://discord.gg/Gur2V67]Discord[/url][/b]
[/list]
