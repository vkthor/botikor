# BOTikor — arquitectura y notas de desarrollo

Documento para quien vaya a tocar `botikor.sh` (tú dentro de seis meses, un colaborador o una IA). Los comentarios dentro del script explican cada bloque; aquí está la visión de conjunto.

## Qué es

Un único script de bash (con trozos de Python embebidos) que corre como root dentro de un decodificador Enigma2 y lo maneja por Telegram: da URLs de streaming, cambia de canal, enciende y apaga, y avisa de grabaciones y de streams. Habla español o inglés (ver «Idioma»).

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
2. **Configuración** (ver «Configuración» más abajo): valores por defecto, funciones de idioma (`en_ingles`, `t`, `decir`, `es_si`; ver «Idioma»), `leer_conf`, `guardar_conf`, validaciones, `detectar_puerto_ghost`, `configuracion_inicial` e instalación (`instalar_arranque`, `script_arranque`, `iniciar_instalado`). Corre antes de redirigir la salida al log, porque la configuración inicial habla con la persona por la terminal.
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
| `lista.m3u8` | Lista de canales de ghostreamy: la descarga el bot de `GHOSTLIST_URL` o la copia la persona. La anterior queda en `lista.m3u8.anterior`. |
| `canales.tsv` | La lista ya digerida: nombre, URL normal, URL transcodificada. |
| `canalnombres`, `canalurls`, `canalurlstrans` | Las tres columnas de `canales.tsv`. La línea N de cada una es el canal N de `/lista`. |
| `listagrabaciones` | Grabaciones ya conocidas (se rehace en cada arranque). |
| `botikor_nuevo.sh`, `botikor_nuevo.sha256`, `botikor_versiones.tmp`, `botikor.log.tmp` | Temporales. |

Fuera de él:

| Ruta | Contenido |
|---|---|
| `SCRIPT_PATH` | El propio script (normalmente `/usr/script/botikor.sh`). |
| `SCRIPT_PATH.anterior` | Copia de la versión previa (la deja cada actualización o downgrade). |
| `/etc/init.d/botikor` | Arranque en cada boot. Lo crea el propio script al instalarse (ver «Instalación») y lo activa con `update-rc.d` (S90/K10). |
| `/var/run/botikor.pid` | PID del bot en marcha (lo usa `/etc/init.d/botikor`). |

## Requisitos del deco

- **bash** (no vale ash: se usan `printf -v`, `${!var}`, `<<<`, `$'..'` y `for ((..))`).
- curl con HTTPS.
- python3 (solo biblioteca estándar).
- awk, sed, grep, cut y tr (busybox vale; ojo: su awk **no** admite `%*d` en `printf`).
- Permisos de root: `parar_stream` abre sockets AF_PACKET y raw, y `sincronizar_hora` cambia el reloj.

## Configuración

Cada instalación tiene su configuración en `botikor.conf`, en el directorio de trabajo, con permisos 600. El script no lleva ningún dato de nadie, así que se actualiza o se publica tal cual. `botikor.conf.ejemplo` explica cada clave.

