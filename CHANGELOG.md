# Changelog

**English** first, then **Español**.

## v1.0.2 — November 2026

**English**

- New command **`/channel_local X`** (`/canal_local X`): the same two links as `/channel X` (normal and transcoded, in separate messages), but with the box's address in your home network and ghostreamy's internal port, to watch the channel at home without going through the router.
- The bot finds out the box's local IP every time it starts, so nothing is asked during installation and it keeps up with changes. It prefers the `192.168.x.x` addresses; if there are several that could do (for example, cable and Wi-Fi), it asks you in Telegram which one to use and saves your answer as `INTERFAZ_LAN=` in `botikor.conf`. Installations updated from an earlier version don't need to change anything.
- New command **`/lan`**: the box's local IPs and which one is in use. `/lan_N` chooses another one, and `/lan_auto` lets the bot choose again.
- The start-up message now shows the public IP (WAN), the local IP (LAN) in use and, if there are several, every interface. `/status` shows the local IP too.

**Español**

- Comando nuevo **`/canal_local X`** (`/channel_local X`): los mismos dos enlaces que `/canal X` (normal y transcodificado, en mensajes separados), pero con la dirección del deco en la red de casa y el puerto interno de ghostreamy, para ver el canal en casa sin pasar por el router.
- El bot averigua la IP local del deco cada vez que arranca, así que no se pregunta nada en la instalación y sigue los cambios. Prefiere las direcciones `192.168.x.x`; si hay varias que pueden valer (por ejemplo, cable y wifi), te pregunta por Telegram cuál usar y guarda tu respuesta como `INTERFAZ_LAN=` en `botikor.conf`. Las instalaciones que actualicen desde una versión anterior no tienen que cambiar nada.
- Comando nuevo **`/lan`**: las IP locales del deco y cuál está en uso. `/lan_N` elige otra y `/lan_auto` deja que el bot vuelva a elegirla.
- El aviso de arranque muestra ahora la IP pública (WAN), la IP local (LAN) en uso y, si hay varias, todas las interfaces. `/estado` muestra también la IP local.

## v1.0.1 — November 2026

**English**

- The bot now speaks **English or Spanish**. The installation starts by asking for the language (Spanish by default), and everything the bot says follows it: the questions in the terminal, the Telegram messages, the log and the box's startup script. It is saved as `IDIOMA=` in `botikor.conf`; installations that don't have that line keep Spanish.
- New command **`/language X`** (`/idioma X`) to change the language at any time from Telegram: `/language en` or `/language es`. It changes right away, without restarting, and is saved in `botikor.conf`.
- Every command has an English name as well (`/list`, `/channel X`, `/status`, `/power_off`…). Both names work whichever the language; the help shows the ones of the chosen language.
- `--setup` and `--install` work as well as `--configurar` and `--instalar`.
- Versions are written with a `v` in front everywhere (`v1.0.1`), as in the release tags: in `/downgrade` and in the release titles.
- The start-up message shows the day of the week in the bot's language.
- README, installation guide, FAQ and security policy in English and Spanish.

**Español**

- El bot habla ahora **español o inglés**. La instalación empieza preguntando el idioma (español por defecto) y todo lo que dice el bot lo sigue: las preguntas de la terminal, los mensajes de Telegram, el log y el arranque del deco. Se guarda como `IDIOMA=` en `botikor.conf`; las instalaciones que no tienen esa línea siguen en español.
- Comando nuevo **`/idioma X`** (`/language X`) para cambiar el idioma cuando quieras desde Telegram: `/idioma es` o `/idioma en`. Cambia al momento, sin reiniciar, y se guarda en `botikor.conf`.
- Cada comando tiene también un nombre en inglés (`/list`, `/channel X`, `/status`, `/power_off`…). Los dos nombres funcionan sea cual sea el idioma; la ayuda muestra los del idioma elegido.
- `--setup` e `--install` funcionan igual que `--configurar` e `--instalar`.
- Las versiones se escriben con `v` delante en todas partes (`v1.0.1`), como las etiquetas de las releases: en `/downgrade` y en el título de las releases.
- El aviso de arranque pone el día de la semana en el idioma del bot.
- README, guía de instalación, preguntas frecuentes y política de seguridad en inglés y en español.

## v1.0.0 — November 2026

**English**

First public version (beta), in Spanish only.

**Español**

Primera versión pública (beta), sólo en español.
