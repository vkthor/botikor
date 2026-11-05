# Security

**English** | [Español](SECURITY.es.md)

BOTikor runs as **root** inside the box and controls it over Telegram. It is worth knowing what it protects and what it doesn't.

## How to report a security problem

If you find a vulnerability, **don't open a public issue**. Use the **"Report a vulnerability"** button in the *Security* tab of this repository (GitHub private reporting). Explain what you found and how to reproduce it. We will answer as soon as we can; this is a personal project with no guaranteed response times.

## What the bot does to protect you

- **A single authorized chat.** It only obeys the chat set in `ID`. Messages from any other chat are ignored and noted in the log.
- **Verified updates.** `/update_botikor` and `/downgrade` only download from this repository's releases and only over HTTPS; not even a redirect can drop to HTTP. Before installing, the bot checks three things:
  - the SHA-256 checksum published next to the script;
  - that it has no syntax errors;
  - the version.

  If anything doesn't match, it installs nothing.
- **Secrets don't go to the log.** The bot token and the OpenWebIF password are never written to the log, which is what `/log` sends. Of web addresses (the ghostreamy list address and the `/channel` links, which contain the user's code) only the server and port are noted. The log does contain your public IP: keep that in mind if you share it to ask for help.
- **Settings kept apart and protected.** They are in `botikor.conf` with permissions 600 (root only) and the bot never runs it: it only reads the keys it knows. The published script contains nobody's data.
- **Outgoing connections only.** The bot asks Telegram every few seconds; it doesn't open any port on the box or on the router.

## What it does NOT protect (and what to do)

- **Whoever has your token controls the bot.** If you think someone has seen it, revoke it in @BotFather (`/revoke`) and set up the new one.
- **Whoever gets into your Telegram** can switch the box off or ask for links. Turn on Telegram's two-step verification.
- **Updates trust this repository.** The checksum detects downloads that are corrupt or altered on the way, but it doesn't protect you if someone takes over the account that publishes the versions. If you prefer not to depend on that, don't use `/update_botikor` and update by hand, reviewing the code.
- **The ghostreamy port open to the Internet** (for `/channel`) gets visits from programs looking for open ports from day one. Use a long password for the ghostreamy user and don't share the "m3u URL" or the downloaded list: they contain the user's access code.
- **The `/channel` link contains your home's public IP.** Only share it with people you want to know it.
- **`/stop_stream` cuts connections by crafting TCP packets** (*raw* sockets). It needs root and only acts on the streaming ports of the box itself.

## Supported versions

Only the latest published version. Update with `/update_botikor`.
