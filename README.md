# BOTikor

**English** | [Español](README.es.md)

A Telegram bot to control an **Enigma2** set-top box with the **ghostreamy** plugin from your phone, wherever you are.

You write to the bot and it gives you the links to watch your channels away from home, changes the channel, switches the box on or off and tells you when a recording starts or when someone connects to a stream.

The bot speaks **English or Spanish**: you choose when you install it, and you can change it at any time with `/language`.

> **Status: beta.** It works every day on OpenSPA 8.3 with ghostreamy 3.1.5. It should work on other boxes and images that meet the requirements, but it has not been tested on them.

## What it does

- **Channel list** (`/list`) and **a link to watch them away from home** (`/channel 5`), in VLC or any similar player.
- **Changes the channel** on the TV at home (`/zap 5`).
- **Switches the box on, to standby, off or reboots it.**
- **Tells you** when a recording starts and when someone starts or stops watching a stream (with their IP and the channel).
- **Cuts the streams** in progress (`/stop_stream`).
- **`/status`**: at a glance, whether everything works (OpenWebIF, ghostreamy, OSCam, channels, recordings…).
- **Updates itself** from this repository when you ask it to.

It only obeys **your** Telegram chat; messages from anyone else are ignored.

## Requirements

- A box with **Enigma2** and root access (SSH or telnet), with `bash`, `curl` and `python3` (current images have them).
- **ghostreamy** installed, with **a single user**, and with these two settings enabled (without them `/zap` may not change the channel):
  - in the ghostreamy user, the option to **force a zap before playing a channel** (in the Spanish interface, *«Forzar zap antes de reproducir un canal»*);
  - in OpenWebIF: **"Zap before streaming"**.
- A **Telegram bot** of your own, created with [@BotFather](https://t.me/BotFather).
- Optional: **OSCam** with its log enabled, so that `/status` can tell whether decryption is working.
- Optional: the ghostreamy port opened on the router, to watch channels away from home with `/channel`.

## Quick install

Log in to the box over SSH and run:

```bash
curl -fsSLo /tmp/botikor.sh https://github.com/vkthor/botikor/releases/latest/download/botikor.sh && bash /tmp/botikor.sh
```

The script first asks for the language (English or Spanish) and then five questions (bot token, your chat, OpenWebIF, channel list and ports). Then it installs itself and starts. When it is done, it sends you a Telegram message.

Step-by-step installation: **[installation guide](docs/INSTALL.md)**.

## Commands

They can be typed with or without `/`, in upper or lower case. If you send it anything else, the bot answers with the list of commands.

Each command has an English and a Spanish name, and the bot accepts both whatever the language you chose. The help and the messages use the names of your language.

| Command | Spanish name | What it does |
|---|---|---|
| `/list` | `/lista` | Numbered channel list. |
| `/channel X` | `/canal X` | Link to watch channel X away from home (and the transcoded one, if there is one). |
| `/zap X` | `/zap X` | Puts channel X on the box. |
| `/update_channels` | `/actualizar_canales` | Downloads the channel list from ghostreamy again. |
| `/status` | `/estado` | Summary of whether everything works. |
| `/language X` | `/idioma X` | Changes the bot's language right away: `/language en` (English) or `/language es` (Spanish). |
| `/log` | `/log` | Sends you the bot's log (to look for problems). |
| `/power_on` | `/encender` | Takes the box out of standby. |
| `/standby` | `/suspender` | Puts the box in standby (the bot keeps working). |
| `/power_off` | `/apagar` | Deep standby: the bot stops working until you switch the box on. |
| `/stop_stream` | `/parar_stream` | Cuts the streams in progress. |
| `/reboot_box` | `/reiniciar_deco` | Reboots the box. |
| `/restart_bot` | `/reiniciar_bot` | Restarts only the bot. |
| `/update_botikor` | `/actualizar_botikor` | Installs the latest published version, if there is a newer one. |
| `/downgrade X` | `/downgrade X` | Installs a specific version, for example `/downgrade v1.0.0` (without X, it tells you which ones there are). |
| `/exit` | `/exit` | Closes the bot. |

## Settings

Everything about your installation is in `/home/root/botikor/botikor.conf`, which only root can read. The language is the `IDIOMA=` line (`en` or `es`); the easiest way to change it is `/language` in Telegram. To change anything else:

```bash
/etc/init.d/botikor stop
```

```bash
/usr/script/botikor.sh --setup
```

It asks the questions again, starting with the language, with your current values as defaults. You can also edit the file by hand and restart the bot. What each line means: [`botikor.conf.ejemplo`](botikor.conf.ejemplo).

## More information

- [Installation guide](docs/INSTALL.md)
- [Frequently asked questions and problems](docs/FAQ.md)
- [Security](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [How it works inside](ARQUITECTURA.md) (in Spanish), for anyone who wants to touch the code

## License

BOTikor is free software under the [GNU General Public License, version 3 or later](LICENSE). You can use it, study it, modify it and share it; if you distribute a modified version, it has to stay free under the same license. It comes **without any warranty**.

ghostreamy, OSCam, Enigma2 and OpenWebIF are third-party projects, independent from this one.

© 2026 Víctor Cruz