- **Formato:** una línea `CLAVE=valor`; se ignoran las vacías y las que empiezan por `#`. El valor es literal, sin comillas (si va entero entre comillas, se quitan). Se quitan los espacios de alrededor salvo en `WEBIF_CLAVE`, así que una contraseña puede llevar `$`, `"`, `` ` ``, `\` o espacios. El fichero **nunca se ejecuta**: `leer_conf` lo lee línea a línea y solo acepta las claves de `CLAVES_CONF`; las demás se anotan en el log.
- **Claves:** `IDIOMA` (`es` o `en`; sin ella, o con otro valor, `es`), `TOKEN` e `ID` (obligatorias), `WEBIF`, `WEBIF_USUARIO`, `WEBIF_CLAVE`, `GHOSTLIST`, `GHOSTLIST_URL` (ver «Lista de canales»), `GHOST_PORT_INT` (`auto` = el puerto más repetido en las URLs de la lista; si no hay, 3138), `GHOST_PORT_EXT` (vacío = el interno), `STREAMPORT_NATIVO`, `OSCAM_LOG` (`/tmp/oscam.log`; vacío = no se mira) y `GRABACIONES` (carpeta donde graba el deco; `/hdd/movie`; la configuración inicial solo la pregunta si esa no existe).
- **Configuración inicial:** si falta el fichero (o el `TOKEN` o el `ID`) y el script se lanza a mano desde una terminal (`[ -t 0 ]`), `configuracion_inicial` pregunta primero el idioma (1 español, por defecto; 2 inglés; la pregunta va en los dos idiomas) y después hace cinco preguntas:
  1. el token, que comprueba con `getMe`;
  2. el chat: pide escribir al bot y lo lee con `getUpdates`, saltándose los mensajes pendientes para que no se ejecute un comando viejo;
  3. OpenWebIF: lo prueba y, si responde 401, pide usuario y contraseña;
  4. la lista de canales;
  5. los puertos.

  Después guarda el fichero. Se niega si ya hay otro BOTikor en marcha (se comería los mensajes) y se cancela con Ctrl+D. En un arranque sin terminal nunca pregunta: deja un `ERROR` en el log y se cierra. `botikor.sh --configurar` (o `--setup`) vuelve a preguntar, con los valores actuales por defecto. Las respuestas s/n aceptan también y/yes, y las palabras clave tienen su versión inglesa (`mantener`/`keep`, `ninguna`/`none`).
- **OpenWebIF con contraseña:** se pasa a curl como array (`WEBIF_AUTH`), para que la contraseña llegue entera.

## Idioma

Todo lo que el bot dice (terminal, Telegram, log y el texto de `/etc/init.d/botikor`) está escrito en los dos idiomas, uno junto al otro, primero en español y después en inglés. `IDIOMA` decide cuál se usa:

- `registrar "texto" "text"` y `telegram "texto" "text"`: el segundo argumento es la versión inglesa. Con uno solo (una URL, un nombre de canal, un texto ya traducido) se usa ese.
- `t "texto" "text"` imprime el que toca sin salto de línea, para meterlo en `$(...)`; `decir "texto" "text"` lo imprime con salto de línea (terminal).
- En los trozos de Python que escriben textos para la persona (`estado_oscam`, `parar_streams`, el estado de OpenWebIF de `enviar_estado`) el idioma entra por argumento o por la variable de entorno `IDIOMA`, con una función `T(es, en)` equivalente.
- En el bucle principal se evita lanzar procesos por los textos: los fijos de los avisos de streams se calculan una vez (`TXT_STREAMS_ACTIVOS`, `TXT_VIA`, `TXT_DIRECTO`) y los demás usan `en_ingles`, que es un builtin.
- No se traducen: las dos líneas de cabecera de cada arranque en el log (`BOTIKOR v…` y `Started on …`, que cuenta `recortar_log`), la marca `Creado por BOTikor` del init.d (con ella se reconoce), los nombres de las claves de `botikor.conf` ni los valores internos del estado de los streams (`directo`, `ghostreamy`).
- Los mensajes de la terminal van sin tildes (como siempre); los de Telegram, con ellas.

Para añadir un mensaje nuevo: escribirlo siempre en los dos idiomas.

## Instalación

No hay instalador aparte: la persona descarga `botikor.sh`, lo lanza una vez desde una terminal (`bash botikor.sh`) y contesta las preguntas. Al acabar la configuración inicial, `instalar_arranque` ofrece dejarlo instalado:

1. se copia a `/usr/script/botikor.sh`, si no se ejecuta ya desde ahí (la versión anterior queda en `.anterior`);
2. crea `/etc/init.d/botikor` (texto en `script_arranque`) y lo activa con `update-rc.d botikor defaults 90 10`; si no hay `update-rc.d`, pone los enlaces de `/etc/rc?.d` a mano;
3. lo arranca en segundo plano y explica cómo pararlo, reiniciarlo y ver el log.

Si se contesta que no, el bot sigue en primer plano en la terminal. `botikor.sh --instalar` (o `--install`) repite solo este paso (exige que ya haya configuración). No se toca un `/etc/init.d/botikor` que no tenga la marca «Creado por BOTikor». Sus mensajes (`start`, `stop`, `status`) salen en el idioma de la configuración del momento en que se crea: al cambiar de idioma con `--configurar` y contestar que sí a la instalación, se rehace.

Para parar no se usa `--retry` de `start-stop-daemon` (el de busybox no lo anuncia en su ayuda, aunque en OpenSPA lo acepta): `stop` manda TERM, espera hasta 10 s y, si sigue vivo, manda KILL. `start` no lanza un segundo bot si el del fichero de PID sigue vivo.

## Lista de canales

En la web de ghostreamy, menú **Listas**, cada lista del usuario tiene una «m3u URL» del tipo `http://IP:3138/s/<lista>/l/<código>/l.m3u8`. `<código>` es la clave de acceso del usuario de ghostreamy: la URL es secreta. Se muestra una vez por cada interfaz de red del deco, con IPs que pueden no ser alcanzables desde fuera.

