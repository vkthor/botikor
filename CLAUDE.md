# BOTikor — contexto del proyecto (léelo entero al empezar)

Responde siempre en español, directo y preciso. Autor: Víctor Cruz (VkThor). Si existe `CLAUDE.local.md` (no se sube a git), léelo también: tiene las preferencias del dueño y el acceso a su instalación.

## Qué es
`botikor.sh`: bot de Telegram en bash (con Python embebido) que corre como root en un decodificador Enigma2 (Octagon SF8008, OpenSPA 8.3) con el plugin ghostreamy. Lista canales, da URLs de streaming, cambia de canal, enciende/apaga, avisa de grabaciones y de streams, y se actualiza solo. Habla español o inglés (`IDIOMA` en `botikor.conf`, desde la v1.0.1). Lo usan también otras personas con configuraciones distintas. Arquitectura, comandos, convenciones y limitaciones: `ARQUITECTURA.md` (leer antes de tocar código).

## Estado
- Todo es **beta**. Versiones publicadas: **v1.0.0** (2026-11-04, sólo español) y **v1.0.1** (2026-11-06, español e inglés). Para publicar otra: subir `VERSION=` en `botikor.sh`, anotarla en `CHANGELOG.md`, commit, push y `herramientas/publicar_version.sh --notas-fichero notas.md`.
- La versión sólo se sube cuando Víctor lo pide. Desde la v1.0.1 hay `CHANGELOG.md` (inglés y español).
- En el repositorio todo se llama **botikor** (script `botikor.sh`, directorio `/home/root/botikor`, log `botikor.log`). No añadir referencias a nombres antiguos del proyecto: lo relativo a versiones anteriores va en `CLAUDE.local.md`.
- **Licencia: GPL-3.0** (decidida por Víctor), puesta como `GPL-3.0-or-later` en la cabecera del script.
- Repositorio: `vkthor/botikor` en GitHub, **público** desde el 2026-11-04 (aviso privado de vulnerabilidades activado). Antes de subir nada, revisar que no lleve datos privados: el historial ya es visible para todos.

## Convenciones de GitHub (iguales en todos los proyectos de vkthor: ping-tray, redes-movil-adb…)
- **Versiones con `v` delante** hacia fuera: etiqueta y **título** de la release `vX.Y.Z` (no «BOTikor X.Y.Z»), y así también en los mensajes del bot y en `downgrade`. La línea `VERSION="X.Y.Z"` del script sigue sin `v` (la leen las instalaciones de la v1.0.0 al actualizarse).
- **Documentación en inglés y en español**, inglés por defecto: `README.md` / `README.es.md`, `docs/INSTALL.md` / `docs/INSTALACION.md`, `docs/FAQ.md` / `docs/FAQ.es.md`, `SECURITY.md` / `SECURITY.es.md`, con el enlace para cambiar de idioma arriba (`**English** | [Español](README.es.md)`). **Cualquier cambio se hace en los dos.** `ARQUITECTURA.md` y este fichero, sólo en español.
- **Notas de cada release** en los dos idiomas: primero un bloque `**English**` y después `**Español**`, cada uno con una línea de resumen, los cambios en viñetas y cómo instalar o actualizar, con enlace al README de su idioma.
- En español, «sólo» con tilde cuando equivale a «solamente» (decisión de Víctor).
- **El bot, en los dos idiomas:** cada mensaje nuevo (terminal, Telegram, log) se escribe en español y en inglés (`registrar "…" "…"`, `telegram "…" "…"`, `t`, `decir`; ver ARQUITECTURA.md, «Idioma»), y cada comando nuevo lleva sus dos nombres.

