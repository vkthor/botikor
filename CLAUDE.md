# BOTikor — contexto del proyecto (léelo entero al empezar)

Responde siempre en español, directo y preciso. Autor: Víctor Cruz (VkThor). Si existe `CLAUDE.local.md` (no se sube a git), léelo también.

## Qué es
`botikor.sh`: bot de Telegram en bash (con Python embebido) que corre como root en un decodificador Enigma2 con el plugin ghostreamy. Lista canales, da URLs de streaming, cambia de canal, enciende/apaga, avisa de grabaciones y de streams, y se actualiza solo. Habla español o inglés (`IDIOMA` en `botikor.conf`, o el comando `idioma`). Arquitectura, comandos, convenciones y limitaciones: `ARQUITECTURA.md` (leer antes de tocar código).

## Versiones
- Todo es **beta**. Las versiones publicadas están en `CHANGELOG.md` y en las releases de GitHub.
- Para publicar una: subir `VERSION=` en `botikor.sh`, anotarla en `CHANGELOG.md`, commit, push y `herramientas/publicar_version.sh --notas-fichero notas.md`. La versión sólo se sube cuando Víctor lo pide.
- Todo se llama **botikor** (script `botikor.sh`, directorio `/home/root/botikor`, log `botikor.log`).
- **Licencia: GPL-3.0**, como `GPL-3.0-or-later` en la cabecera del script.
- El repositorio es público: antes de subir nada, revisar que no lleve datos privados ni notas internas de trabajo.

## Convenciones de GitHub (iguales en todos los proyectos de vkthor)
- **Versiones con `v` delante** hacia fuera: etiqueta y **título** de la release `vX.Y.Z`, y así también en los mensajes del bot y en `downgrade`. La línea `VERSION="X.Y.Z"` del script va sin `v` (así la leen las instalaciones de la v1.0.0 al actualizarse).
- **Documentación en inglés y en español**, inglés por defecto: `README.md` / `README.es.md`, `docs/INSTALL.md` / `docs/INSTALACION.md`, `docs/FAQ.md` / `docs/FAQ.es.md`, `SECURITY.md` / `SECURITY.es.md`, con el enlace para cambiar de idioma arriba (`**English** | [Español](README.es.md)`). **Cualquier cambio se hace en los dos.** `ARQUITECTURA.md` y este fichero, sólo en español.
- **Notas de cada release** en los dos idiomas: primero un bloque `**English**` y después `**Español**`, cada uno con una línea de resumen, los cambios en viñetas y cómo instalar o actualizar, con enlace al README de su idioma.
- **Mensajes de commit** que describan el cambio, sin referencias a planes o fases internas.
- En español, «sólo» con tilde cuando equivale a «solamente».
- **El bot, en los dos idiomas:** cada mensaje nuevo (terminal, Telegram, log) se escribe en español y en inglés (`registrar "…" "…"`, `telegram "…" "…"`, `t`, `decir`; ver ARQUITECTURA.md, «Idioma»), y cada comando nuevo lleva sus dos nombres.

## Decisiones de diseño
1. La documentación vive en Markdown aparte, no en una cabecera larga del `.sh`. Sí se mantienen los comentarios por bloque y las notas «LEER ANTES DE EDITAR».
2. Sin secretos en el repositorio: los pone cada usuario. La configuración inicial la hace **el propio script** la primera vez que se lanza a mano desde una terminal (`[ -t 0 ]`; en un arranque sin terminal nunca pregunta), sin instalador aparte. Valida el token con `getMe`, averigua el ID de chat pidiendo al usuario que escriba al bot (`getUpdates`) y guarda `botikor.conf` con chmod 600.
3. La configuración va en `botikor.conf`, que el script lee línea a línea y nunca ejecuta.
4. **No usar DDNS** para `canal X`: el bot comparte a propósito la IP pública variable, no un nombre que apunte siempre al dueño.
5. `zap` pide 3 s de stream a ghostreamy. Requisito de instalación: «Forzar zap antes de reproducir un canal» activado en el usuario de ghostreamy **y** «zap before streaming» activado en OpenWebIF. Sin ello el stream se abre pero el deco no cambia de canal. No se depende de los picons de `lista.m3u8` (no todas las instalaciones los tienen igual).
6. Requisitos de la guía: un solo usuario de ghostreamy; la «m3u URL» se copia de ghostreamy → Listas y no se comparte (lleva el código del usuario); OSCam con `logfile` activado (por defecto `/tmp/oscam.log`; otra ruta → `OSCAM_LOG`).

## Hechos técnicos (verificados en un deco real: Octagon SF8008, OpenSPA 8.3, ghostreamy 3.1.5)
- ghostreamy escucha por defecto en el **puerto 3138** (HTTP; `HTTP_PORT=3138` en `/etc/enigma2/ghostreamy.env`, HTTPS 3139 desactivado). `GHOST_PORT_EXT` es el puerto que se expone en el router.
- Los puertos expuestos reciben visitas de escáneres de internet (peticiones a `/` y `/login`, respondidas con 401). Tenerlo en cuenta en la guía de seguridad.
- El `lista.m3u8` de ghostreamy tiene cada canal dos veces (normal y `?t=transcoding`), con `tvg-name`; algunas líneas vienen truncadas a mitad de carácter UTF-8 (por eso `errors="replace"`).
- El awk de busybox no admite `%*d`. `printf -v` exige bash. No hay `timeout` fiable en busybox.
- Formato de grabaciones: `AAAAMMDD HHMM - Canal - Título.ts`; en OpenSPA, `AAAAMMDD_HHMM_-_Canal_-_Título.ts`.
- Detección de streams: awk sobre `/proc/net/tcp(6)` para los puertos 8001 (nativo Enigma2) y el de ghostreamy; una conexión a ghostreamy sólo se anuncia si OpenWebIF (`Streaming_list`) tiene un stream detrás.
- `parar_streams` fabrica TCP RST (AF_PACKET + raw socket).
- Versión gratuita de ghostreamy: un solo cliente a la vez.

## Cómo probar
Sin el deco: extraer funciones con `sed -n '/^nombre() {/,/^}/p'`, stubs de `registrar`, `telegram`, `curl`, `wget`; para un `case` del despachador, extraer con awk desde la etiqueta hasta su `;;`. Siempre `bash -n` y `shellcheck -S warning`. Probar los mensajes en los dos idiomas.

## Reglas
- No guardar ni imprimir tokens, contraseñas, IPs públicas ni datos de la red de nadie en ficheros del repositorio. Todo eso, y las notas de trabajo, va en `CLAUDE.local.md` o fuera del repositorio.
- Ficheros en UTF-8 con saltos de línea LF (lo fuerza `.gitattributes`).
- Corregir errores sin comentarios innecesarios.