- La persona pega una de ellas en la configuración inicial. `url_lista_local` cambia el host por `127.0.0.1` y conserva el puerto y la ruta. Pedida así, ghostreamy devuelve las URLs de los canales también con `127.0.0.1`; `canal X` las convierte después a IP pública y puerto externo. Se guarda en `GHOSTLIST_URL`.
- `descargar_lista` baja a un temporal, comprueba que sea una lista m3u con canales (`#EXTM3U`, al menos un `#EXTINF` y una URL) y solo entonces sustituye `GHOSTLIST`. Si falla, deja el motivo en `LISTA_ERROR` y no toca nada.
- Al arrancar solo se descarga si falta el fichero, porque ghostreamy arranca después que el bot (S99 frente a S90). Para refrescarla está `actualizar_canales`.
- La URL nunca va al log: se registra con `url_lista_segura`, que solo muestra el host y el puerto.
- Comprobado en un deco real: la «m3u URL» de la lista usada, pedida por `127.0.0.1`, devuelve exactamente el mismo fichero que se había descargado a mano.

## OSCam

`/estado` dice si se está descifrando bien leyendo el log de OSCam (`OSCAM_LOG`, por defecto `/tmp/oscam.log`; vale para cualquier versión). `estado_oscam` lee el final del fichero (como mucho 400 KB) y mira los últimos `OSCAM_VENTANA` segundos (300):

- **ECM:** «found» y «cacheN» son descifrados correctos; «not found», «timeout», «rejected»… son fallos.
- **Lectores:** un «connect failed» o «disconnected» sin un ECM correcto posterior del mismo lector = lector caído.
- **dvbapi:** «waiting for matching readers» = el deco espera un lector.

Veredicto:

- **«bien»:** sin fallos.
- **«bien, con algún fallo»:** al menos el 80 % correcto, el último correcto y ningún lector caído.
- **«PROBLEMAS»:** el resto.
- **Sin ECM en la ventana** (canal en abierto, standby): no da alarma; solo dice cuándo fue el último, salvo que haya un lector caído.

Nunca muestra las direcciones de los servidores. Requisito: que OSCam tenga `logfile` activado (en `[global]` de `oscam.conf`).

## Comandos

Se aceptan con o sin `/` delante, en mayúsculas o minúsculas. Cada uno tiene un nombre en español y otro en inglés; los dos funcionan sea cual sea `IDIOMA`, y la ayuda (rama `*)`) muestra los del idioma elegido.

| Comando | En inglés | Qué hace |
|---|---|---|
| `lista` | `list` | Canales numerados. Si no caben en un mensaje de Telegram (4096 caracteres), van en varios, cortando entre líneas. |
| `canal X` | `channel X` | URL pública del canal X (y la transcodificada). |
| `zap X` | `zap X` | Cambia el deco al canal X (ver «Cómo funciona zap»). |
| `actualizar_canales` | `update_channels` | Con `GHOSTLIST_URL`, descarga la lista de ghostreamy (si falla, se queda la anterior); después la vuelve a leer. |
| `actualizar_botikor` | `update_botikor` | Descarga la última release y, si es más nueva, la instala. |
| `downgrade X` | `downgrade X` | Instala la versión X publicada (`v1.0.0`, `1.0.0` o `100`); sin X, las lista (con `v` delante). |
| `log` | `log` | Envía el log (últimos arranques) como `log.txt`. |
| `estado` | `status` | Resumen de si todo funciona: versión, tiempo en marcha, si responden OpenWebIF (y qué canal se ve) y ghostreamy, cómo va OSCam (ver «OSCam»), canales y de dónde sale la lista, streams en curso, IP pública y grabaciones con el espacio libre. Solo consulta. |
| `encender` | `power_on` | Saca al deco de standby. |
| `suspender` | `standby` | Standby normal (el bot sigue vivo). |
| `apagar` | `power_off` | Apagado **profundo** (el bot deja de correr). |
| `parar_stream` | `stop_stream` | Corta los streams activos. |
| `reiniciar_deco` | `reboot_box` | Reinicia el deco. |
| `reiniciar_bot` | `restart_bot` | Relanza este script sin reiniciar el deco. |
| `exit` | `exit` | Cierra el bot. |

Los comandos son **una palabra** (con `_` si hace falta) porque Telegram solo convierte en enlace clicable letras, cifras y guion bajo. Para añadir uno nuevo, ver la nota sobre `case $comando in` en el bucle principal.

## Cómo funciona `zap`

El bot pide 3 s de stream a ghostreamy por la URL local (`curl --max-time 3`). Para que eso cambie el canal del deco hacen falta **dos ajustes activados**; es un requisito de instalación que debe constar en la guía:

1. En el **usuario de ghostreamy** que usa el bot: «Forzar zap antes de reproducir un canal».
2. En el **propio deco**, en OpenWebIF: «Zap before streaming», que en la traducción española es «Saltar antes del Stream» (clave `zapbeforestream`). Está en la web de OpenWebIF, menú Extras → Configuración → «Configuración OpenWebif».