## Decisiones tomadas
1. La cabecera larga NO va en el `.sh`; la documentación vive en Markdown aparte. Sí se mantienen los comentarios por bloque y las notas «LEER ANTES DE EDITAR».
2. Publicado en GitHub: sin secretos; los pone el usuario. La configuración inicial la hace **el propio script** la primera vez que se lanza a mano desde una terminal (`[ -t 0 ]`; en un arranque sin terminal nunca pregunta), sin script instalador aparte. Va antes del bucle y antes de redirigir la salida al log. Valida el token con `getMe`, averigua el ID de chat pidiendo al usuario que escriba al bot (`getUpdates`) y guarda `botikor.conf` con chmod 600.
3. La configuración pasa a un fichero aparte (`botikor.conf`): elimina `inyectar_config()` y el problema de contraseñas con `$` o `"` (hoy se escriben entre comillas dobles sin escapar dentro del código).
4. **No usar DDNS** para `canal X`: el bot comparte a propósito la IP pública variable, no un nombre que apunte siempre al dueño.
5. En la guía de instalación y el FAQ: tutorial nuevo (el viejo `botikor-tutorial_v1.1.pdf` está obsoleto).
6. `zap` se queda como está (pide 3 s de stream a ghostreamy). Requisito de instalación: «Forzar zap antes de reproducir un canal» activado en el usuario de ghostreamy **y** «zap before streaming» activado en OpenWebIF del deco. Se comprobó que sin ello el stream se abre pero el deco no cambia de canal. Descartado depender de los picons de `lista.m3u8` (no todas las instalaciones los tienen igual).

## Plan por fases
- **Fase 0 — seguridad de descargas/actualizaciones** (obligatoria antes de publicar). **Código hecho y probado** (2026-11-03): `actualizar_botikor`/`downgrade_botikor` descargan de las releases de `REPO_GITHUB` por HTTPS (`--proto`/`--proto-redir '=https'`), comprueban la huella SHA-256 (`descargar_verificado`), `bash -n` y la versión. Las versiones se publican con `herramientas/publicar_version.sh`. Probado con 20 casos contra un servidor local que imita GitHub, en el PC y dentro del deco. **Pendiente:** prueba real contra GitHub, que solo es posible cuando el repositorio sea público (las releases de un repositorio privado piden contraseña). Orden: repositorio público → release v1.0.0 → paso de las instalaciones existentes (ver `CLAUDE.local.md`).
- **Fase 1 — configuración.** **Hecha y probada** (2026-11-03): `botikor.conf` (formato y claves en ARQUITECTURA.md, «Configuración»; ejemplo en `botikor.conf.ejemplo`), `configuracion_inicial` interactiva, `--configurar`, `GHOST_PORT_INT=auto`. Desaparece `inyectar_config()`. OpenWebIF con usuario y contraseña pasa por curl (`WEBIF_AUTH`), porque el `wget -u` anterior no funcionaba con busybox. La migración desde instalaciones anteriores la hace el puente (ver `CLAUDE.local.md`). Probado en el deco: lector con valores con trampa (37 casos), configuración inicial contra un Telegram y un OpenWebIF falsos, arranque con y sin configuración, y las 20 de actualización. No probado: la configuración inicial con un bot real de Telegram.
- **Instalación automática** (adelantada de la Fase 4 por decisión de Víctor). **Hecha y probada** (2026-11-03): al acabar la configuración inicial el script se copia a `/usr/script/botikor.sh`, crea y activa `/etc/init.d/botikor` y se arranca; `--instalar` lo repite. Ver ARQUITECTURA.md, «Instalación». Probado en el deco con `/etc`, `/usr/script` y `/var/run` simulados en `/tmp`.
- **Lista desde ghostreamy. Hecha y probada** (2026-11-03): `GHOSTLIST_URL` (la «m3u URL» de ghostreamy → Listas, pedida siempre a 127.0.0.1), descarga en la configuración inicial y en `actualizar_canales`. `/lista` se parte en varios mensajes si no cabe (decidido en vez de limitar el número de canales). Mensajes a Telegram con `--data-urlencode` (antes un `+` llegaba como espacio). Ver ARQUITECTURA.md, «Lista de canales».
- **`/estado` y carpeta de grabaciones (`GRABACIONES`). Hechos y probados** (2026-11-03) con un bot de prueba en el deco (Telegram falso; OpenWebIF y ghostreamy reales, solo lectura). `/estado` incluye OSCam (`OSCAM_LOG`, leído del log; ver ARQUITECTURA.md, «OSCam»). Con esto la Fase 2 está completa. Los nombres de grabación pasan por `nombre_grabacion` (en OpenSPA los ficheros llevan `_` en vez de espacios).
- **Fase 3 — documentación. Hecha** (2026-11-03; en inglés y español desde la v1.0.1): `README.md`, `docs/INSTALACION.md` (tutorial), `docs/FAQ.md`, `SECURITY.md`, `LICENSE` (texto oficial GPL-3.0 de la API de licencias de GitHub) y aviso `GPL-3.0-or-later` en la cabecera de `botikor.sh`. «Saltar antes del Stream» está en OpenWebIF → Extras → Configuración → «Configuración OpenWebif» (confirmado por Víctor con captura).
- **Fase 4 (pendiente):** activar en GitHub el aviso privado de vulnerabilidades (`SECURITY.md` lo menciona; GitHub solo lo permite en repositorios públicos: hacerlo justo al publicar, con `gh api -X PUT repos/vkthor/botikor/private-vulnerability-reporting`), shellcheck/CI (hecho: `.github/workflows/comprobaciones.yml`, en verde), release v1.0.0, repositorio recreado limpio el 2026-11-04 (7 commits, sin el commit viejo; respaldo en `privado/botikor-respaldo.bundle`), y después el paso de las instalaciones existentes (ver `CLAUDE.local.md`).
- **Requisitos para el tutorial** (decididos con Víctor): un solo usuario de ghostreamy; «Forzar zap antes de reproducir un canal» en ese usuario y «zap before streaming» en OpenWebIF; la «m3u URL» se copia de ghostreamy → Listas y no se comparte (lleva el código del usuario). OSCam con `logfile` activado (por defecto `/tmp/oscam.log`; otra ruta → `OSCAM_LOG` en botikor.conf).
- **Fase 2 — funciones:** hecha (ver más abajo).
- **Fase 3 — documentación:** hecha (ver más abajo).
- **Fase 4 — repositorio:** estructura, shellcheck/CI, release v1.0, instalación con un solo comando.

