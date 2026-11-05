# BOTikor installation guide

**English** | [Español](INSTALACION.md)

This guide takes you from zero to a working bot. Allow about half an hour. You don't need to know how to program, but you will type a few commands on the box; this guide tells you exactly which ones.

**Summary:** you prepare ghostreamy (and, if you want, OSCam), create a bot in Telegram, log in to the box, run one command, choose the language and answer five questions. BOTikor does the rest by itself.

## What you need

- A box with **Enigma2** (OpenSPA, OpenATV, OpenPLi…) with **ghostreamy** installed and working.
- **Telegram** on your phone.
- A computer on the same network as the box, to log in to it over SSH. Windows 10/11 already includes it; so do Mac and Linux.
- The **IP of the box** in your home network (for example `192.168.1.50`). You can see it on the box itself, in Menu → Information → Network, or in your router's web page.

## 1. Prepare ghostreamy

Open the ghostreamy web page in your browser: `http://BOX-IP:3138`. The port may be different if you changed it.

1. **A single user.** BOTikor works with one ghostreamy user. If you have several, decide which one the bot will use and give it a long password.
2. **Enable the option to force a zap before playing a channel** for that user (menu **Users** → edit the user; in the Spanish interface it is called «Forzar zap antes de reproducir un canal»). Without it, `/zap` opens the channel but the TV at home doesn't change.
3. **Have a channel list ready** for that user (menus **Bouquets** and **Lists**). It is the one you will see with `/list`. If it doesn't fit in one Telegram message, the bot sends it in several.
4. **Copy its address.** In **Lists**, next to the list you want to use, press the **"m3u URL"** button. The address is copied to the clipboard; paste it into a notepad, because you will use it in step 6.
   - It appears once for each network of the box; it doesn't matter which one you copy.
   - **That address contains the code of your ghostreamy user: don't share it.**

> The free version of ghostreamy only allows **one client at a time**. BOTikor takes this into account to know which channel each connection is watching.

## 2. Prepare OpenWebIF

OpenWebIF is the box's own web page (`http://BOX-IP`). The bot uses it to switch the box on and off and to know which channel is being watched.

- Tick **"Zap before streaming"** (in the Spanish translation, «Saltar antes del Stream»). It is in the left menu, **Extras → Settings**, which opens directly on the **OpenWebif settings**. It is the other requirement for `/zap` to change the channel on the TV.
- If your OpenWebIF asks for a user name and password, have them at hand: the bot will ask you for them.

## 3. OSCam (optional)

If you use OSCam, `/status` can tell you whether decryption is working: for example, whether the key server is down. To do that it reads the OSCam log, which has to be enabled. In the `oscam.conf` file, `[global]` section, there must be a line like this one:

```
logfile = /tmp/oscam.log
```

Almost every installation already has it. If your log is somewhere else, change it later in `botikor.conf` (line `OSCAM_LOG=`).

## 4. Create your Telegram bot