Sin ellos, ghostreamy abre un stream aparte y el deco no se mueve (comprobado en un Octagon SF8008). El bot no puede confirmar el cambio. El corte por `--max-time` devuelve rc 28, que aquí es lo normal.

## Convenciones del código

- Para escribir en el log: `registrar "texto" "text"` (antepone la hora). Para hablar con la persona: `telegram "texto" "text"`. Siempre en los dos idiomas (ver «Idioma»). **Nunca `echo` suelto**: la salida estándar va al log sin hora y la persona no la ve.
- El `TOKEN` no debe aparecer jamás en el log, ni dentro de mensajes de error.
- No hay `set -e` a propósito: el bot no debe morir porque un comando falle; cada fallo se registra y el bucle sigue.
- El estado de los streams es texto: una línea por elemento, campos separados por tabuladores, en variables normales (sin arrays asociativos). Ver «ESTADO DE LOS STREAMS: FUNCIONES DE APOYO» en el script.
- Python embebido en heredocs `<<-'PYEOF'` (comilla simple: bash no interpreta nada dentro). El contenido va sangrado con **tabuladores**, que `<<-` elimina: no empezar línea con espacios. Los datos entran por argumentos o variables de entorno, no interpolados en el código (única excepción: la comparación de versiones de `actualizar_botikor`).
- Fichero en UTF-8 y con saltos de línea LF (no CRLF: bash se rompe con el `\r`). Si se edita en Windows, usar un editor de código, no Word.
- `VERSION="X.Y.Z"` debe ser la **primera** línea del fichero que empiece por `VERSION=`. La leen `actualizar_botikor` y `downgrade_botikor` (con `version_de`) y la comparan como tupla de enteros (3.1.10 > 3.1.9). Va sin `v` a propósito: así la leen también las instalaciones de la v1.0.0. Hacia fuera siempre se escribe con `v` delante (`v1.0.1`): en los mensajes, en `downgrade`, en la etiqueta y en el título de la release.

## Cómo se publica una versión

Cada versión es una release de GitHub con etiqueta y título `vX.Y.Z` (como en los demás proyectos de vkthor), notas en inglés y en español (en ese orden, cada bloque con su rótulo en negrita, **English** y **Español**) y dos ficheros: `botikor.sh` (con `TOKEN` e `ID` vacíos) y `botikor.sh.sha256` (salida de `sha256sum`). `actualizar_botikor` baja la de `releases/latest/download/`; `downgrade X` consulta la lista en la API (`api.github.com/repos/REPO_GITHUB/releases`, 60 consultas por hora e IP) y baja la de `releases/download/vX.Y.Z/`.

Para publicar:

1. Subir `VERSION=` en `botikor.sh`, anotar los cambios en `CHANGELOG.md` (en inglés y en español), hacer commit y `git push`.
2. Ejecutar `herramientas/publicar_version.sh` (en Git Bash), con las notas en un fichero: `--notas-fichero notas.md`. Comprueba que no haya cambios sin guardar, que `main` esté subido, `bash -n`, que no haya CRLF, que `TOKEN` e `ID` estén vacíos y que la versión no exista y sea mayor que la última. Publica exactamente lo que hay en el commit, calcula la huella, crea la release y, al terminar, descarga lo publicado y comprueba la huella.

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
3. **Grabaciones**: solo se mira el `*.ts` más reciente de `GRABACIONES` y solo se avisa del inicio. Si dos grabaciones empiezan en el mismo ciclo, solo se anuncia una. El nombre que se muestra sale de `nombre_grabacion` (sin la fecha `AAAAMMDD HHMM - `, sin `.ts` y con los `_` como espacios).
4. `canal X` necesita la IP pública (ipinfo.io) y que el router tenga abierto `GHOST_PORT_EXT`; no sirve detrás de CG-NAT. La reescritura de la URL solo reconoce hosts numéricos (`[0-9.]+`). Es intencionado: el bot comparte la IP pública (variable) y no un nombre DDNS que apunte siempre al dueño.
5. **Las actualizaciones se ejecutan como root.** Van por HTTPS (también las redirecciones) y se comprueba la huella SHA-256, que se publica junto al script. Eso protege del camino y de las descargas corruptas, pero no de quien entre en la cuenta de GitHub que publica: la cuenta debe tener verificación en dos pasos. No hay firma criptográfica.
6. La configuración se lee al arrancar: un cambio en `botikor.conf` no cuenta hasta reiniciar el bot. `GHOST_PORT_INT=auto` se vuelve a detectar con `actualizar_canales`.
7. Un único chat autorizado (`ID`).
8. Latencia: un comando se atiende en el siguiente ciclo (hasta ~5 s) y un stream se anuncia tras verlo dos ciclos seguidos (~10 s).
9. `zap` no puede confirmar que el deco haya cambiado de canal.

## Ideas pendientes (por orden de utilidad)