## Hechos técnicos importantes (verificados en un deco real)
- ghostreamy 3.1.5 escucha por defecto en el **puerto 3138** (HTTP; `HTTP_PORT=3138` en `/etc/enigma2/ghostreamy.env`, HTTPS 3139 desactivado). El script usa `GHOST_PORT_INT=3138` y `GHOST_PORT_EXT` (puerto que se expone en el router, 3838 en la instalación de referencia).
- Los puertos expuestos reciben visitas de escáneres de internet (se vieron peticiones a `/` y `/login`, respondidas con 401). Tenerlo en cuenta en la guía de seguridad.
- El `lista.m3u8` de ghostreamy tiene cada canal dos veces (normal y `?t=transcoding`), con `tvg-name`; algunas líneas vienen truncadas a mitad de carácter UTF-8 (por eso `errors="replace"`). Hay canales IPTV con picon de otro formato.
- El awk de busybox no admite `%*d`. `printf -v` exige bash. No hay `timeout` fiable en busybox.
- Formato de grabaciones: `AAAAMMDD HHMM - Canal - Título.ts`; en OpenSPA, `AAAAMMDD_HHMM_-_Canal_-_Título.ts`.
- Detección de streams: awk sobre `/proc/net/tcp(6)` para los puertos 8001 (nativo Enigma2) y el de ghostreamy; una conexión a ghostreamy solo se anuncia si OpenWebIF (`Streaming_list`) tiene un stream detrás.
- `parar_streams` fabrica TCP RST (AF_PACKET + raw socket).
- Versión gratuita de ghostreamy: un solo cliente a la vez.

## Cómo probar
Sin el deco: extraer funciones con `sed -n '/^nombre() {/,/^}/p'`, stubs de `registrar`, `telegram`, `curl`, `wget`; para un `case` del despachador, extraer con awk desde la etiqueta hasta su `;;`. Siempre `bash -n`.

## Reglas
- No guardar ni imprimir tokens, contraseñas, IPs públicas ni datos de la red de nadie en ficheros del repositorio. Todo eso va en `CLAUDE.local.md` o fuera del repositorio.
- Ficheros en UTF-8 con saltos de línea LF (lo fuerza `.gitattributes`).
- Corregir errores sin comentarios innecesarios.
