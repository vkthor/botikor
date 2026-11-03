# BOTikor — arquitectura y notas de desarrollo

Documento para quien vaya a tocar `botikor.sh` (tú dentro de seis meses, un colaborador o una IA). Los comentarios dentro del script explican cada bloque; aquí está la visión de conjunto.

## Qué es

Un único script de bash (con trozos de Python embebidos) que corre como root dentro de un decodificador Enigma2 y lo maneja por Telegram: da URLs de streaming, cambia de canal, enciende y apaga, y avisa de grabaciones y de streams.

No necesita servidor propio ni abrir puertos para Telegram: el bot **pregunta** a Telegram (`getUpdates`) cada pocos segundos y solo hace conexiones de salida. Los puertos que se abren en el router son los de ghostreamy, para ver los canales desde fuera de casa.

## Qué hace

1. Responde a comandos. Solo hace caso al chat cuyo ID coincide con la variable `ID`; los mensajes de cualquier otro chat se ignoran y se anotan en el log.
2. Avisa por su cuenta de su propio arranque, de grabaciones nuevas en `/hdd/movie` y de streams que empiezan y terminan (IP, vía, canal y duración).
3. Se actualiza a sí mismo cuando se le ordena (`actualizar_botikor`, `downgrade X`), descargando de las releases de GitHub por HTTPS y comprobando la huella SHA-256.

## Piezas que intervienen

| Pieza | Papel |
|---|---|
| Enigma2 + OpenWebIF (`127.0.0.1`) | El bot le pregunta qué canal ve cada cliente (`/api/statusinfo`), le da órdenes de encendido/apagado (`/api/powerstate`). |
| ghostreamy (plugin de terceros, no forma parte de este proyecto) | Publica los canales como streams HTTP en el puerto `GHOST_PORT_INT` y genera la lista `lista.m3u8` que lee el bot. La versión gratuita solo admite un cliente a la vez; el reparto de canales de `resolver_canales()` lo asume. |
| Telegram Bot API | El único canal con la persona. |
| ipinfo.io, pool.ntp.org, github.com, api.github.com | Resto de conexiones de salida: IP pública, hora y actualizaciones (releases de `REPO_GITHUB`). |

## Estructura del script (se lee de arriba abajo)

1. **Cabecera**: `VERSION`, `REPO_GITHUB`, directorio de trabajo.
2. **Configuración** (ver «Configuración» más abajo): valores por defecto, `leer_conf`, `guardar_conf`, validaciones, `detectar_puerto_ghost`, `configuracion_inicial`. Corre antes de redirigir la salida al log, porque la configuración inicial habla con la persona por la terminal.
3. **Arranque**: recorte del log (`recortar_log`), redirección de la salida al log, banner.
4. **Funciones de apoyo** (se definen antes de usarse):
   - log y salida: `registrar`, `resumir`, `telegram`, `escapar_html`, `telegram_html`, `telegram_documento`
   - acciones: `powerstate`, `parar_streams`, `obtener_ip_publica`
   - estado de streams: `agregar_linea`, `contar_lineas`, `clave_en`, `duracion_txt`, `lista_activos`, `decodificar_conexiones`, `resolver_canales`
   - canales: `cargar_canales`
   - configuración en uso: comprobación de `TOKEN`/`ID` (sin ellos se cierra), `WEBIF_AUTH`, `fijar_puerto_ghost`
   - actualizaciones: `instalar_script_descargado`, `descargar_verificado`, `version_de`, `actualizar_botikor`, `downgrade_botikor`
   - hora: `sincronizar_hora`
5. **Secuencia de arranque**: `cargar_canales`, `sincronizar_hora`, aviso de «iniciado», IP pública.
6. **Bucle principal** (cada ~5 s): sondeo de Telegram y despacho de comandos, detección de grabaciones, detección de streams, latido, `sleep 5`.