1. In Telegram, open [@BotFather](https://t.me/BotFather) and send it `/newbot`.
2. It asks for a **name** (the one you will see in the chat, for example "My box") and a **user name**, which must end in `bot` (for example `mybox_home_bot`).
3. It answers with a **token**, a line like `123456789:ABCdefGhIJKlmNoPQRstuVWXyz`. Copy it. **It is the key to your bot: don't give it to anyone.**

## 5. Log in to the box

On the computer, open a terminal (on Windows: Start button → type `PowerShell`) and type, replacing the IP with your box's:

```bash
ssh root@192.168.1.50
```

The first time it asks whether you trust the computer: type `yes`. Then it asks for the box's root password (many images have none; if you don't know it, look in the box's menu, in the network or password settings).

## 6. Download and run BOTikor

Once inside the box, copy and paste this command:

```bash
curl -fsSLo /tmp/botikor.sh https://github.com/vkthor/botikor/releases/latest/download/botikor.sh && bash /tmp/botikor.sh
```

It downloads the latest version and starts it. The first thing it asks is the **language**: `1` (or Enter) for Spanish, `2` for English. Everything the bot says from then on (in the terminal, in Telegram and in its log) will be in that language. Then it asks five questions. Where a value is shown in brackets, just press Enter to accept it.

1. **Bot token**: paste the one from step 4. The bot checks with Telegram that it is valid and tells you its name.
2. **Your chat**: open Telegram and send anything to your bot (for example, `hello`). The script detects it, shows you your name and asks whether it is you. From then on the bot will only obey that chat.
3. **OpenWebIF**: usually you just press Enter. If it asks for a password, it asks you for the user name and the password.
4. **Channel list**: paste the "m3u URL" address from step 1. The script downloads the list and tells you how many channels it has.
5. **ghostreamy ports**:
   - the **internal** one is detected by itself (press Enter);
   - the **external** one is the one you open on the router to watch channels away from home (see step 8). If you are not going to open it, or it is the same, press Enter.

At the end it asks **"Install it?"**. Answer `y` (or press Enter):

- it is copied to `/usr/script/botikor.sh`;
- it is set up to start by itself every time the box is switched on;
- it starts.

You can close the terminal now.

> All your settings are in `/home/root/botikor/botikor.conf`, which only root can read. It contains your token and the address of your list: don't share it.

## 7. Check that it works

In Telegram, your bot will have sent you "BOTikor v… started". Try:

- `/status`: tells you whether everything answers (OpenWebIF, ghostreamy, OSCam, channels…).
- `/list`: your numbered channels.
- `/zap 1`: the TV at home should switch to channel 1.

If something doesn't work, see the [frequently asked questions](FAQ.md).

## 8. Watch channels away from home (optional)

`/channel X` gives you a link to watch channel X on your phone or somewhere else. For it to work outside your network, the router has to let connections to ghostreamy through:

1. In your router's web page, look for **"Port forwarding"** or *NAT*.
2. Create a rule:
   - **external port:** whichever you want, for example `3838`;
   - **destination IP:** the box's;
   - **internal port:** ghostreamy's, usually `3939`.
3. The external port you chose is the one BOTikor must have in `GHOST_PORT_EXT` (question 5 of step 6).

Keep in mind:

- The Internet is full of programs that probe open ports: as soon as you open one, you will see login attempts in the ghostreamy log. That is why the **password of the ghostreamy user has to be a good one**.
- If your provider gives you a **CG-NAT** connection (common on shared fiber and on 4G/5G), opening ports doesn't work. You will have to use Tailscale or other options.
- The `/channel` link contains your home's public IP at that moment, which may change. Ask for it again when you need it.

## Updating

Send `/update_botikor` to the bot. If there is a newer version:

1. it downloads it from this repository;
2. it checks that it hasn't been tampered with;
3. it installs it;
4. it restarts.

Your settings are not touched. The changes in each version are in the [CHANGELOG](../CHANGELOG.md).

## Managing it from the box

| To… | Command |
|---|---|
| Stop the bot | `/etc/init.d/botikor stop` |
| Start it | `/etc/init.d/botikor start` |
| See whether it is running | `/etc/init.d/botikor status` |
| Change the settings or the language (with the bot stopped) | `/usr/script/botikor.sh --setup` |
| Reinstall the automatic start | `/usr/script/botikor.sh --install` |
| See the log | `tail -50 /home/root/botikor/botikor.log` |

## Uninstalling

Run these commands on the box, one after another:

```bash
/etc/init.d/botikor stop
```

```bash
update-rc.d -f botikor remove
```

```bash
rm -f /etc/init.d/botikor /usr/script/botikor.sh /usr/script/botikor.sh.anterior
```

```bash
rm -rf /home/root/botikor
```

The last one also deletes your settings and the log. Then, if you want, delete the bot in Telegram with @BotFather (`/deletebot`).
