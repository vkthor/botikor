# BOTikor — contexto del proyecto (léelo entero al empezar)

Responde siempre en español, directo y preciso. Autor: Víctor Cruz (VkThor). Si existe `CLAUDE.local.md` (no se sube a git), léelo también: tiene las preferencias del dueño y el acceso a su instalación.

## Qué es
`botikor.sh`: bot de Telegram en bash (con Python embebido) que corre como root en un decodificador Enigma2 (Octagon SF8008, OpenSPA 8.3) con el plugin ghostreamy. Lista canales, da URLs de streaming, cambia de canal, enciende/apaga, avisa de grabaciones y de streams, y se actualiza solo. Lo usan también otras personas con configuraciones distintas. Arquitectura, comandos, convenciones y limitaciones: `ARQUITECTURA.md` (leer antes de tocar código).

## Estado
- Todo es **beta**. La versión actual es la **1.0.0** (aún sin publicar).
- La primera versión publicada en GitHub será la **1.0.0** (decidido por Víctor). No llevar changelog hasta entonces.
- En el repositorio todo se llama **botikor** (script `botikor.sh`, directorio `/home/root/botikor`, log `botikor.log`). No añadir referencias a nombres antiguos del proyecto: lo relativo a versiones anteriores va en `CLAUDE.local.md`.
- **Licencia: GPL-3.0** (decidida por Víctor). Falta añadir el fichero LICENSE y las cabeceras.
- Repositorio: `vkthor/botikor` en GitHub, **privado** hasta terminar la Fase 0 y revisar que no quede nada privado.

## Decisiones tomadas
1. La cabecera larga NO va en el `.sh`; la documentación vive en Markdown aparte. Sí se mantienen los comentarios por bloque y las notas «LEER ANTES DE EDITAR».
2. Publicado en GitHub: sin secretos; los pone el usuario. La configuración inicial la hace **el propio script** la primera vez que se lanza a mano desde una terminal (`[ -t 0 ]`; en un arranque sin terminal nunca pregunta), sin script instalador aparte. Va antes del bucle y antes de redirigir la salida al log. Valida el token con `getMe`, averigua el ID de chat pidiendo al usuario que escriba al bot (`getUpdates`) y guarda `botikor.conf` con chmod 600.
3. La configuración pasa a un fichero aparte (`botikor.conf`): elimina `inyectar_config()` y el problema de contraseñas con `$` o `"` (hoy se escriben entre comillas dobles sin escapar dentro del código).
4. **No usar DDNS** para `canal X`: el bot comparte a propósito la IP pública variable, no un nombre que apunte siempre al dueño.
5. En la guía de instalación y el FAQ: tutorial nuevo (el viejo `botikor-tutorial_v1.1.pdf` está obsoleto).
6. `zap` se queda como está (pide 3 s de stream a ghostreamy). Requisito de instalación: «Forzar zap antes de reproducir un canal» activado en el usuario de ghostreamy **y** «zap before streaming» activado en OpenWebIF del deco. Se comprobó que sin ello el stream se abre pero el deco no cambia de canal. Descartado depender de los picons de `lista.m3u8` (no todas las instalaciones los tienen igual).

## Plan por fases
- **Fase 0 — seguridad de descargas/actualizaciones** (obligatoria antes de publicar). **Código hecho y probado** (2026-11-03): `actualizar_botikor`/`downgrade_botikor` descargan de las releases de `REPO_GITHUB` por HTTPS (`--proto`/`--proto-redir '=https'`), comprueban la huella SHA-256 (`descargar_verificado`), `bash -n` y la versión. Las versiones se publican con `herramientas/publicar_version.sh`. Probado con 20 casos contra un servidor local que imita GitHub, en el PC y dentro del deco. **Pendiente:** prueba real contra GitHub, que solo es posible cuando el repositorio sea público (las releases de un repositorio privado piden contraseña). Orden: repositorio público → release v1.0.0 → paso de las instalaciones existentes (ver `CLAUDE.local.md`).
- **Fase 1 — configuración:** `botikor.conf`, configuración inicial en el propio script, detectar `GHOST_PORT_INT` leyendo las URLs de `lista.m3u8`, migración desde la configuración incrustada.
- **Fase 2 — funciones:** `actualizar_canales` que descargue la lista desde ghostreamy; carpeta de grabaciones configurable (hoy `/hdd/movie` y `cut -c 28-` fijos); comando `/estado` (versión, tiempo en marcha, OpenWebIF y ghostreamy alcanzables, canales, IP pública).
- **Fase 3 — documentación:** README, guía de instalación, FAQ, SECURITY.md, LICENSE (GPL-3.0). Requisitos de ghostreamy (los dos ajustes de zap, usuario dedicado, un cliente a la vez en la versión gratuita).
- **Fase 4 — repositorio:** estructura, shellcheck/CI, release v1.0, instalación con un solo comando.

## Hechos técnicos importantes (verificados en un deco real)
- ghostreamy 3.1.5 escucha por defecto en el **puerto 3138** (HTTP; `HTTP_PORT=3138` en `/etc/enigma2/ghostreamy.env`, HTTPS 3139 desactivado). El script usa `GHOST_PORT_INT=3138` y `GHOST_PORT_EXT` (puerto que se expone en el router, 3838 en la instalación de referencia).
- Los puertos expuestos reciben visitas de escáneres de internet (se vieron peticiones a `/` y `/login`, respondidas con 401). Tenerlo en cuenta en la guía de seguridad.
- El `lista.m3u8` de ghostreamy tiene cada canal dos veces (normal y `?t=transcoding`), con `tvg-name`; algunas líneas vienen truncadas a mitad de carácter UTF-8 (por eso `errors="replace"`). Hay canales IPTV con picon de otro formato.
- El awk de busybox no admite `%*d`. `printf -v` exige bash. No hay `timeout` fiable en busybox.
- Formato de grabaciones asumido: `/hdd/movie/AAAAMMDD HHMM - ...` (de ahí `cut -c 28-`).
- Detección de streams: awk sobre `/proc/net/tcp(6)` para los puertos 8001 (nativo Enigma2) y el de ghostreamy; una conexión a ghostreamy solo se anuncia si OpenWebIF (`Streaming_list`) tiene un stream detrás.
- `parar_streams` fabrica TCP RST (AF_PACKET + raw socket).
- Versión gratuita de ghostreamy: un solo cliente a la vez.

## Cómo probar
Sin el deco: extraer funciones con `sed -n '/^nombre() {/,/^}/p'`, stubs de `registrar`, `telegram`, `curl`, `wget`; para un `case` del despachador, extraer con awk desde la etiqueta hasta su `;;`. Siempre `bash -n`.

## Reglas
- No guardar ni imprimir tokens, contraseñas, IPs públicas ni datos de la red de nadie en ficheros del repositorio. Todo eso va en `CLAUDE.local.md` o fuera del repositorio.
- Ficheros en UTF-8 con saltos de línea LF (lo fuerza `.gitattributes`).
- Corregir errores sin comentarios innecesarios.