El bucle es secuencial y de un solo hilo a propósito: un comando lento (`parar_stream` tarda hasta ~10 s) retrasa la vigilancia ese rato, pero a cambio todo el estado son unas pocas variables de bash, sin carreras.

## Ficheros

En el directorio de trabajo `/home/root/botikor` (el script hace `cd` a él):

| Fichero | Contenido |
|---|---|
| `botikor.log` | Log. Solo se conservan los `MAX_ARRANQUES` últimos arranques. |
| `botikor.conf` | La configuración de esta instalación (permisos 600; lleva el token). Ver «Configuración». |
| `offset` | Id del siguiente mensaje de Telegram a pedir (sobrevive a reinicios). |
| `lista.m3u8` | Lista de canales de ghostreamy (la prepara la persona). |
| `canales.tsv` | La lista ya digerida: nombre, URL normal, URL transcodificada. |
| `canalnombres`, `canalurls`, `canalurlstrans` | Las tres columnas de `canales.tsv`. La línea N de cada una es el canal N de `/lista`. |
| `listagrabaciones` | Grabaciones ya conocidas (se rehace en cada arranque). |
| `botikor_nuevo.sh`, `botikor_nuevo.sha256`, `botikor_versiones.tmp`, `botikor.log.tmp` | Temporales. |

Fuera de él:

| Ruta | Contenido |
|---|---|
| `SCRIPT_PATH` | El propio script (normalmente `/usr/script/botikor.sh`). |
| `SCRIPT_PATH.anterior` | Copia de la versión previa (la deja cada actualización o downgrade). |
| `/etc/init.d/botikor` | Arranque en cada boot (lo prepara la persona al instalar; ver la guía de instalación). |

## Requisitos del deco

- **bash** (no vale ash: se usan `printf -v`, `${!var}`, `<<<`, `$'..'` y `for ((..))`).
- curl con HTTPS.
- python3 (solo biblioteca estándar).
- awk, sed, grep, cut y tr (busybox vale; ojo: su awk **no** admite `%*d` en `printf`).
- Permisos de root: `parar_stream` abre sockets AF_PACKET y raw, y `sincronizar_hora` cambia el reloj.

## Configuración

Cada instalación tiene su configuración en `botikor.conf`, en el directorio de trabajo, con permisos 600. El script no lleva ningún dato de nadie, así que se actualiza o se publica tal cual. `botikor.conf.ejemplo` explica cada clave.

