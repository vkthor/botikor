# Frequently asked questions and problems

**English** | [Español](FAQ.es.md)

First of all: send **`/status`** to the bot. In one message it tells you what answers and what doesn't, and it usually points straight at the problem. If the bot doesn't even answer that, see the first section.

## The bot doesn't answer

1. **Is it running?** Log in to the box over SSH and run:

   ```bash
   /etc/init.d/botikor status
   ```

   If it says it is not running, start it with `/etc/init.d/botikor start`.
2. **Look at the end of the log:**

   ```bash
   tail -30 /home/root/botikor/botikor.log
   ```

   - **`ERROR: .../botikor.conf does not exist`:** the bot is not set up. Run it by hand once, from a terminal: `/usr/script/botikor.sh`.
   - **`getUpdates without a valid answer`:** the box has no Internet, or the token is no longer valid (for example, because you regenerated it in @BotFather). To change the token, follow these steps:
     1. stop the bot with `/etc/init.d/botikor stop`;
     2. run `/usr/script/botikor.sh --setup`.
3. **Are you writing from the right chat?** The bot only obeys the chat that was set up and doesn't answer anyone else. If you changed your Telegram account, set it up again.
4. **Are two bots using the same token?** For example, another copy of the script on another box. Telegram splits the messages between them and each one only sees some of them. Use a different bot for each box.

## `/zap` answers, but the TV doesn't change channel

The two "zap" settings are missing (see the [installation guide](INSTALL.md), steps 1 and 2):

- in the **ghostreamy user**: the option to force a zap before playing a channel («Forzar zap antes de reproducir un canal» in the Spanish interface);
- in **OpenWebIF**: "Zap before streaming".

**Both** are needed. The bot cannot check whether the TV has changed: it only asks ghostreamy for the channel.

## `/list` says there are no channels, or `/update_channels` fails

- `/status` tells you whether **ghostreamy answers** and where the list comes from.
- **"could not download it (… 401)":** the "m3u URL" is no longer valid. It happens if you changed the password or deleted the list in ghostreamy. Copy it again from ghostreamy → Lists and set up the bot again.
- **"could not download it (… Couldn't connect)":** ghostreamy is not running, or it listens on another port.
- **"what was downloaded is not an m3u list with channels":** the address is not the one from the "m3u URL" button, or the list is empty.

If `/update_channels` fails, the bot keeps using the previous list.

## The `/channel` link doesn't work away from home

- **Is the port open on the router?** A forwarding from the external port (`GHOST_PORT_EXT`) to the ghostreamy port on the box is needed. See the [guide](INSTALL.md), step 8.
- **Do you have CG-NAT?** If your provider doesn't give you a public IP of your own, it is not possible to connect from outside.
- **Has your IP changed?** The link contains the public IP at the moment you asked for it. Ask for it again.
- **Is someone else watching something?** The free version of ghostreamy only allows one client at a time.

## `/status` says OSCam has PROBLEMS

It means that in the last 5 minutes many decryptions have failed ("timeout", "not found"…) or that a reader cannot connect to its server. It is usually a problem with your key server, not with the box or the bot. Check the state of your readers in the OSCam web page.

If it says it **cannot find the OSCam log**, enable it (`logfile` in `oscam.conf`) or put its path in `OSCAM_LOG=` inside `botikor.conf`. If you don't use OSCam, leave `OSCAM_LOG=` empty.

## It doesn't tell me about recordings

The bot watches the `GRABACIONES` folder in `botikor.conf`, which by default is `/hdd/movie`. If your box records somewhere else (a USB stick, a network disk…), change that line and restart the bot. `/status` tells you whether the folder exists.

## How do I change the settings?

With the bot stopped:

```bash
/etc/init.d/botikor stop
```

```bash
/usr/script/botikor.sh --setup
```

It asks you the questions again, with your current values as defaults. You can also edit `/home/root/botikor/botikor.conf` by hand and restart the bot. The format and the meaning of each line are in [`botikor.conf.ejemplo`](../botikor.conf.ejemplo).

## How do I change the bot's language?

With `--setup` (see the previous question): the first question is the language. Answer `2` for English or `1` for Spanish and press Enter on the others to leave them as they are. At the end, answer `y` to "Install it?", so that the box's startup script also uses the new language.

Another way: change the `IDIOMA=` line in `botikor.conf` (`en` or `es`) and restart the bot with `/restart_bot`.

Commands are understood in both languages whichever one you chose: `/list` and `/lista` do the same.

## Can I use the bot from several chats or with several people?

No: it obeys a single chat, yours. Messages from any other chat are ignored (and noted in the log).

## Can I go back to a previous version?

Yes: `/downgrade` tells you which versions are published, and `/downgrade v1.0.0` installs that one. Also, every update leaves the previous version in `/usr/script/botikor.sh.anterior`. v1.0.0 only speaks Spanish.

## What happens if the power goes out or I reboot the box?

The bot starts by itself with the box. It remembers where it was reading messages, so it doesn't repeat old orders (for example, a "power off" it has already carried out).