- **Formato:** una línea `CLAVE=valor`; se ignoran las vacías y las que empiezan por `#`. El valor es literal, sin comillas (si va entero entre comillas, se quitan). Se quitan los espacios de alrededor salvo en `WEBIF_CLAVE`, así que una contraseña puede llevar `$`, `"`, `` ` ``, `\` o espacios. El fichero **nunca se ejecuta**: `leer_conf` lo lee línea a línea y solo acepta las claves de `CLAVES_CONF`; las demás se anotan en el log.
- **Claves:** `TOKEN` e `ID` (obligatorias), `WEBIF`, `WEBIF_USUARIO`, `WEBIF_CLAVE`, `GHOSTLIST`, `GHOST_PORT_INT` (`auto` = el puerto más repetido en las URLs de la lista; si no hay, 3138), `GHOST_PORT_EXT` (vacío = el interno) y `STREAMPORT_NATIVO`.
- **Configuración inicial:** si falta el fichero (o el `TOKEN` o el `ID`) y el script se lanza a mano desde una terminal (`[ -t 0 ]`), `configuracion_inicial` hace cinco preguntas:
  1. el token, que comprueba con `getMe`;
  2. el chat: pide escribir al bot y lo lee con `getUpdates`, saltándose los mensajes pendientes para que no se ejecute un comando viejo;
  3. OpenWebIF: lo prueba y, si responde 401, pide usuario y contraseña;
  4. la lista de canales;
  5. los puertos.

  Después guarda el fichero. Se niega si ya hay otro BOTikor en marcha (se comería los mensajes) y se cancela con Ctrl+D. En un arranque sin terminal nunca pregunta: deja un `ERROR` en el log y se cierra. `botikor.sh --configurar` vuelve a preguntar, con los valores actuales por defecto.
- **OpenWebIF con contraseña:** se pasa a curl como array (`WEBIF_AUTH`), para que la contraseña llegue entera.

## Comandos

Se aceptan con o sin `/` delante, en mayúsculas o minúsculas.

| Comando | Qué hace |
|---|---|
| `lista` | Canales numerados. |
| `canal X` | URL pública del canal X (y la transcodificada). |
| `zap X` | Cambia el deco al canal X (ver «Cómo funciona zap»). |
| `actualizar_canales` | Vuelve a leer `lista.m3u8`. |
| `actualizar_botikor` | Descarga la última release y, si es más nueva, la instala. |
| `downgrade X` | Instala la versión X publicada (`1.0.0`, `v1.0.0` o `100`); sin X, las lista. |
| `log` | Envía el log (últimos arranques) como `log.txt`. |
| `encender` | Saca al deco de standby. |
| `suspender` | Standby normal (el bot sigue vivo). |
| `apagar` | Apagado **profundo** (el bot deja de correr). |
| `parar_stream` | Corta los streams activos. |
| `reiniciar_deco` | Reinicia el deco. |
| `reiniciar_bot` | Relanza este script sin reiniciar el deco. |
| `exit` | Cierra el bot. |

Los comandos son **una palabra** (con `_` si hace falta) porque Telegram solo convierte en enlace clicable letras, cifras y guion bajo. Para añadir uno nuevo, ver la nota sobre `case $comando in` en el bucle principal.

## Cómo funciona `zap`

El bot pide 3 s de stream a ghostreamy por la URL local (`curl --max-time 3`). Para que eso cambie el canal del deco hacen falta **dos ajustes activados**; es un requisito de instalación que debe constar en la guía:

1. En el **usuario de ghostreamy** que usa el bot: «Forzar zap antes de reproducir un canal».
2. En el **propio deco**, en la configuración de OpenWebIF: «zap before streaming» (anotar aquí el texto exacto del ajuste cuando se compruebe).

Sin ellos, ghostreamy abre un stream aparte y el deco no se mueve (comprobado en un Octagon SF8008). El bot no puede confirmar el cambio. El corte por `--max-time` devuelve rc 28, que aquí es lo normal.

## Convenciones del código

- Para escribir en el log: `registrar "texto"` (antepone la hora). Para hablar con la persona: `telegram "texto"`. **Nunca `echo` suelto**: la salida estándar va al log sin hora y la persona no la ve.
- El `TOKEN` no debe aparecer jamás en el log, ni dentro de mensajes de error.
- No hay `set -e` a propósito: el bot no debe morir porque un comando falle; cada fallo se registra y el bucle sigue.
- El estado de los streams es texto: una línea por elemento, campos separados por tabuladores, en variables normales (sin arrays asociativos). Ver «ESTADO DE LOS STREAMS: FUNCIONES DE APOYO» en el script.
- Python embebido en heredocs `<<-'PYEOF'` (comilla simple: bash no interpreta nada dentro). El contenido va sangrado con **tabuladores**, que `<<-` elimina: no empezar línea con espacios. Los datos entran por argumentos o variables de entorno, no interpolados en el código (única excepción: la comparación de versiones de `actualizar_botikor`).
- Fichero en UTF-8 y con saltos de línea LF (no CRLF: bash se rompe con el `\r`). Si se edita en Windows, usar un editor de código, no Word.
- `VERSION="X.Y.Z"` debe ser la **primera** línea del fichero que empiece por `VERSION=`. La leen `actualizar_botikor` y `downgrade_botikor` (con `version_de`) y la comparan como tupla de enteros (3.1.10 > 3.1.9). La etiqueta de la release es `v` + esa versión.

## Cómo se publica una versión

Cada versión es una release de GitHub con etiqueta `vX.Y.Z` y dos ficheros: `botikor.sh` (con `TOKEN` e `ID` vacíos) y `botikor.sh.sha256` (salida de `sha256sum`). `actualizar_botikor` baja la de `releases/latest/download/`; `downgrade X` consulta la lista en la API (`api.github.com/repos/REPO_GITHUB/releases`, 60 consultas por hora e IP) y baja la de `releases/download/vX.Y.Z/`.

Para publicar:

1. Subir `VERSION=` en `botikor.sh`, hacer commit y `git push`.
2. Ejecutar `herramientas/publicar_version.sh` (en Git Bash). Comprueba que no haya cambios sin guardar, que `main` esté subido, `bash -n`, que no haya CRLF, que `TOKEN` e `ID` estén vacíos y que la versión no exista y sea mayor que la última. Publica exactamente lo que hay en el commit, calcula la huella, crea la release y, al terminar, descarga lo publicado y comprueba la huella.

Las releases solo se pueden descargar sin contraseña si el repositorio es público.

## Cómo probar sin el deco

Las funciones se prueban sueltas en cualquier Linux con bash y python3:

1. Extraerlas con `sed -n '/^nombre() {/,/^}/p' botikor.sh`.
2. Definir stubs de `registrar()` y `telegram()` que impriman, y de `curl()` que devuelva un JSON de prueba.
3. Hacer `source`.

Para el bucle de streams, simular `VIVOS` y ejecutar ciclo a ciclo el bloque entre «Contabilidad barata» y «Latido cada» (así se verificó la 3.1.13). Para un `case` del despachador, extraer el bloque con `awk` desde la etiqueta hasta su `;;` y envolverlo en un `case` de prueba . Siempre `bash -n` antes de publicar.

## Limitaciones conocidas

1. **Canal de un stream de ghostreamy**: si varias conexiones salen de la misma IP, el canal se reparte por orden de llegada (la más reciente primero). Si alguien abre la web de ghostreamy y arranca un stream casi a la vez, podría atribuirse el canal a la conexión equivocada.
2. `parar_stream` solo corta IPv4 (las conexiones IPv6 reales se omiten y se avisa).
3. **Grabaciones**: solo se mira el `*.ts` más reciente de `/hdd/movie` y solo se avisa del inicio. Si dos grabaciones empiezan en el mismo ciclo, solo se anuncia una. La carpeta y los `cut -c 28-` están fijados en el código.
4. `canal X` necesita la IP pública (ipinfo.io) y que el router tenga abierto `GHOST_PORT_EXT`; no sirve detrás de CG-NAT. La reescritura de la URL solo reconoce hosts numéricos (`[0-9.]+`). Es intencionado: el bot comparte la IP pública (variable) y no un nombre DDNS que apunte siempre al dueño.
5. **Las actualizaciones se ejecutan como root.** Van por HTTPS (también las redirecciones) y se comprueba la huella SHA-256, que se publica junto al script. Eso protege del camino y de las descargas corruptas, pero no de quien entre en la cuenta de GitHub que publica: la cuenta debe tener verificación en dos pasos. No hay firma criptográfica.
6. La configuración se lee al arrancar: un cambio en `botikor.conf` no cuenta hasta reiniciar el bot. `GHOST_PORT_INT=auto` se vuelve a detectar con `actualizar_canales`.
7. Un único chat autorizado (`ID`).
8. Latencia: un comando se atiende en el siguiente ciclo (hasta ~5 s) y un stream se anuncia tras verlo dos ciclos seguidos (~10 s).
9. `zap` no puede confirmar que el deco haya cambiado de canal.

## Ideas pendientes (por orden de utilidad)

- Carpeta de grabaciones configurable (y `basename` en vez de `cut -c 28-`).
- Que `actualizar_canales` descargue y reescriba la lista desde ghostreamy.
- Comando de diagnóstico (`/estado`): versión, tiempo en marcha, OpenWebIF y ghostreamy alcanzables, canales cargados, IP pública.
