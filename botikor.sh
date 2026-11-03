#!/bin/bash
# BOTikor - bot de Telegram para decodificadores Enigma2 con ghostreamy.
# Autor: VkThor. Corre como root dentro del deco y lo maneja por Telegram.
# Arquitectura, comandos, convenciones, limitaciones y como probarlo:
# ARQUITECTURA.md.
# Requiere bash (no ash), curl, python3 y awk/sed/grep (busybox vale).
# La configuracion de cada instalacion va aparte, en botikor.conf.

# VERSION: formato X.Y.Z (tres enteros). La leen actualizar_botikor y
# downgrade_botikor con grep '^VERSION=' sobre el fichero descargado y la
# comparan como tupla numerica (3.1.10 es mas nueva que 3.1.9). Por eso esta
# linea debe empezar por VERSION=, ir entre comillas y ser la PRIMERA del
# fichero que lo haga. Version beta: aun no se lleva historial de cambios.
VERSION="1.0.0"
# REPO_GITHUB: repositorio de GitHub donde se publican las versiones. Cada una
# es una "release" con etiqueta vX.Y.Z y dos ficheros: botikor.sh (sin ninguna
# configuracion: esta va en botikor.conf) y botikor.sh.sha256 (su huella). Lo usan
# actualizar_botikor y downgrade_botikor, siempre por HTTPS (ver la nota de
# seguridad junto a descargar_verificado).
REPO_GITHUB="vkthor/botikor"

# Se captura ANTES del cd de más abajo: si $0 se invocó en forma
# relativa (./botikor.sh, bash botikor.sh...), hay que resolverla
# contra el directorio de trabajo original, no contra
# /home/root/botikor, o el auto-update escribiría en el sitio
# equivocado.
case "$0" in
	/*) SCRIPT_PATH="$0" ;;
	*)  SCRIPT_PATH="$(pwd)/$0" ;;
esac

# Directorio de trabajo del bot: aqui viven todos los ficheros relativos que
# usa el script (log, offset, botikor.conf, canales*, listagrabaciones...).
mkdir -p /home/root/botikor
cd /home/root/botikor || exit 1

# Nombre del fichero de log, relativo al directorio de trabajo.
log=botikor.log

# ============================================================

# CONFIGURACION: botikor.conf
#
# La configuracion de cada instalacion vive en $CONF (en el directorio de
# trabajo, solo legible por root), nunca dentro del script: asi el script se
# puede actualizar o publicar tal cual. Formato: una linea CLAVE=valor por
# variable; lineas vacias y las que empiezan por # se ignoran. El valor es
# literal (sin comillas; si va entero entre comillas, se quitan; los espacios
# de alrededor se quitan salvo en WEBIF_CLAVE), asi que una contrasena puede
# llevar $ " ` \ o espacios sin problema. El fichero NUNCA se ejecuta: solo se aceptan las
# claves de esta lista. Ejemplo comentado: botikor.conf.ejemplo.
#
#   TOKEN              el que da @BotFather (obligatorio; nunca va al log)
#   ID                 id numerico del unico chat autorizado (obligatorio)
#   WEBIF              direccion de OpenWebIF (http://127.0.0.1)
#   WEBIF_USUARIO      usuario de OpenWebIF, si pide contrasena (vacio: no)
#   WEBIF_CLAVE        su contrasena
#   GHOSTLIST          fichero con la lista de canales (lista.m3u8)
#   GHOSTLIST_URL      su "m3u URL" en ghostreamy (Listas). Si esta puesta,
#                      el bot descarga la lista de ahi (actualizar_canales);
#                      vacia: la persona copia el fichero a mano. Lleva el
#                      codigo de acceso de ghostreamy: nunca va al log
#   GHOST_PORT_INT     puerto donde escucha ghostreamy en el deco; "auto" lo
#                      saca de las URLs de GHOSTLIST (si no puede, 3138)
#   GHOST_PORT_EXT     puerto que el router abre hacia Internet y redirige al
#                      interno; solo lo usa "canal X". Vacio: igual al interno
#   STREAMPORT_NATIVO  puerto de streaming propio de Enigma2 (8001)
#   GRABACIONES        carpeta donde graba el deco (/hdd/movie); el bot avisa
#                      de cada grabacion nueva (*.ts) que aparece en ella
#   OSCAM_LOG          log de OSCam (/tmp/oscam.log); "estado" lo lee para
#                      decir si se esta descifrando bien. Vacio: no se mira
#
# Si falta el fichero (o el TOKEN o el ID) y el script se lanza a mano desde
# una terminal, pregunta los datos y lo crea (configuracion_inicial). En un
# arranque sin terminal nunca pregunta: lo anota en el log y se cierra. Para
# cambiar la configuracion: "botikor.sh --configurar" (con el bot parado) o
# editar el fichero y reiniciar el bot.
# Al terminar ofrece instalar el arranque automatico (ver "INSTALACION").

# ============================================================

CONF="botikor.conf"

# Valores por defecto (los que no aparezcan en $CONF se quedan asi).
TOKEN=""
ID=""
WEBIF="http://127.0.0.1"
WEBIF_USUARIO=""
WEBIF_CLAVE=""
GHOSTLIST="$(pwd)/lista.m3u8"
GHOSTLIST_URL=""
GHOST_PORT_INT="auto"
GHOST_PORT_EXT=""
STREAMPORT_NATIVO="8001"
GRABACIONES="/hdd/movie"
OSCAM_LOG="/tmp/oscam.log"

CLAVES_CONF="TOKEN ID WEBIF WEBIF_USUARIO WEBIF_CLAVE GHOSTLIST GHOSTLIST_URL GHOST_PORT_INT GHOST_PORT_EXT STREAMPORT_NATIVO GRABACIONES OSCAM_LOG"

# Lee $CONF. Deja en CONF_AVISOS las lineas que no entiende (para el log).
leer_conf() {
	CONF_AVISOS=""
	[ -f "$CONF" ] || return 1
	n=0
	while IFS= read -r linea || [ -n "$linea" ]; do
		n=$((n + 1))
		linea="${linea%$'\r'}"
		# Espacios al principio, fuera (al final no: pueden ser de una contrasena).
		linea="${linea#"${linea%%[![:space:]]*}"}"
		case "$linea" in
			""|\#*) continue ;;
		esac
		case "$linea" in
			*=*) ;;
			*) CONF_AVISOS="$CONF_AVISOS linea $n sin '=';"; continue ;;
		esac
		clave="${linea%%=*}"
		clave="${clave//[[:space:]]/}"
		valor="${linea#*=}"
		# Espacios alrededor del valor: fuera, salvo en la contrasena, que es literal.
		if [ "$clave" != "WEBIF_CLAVE" ]; then
			valor="${valor#"${valor%%[![:space:]]*}"}"
			valor="${valor%"${valor##*[![:space:]]}"}"
		fi
		case "$valor" in
			\"*\"|\'*\') [ ${#valor} -ge 2 ] && valor="${valor:1:${#valor}-2}" ;;
		esac
		case " $CLAVES_CONF " in
			*" $clave "*) printf -v "$clave" '%s' "$valor" ;;
			*) CONF_AVISOS="$CONF_AVISOS linea $n: clave desconocida '$clave';" ;;
		esac
	done < "$CONF"
	return 0
}

token_valido() { [[ "$1" =~ ^[0-9]+:[A-Za-z0-9_-]{20,}$ ]]; }
id_valido() { [[ "$1" =~ ^-?[0-9]+$ ]]; }
es_puerto() { [[ "$1" =~ ^[0-9]{1,5}$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }

# Puerto mas repetido en las URLs de la lista de canales ($1), o nada.
detectar_puerto_ghost() {
	[ -f "$1" ] || return 1
	tr -d '\r' < "$1" | sed -nE 's#^https?://([^/@]*@)?[^/:@]+:([0-9]+)/.*#\2#p' \
		| sort | uniq -c | sort -rn | awk 'NR == 1 { print $2 }'
}

# LISTA DE CANALES DESDE GHOSTREAMY
# En la web de ghostreamy (Listas) cada lista tiene su "m3u URL", del tipo
# http://IP:3138/s/<lista>/l/<codigo>/l.m3u8, una por cada IP del deco. El bot
# corre en el propio deco, asi que siempre la pide a 127.0.0.1 (las IPs de la
# web pueden no ser alcanzables) con el mismo puerto y ruta; ghostreamy
# devuelve entonces las URLs de los canales tambien con 127.0.0.1.

# Imprime la URL con el host cambiado por 127.0.0.1, o nada si no es una URL.
url_lista_local() {
	[[ "$1" =~ ^(https?)://([^/@]*@)?([^/:]+|\[[^]]*\])(:[0-9]+)?(/.+)$ ]] || return 1
	printf '%s://127.0.0.1%s%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[4]}" "${BASH_REMATCH[5]}"
}

# Para el log y la pantalla: solo esquema, host y puerto (la ruta lleva el
# codigo de acceso de ghostreamy).
url_lista_segura() {
	printf '%s\n' "$1" | sed -E 's#^(https?://[^/]+)/.*#\1/... (ruta oculta)#'
}

# descargar_lista URL FICHERO: descarga la lista y, si es una lista m3u con
# canales, sustituye FICHERO (el anterior queda en FICHERO.anterior). Deja en
# LISTA_CANALES los canales distintos (por tvg-name) y en LISTA_ERROR el motivo
# si falla; en ese caso FICHERO no se toca.
descargar_lista() {
	local url="$1" destino="$2" tmp="$2.descarga" n_inf n_url
	LISTA_ERROR=""
	LISTA_CANALES=0
	rm -f "$tmp"
	if ! LISTA_ERROR=$(curl -fsS --max-time 30 -o "$tmp" "$url" 2>&1); then
		LISTA_ERROR="no se ha podido descargar ($(printf '%s' "$LISTA_ERROR" | head -n 1))"
		rm -f "$tmp"
		return 1
	fi
	n_inf=$(grep -c '^#EXTINF' "$tmp" 2>/dev/null)
	n_url=$(grep -cE '^https?://' "$tmp" 2>/dev/null)
	if ! head -n 5 "$tmp" | grep -q '#EXTM3U' || [ "${n_inf:-0}" -eq 0 ] || [ "${n_url:-0}" -eq 0 ]; then
		LISTA_ERROR="lo descargado no es una lista m3u con canales"
		rm -f "$tmp"
		return 1
	fi
	LISTA_CANALES=$(grep -o 'tvg-name="[^"]*"' "$tmp" | sort -u | grep -c .)
	[ "$LISTA_CANALES" -gt 0 ] || LISTA_CANALES=$n_inf
	mkdir -p "$(dirname "$destino")"
	[ -f "$destino" ] && cp -p "$destino" "$destino.anterior"
	if ! mv "$tmp" "$destino"; then
		LISTA_ERROR="no se puede escribir $destino"
		rm -f "$tmp"
		return 1
	fi
	return 0
}

# Escribe $CONF con los valores actuales, de forma atomica y con permisos 600.
guardar_conf() {
	(
		umask 077
		{
			echo "# Configuracion de BOTikor (ver botikor.conf.ejemplo). Generado el $(date '+%d/%m/%Y %H:%M')."
			echo "# Formato CLAVE=valor, sin comillas. Contiene el token del bot: no compartir."
			for clave in $CLAVES_CONF; do
				printf '%s=%s\n' "$clave" "${!clave}"
			done
		} > "$CONF.tmp" && chmod 600 "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
	)
}

# read para la configuracion inicial: si se cierra la entrada (Ctrl+D) se
# cancela, en vez de repetir la pregunta sin fin.
leer_cancelado() {
	echo
	echo "Entrada cerrada: configuracion cancelada, no se ha guardado nada."
	exit 1
}
leer() { read -r "$@" || leer_cancelado; }

# Pregunta con valor por defecto: preguntar VARIABLE "texto" "defecto"
preguntar() {
	local respuesta
	if [ -n "$3" ]; then
		leer -p "$2 [$3]: " respuesta
	else
		leer -p "$2: " respuesta
	fi
	printf -v "$1" '%s' "${respuesta:-$3}"
}

# CONFIGURACION INICIAL (interactiva, solo con terminal). Valida el token con
# getMe, averigua el ID pidiendo a la persona que escriba al bot (getUpdates),
# prueba OpenWebIF y la lista de canales, y guarda $CONF. Devuelve 1 si se
# cancela. Corre ANTES de redirigir la salida al log: lo que imprime lo ve
# la persona en la terminal.
configuracion_inicial() {
	local api nombre_bot respuesta datos ultimo intentos chat nombre tipo
	local codigo detectado n_canales tok url url_local

	echo
	echo "=============================================="
	echo " BOTikor v$VERSION - configuracion"
	echo "=============================================="
	echo "Se guardara en $(pwd)/$CONF (solo lo puede leer root)."
	echo "Pulsa Intro para aceptar el valor entre corchetes. Ctrl+C cancela."

	# Otro botikor en marcha se "comeria" los mensajes de Telegram.
	# "sh .../botikor.sh": el bot en marcha, no un editor con el fichero abierto.
	for p in $(pgrep -f 'sh ([^ ]*/)?botikor\.sh( |$)' 2>/dev/null); do
		# El propio $( ) de esta linea es un hijo con la misma linea de orden:
		# cuando se revisa la lista ya ha terminado, y por eso se descartan los
		# PID que no siguen vivos.
		if [ "$p" != "$$" ] && kill -0 "$p" 2>/dev/null; then
			echo
			echo "Hay otro BOTikor en marcha (PID $p). Paralo antes de configurar"
			echo "(por ejemplo: /etc/init.d/botikor stop) y vuelve a lanzar este comando."
			return 1
		fi
	done

	# 1. Token
	echo
	echo "1/5 TOKEN DEL BOT"
	echo "    Te lo da @BotFather en Telegram al crear el bot (/newbot)."
	while :; do
		if [ -n "$TOKEN" ]; then
			leer -p "    Token [Intro = mantener el actual, ${TOKEN%%:*}:...]: " tok
			tok="${tok:-$TOKEN}"
		else
			leer -p "    Token: " tok
		fi
		tok="${tok//[[:space:]]/}"
		if ! token_valido "$tok"; then
			echo "    Eso no parece un token (es algo como 123456789:ABCdef...). Prueba otra vez."
			continue
		fi
		api="https://api.telegram.org/bot$tok"
		nombre_bot=$(curl -s --max-time 15 "$api/getMe" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d["result"]["username"] if d.get("ok") else "")
except Exception:
    pass' 2>/dev/null)
		if [ -n "$nombre_bot" ]; then
			echo "    Correcto: el bot es @$nombre_bot"
			TOKEN="$tok"
			break
		fi
		echo "    Telegram no acepta ese token (o no hay conexion a Internet). Prueba otra vez."
	done

	# 2. ID del chat
	echo
	echo "2/5 TU CHAT"
	echo "    El bot solo obedecera a un chat. Para saber cual es el tuyo:"
	echo "    abre Telegram y escribe cualquier cosa a @$nombre_bot (por ejemplo: hola)."
	if [ -n "$ID" ]; then
		echo "    (Ahora mismo el autorizado es el $ID. Escribe 'mantener' para no cambiarlo.)"
	fi
	echo "    Espero hasta 2 minutos. Si prefieres escribir el ID a mano, pulsa Intro."

	# Se descarta lo que hubiera pendiente: solo cuenta un mensaje nuevo.
	ultimo=$(curl -s --max-time 15 "$api/getUpdates?offset=-1" | python3 -c '
import json, sys
try:
    r = json.load(sys.stdin).get("result", [])
    print(r[-1]["update_id"] if r else 0)
except Exception:
    print(0)' 2>/dev/null)
	ultimo=${ultimo:-0}

	chat=""
	intentos=0
	while [ -z "$chat" ] && [ $intentos -lt 6 ]; do
		intentos=$((intentos + 1))
		# read -t: si la persona pulsa Intro (o escribe algo) se deja de esperar.
		read -r -t 1 respuesta
		rc_read=$?
		if [ $rc_read -eq 0 ]; then
			[ "$respuesta" = "mantener" ] && [ -n "$ID" ] && chat="$ID"
			break
		elif [ $rc_read -le 128 ]; then
			leer_cancelado
		fi
		datos=$(curl -s --max-time 25 "$api/getUpdates?offset=$((ultimo + 1))&timeout=19" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not d.get("ok"):
    print("ERROR\t%s" % d.get("description", ""))
    sys.exit(0)
for u in d.get("result", []):
    m = u.get("message") or u.get("edited_message")
    if not m:
        continue
    c = m.get("chat", {})
    nombre = c.get("title") or " ".join(x for x in (c.get("first_name"), c.get("last_name")) if x) or ""
    if c.get("username"):
        nombre += " (@%s)" % c["username"]
    print("%s\t%s\t%s\t%s" % (u["update_id"], c.get("id", ""), c.get("type", ""), nombre.replace("\t", " ")))
    break' 2>/dev/null)
		case "$datos" in
			ERROR*)
				echo "    Telegram dice: ${datos#ERROR?}"
				echo "    (Si el bot tiene un webhook o hay otro programa usando este token, no puedo leer los mensajes.)"
				break
				;;
			?*)
				IFS=$'\t' read -r ultimo chat tipo nombre <<< "$datos"
				echo "    Mensaje recibido de: $nombre (chat $chat, tipo $tipo)"
				leer -p "    Es tu chat? (s/n) [s]: " respuesta
				case "${respuesta:-s}" in
					s|S|si|SI|Si) ;;
					*) chat="" ;;
				esac
				;;
		esac
	done

	while ! id_valido "$chat"; do
		preguntar chat "    ID del chat (un numero; te lo da tambien @userinfobot)" "$ID"
	done
	ID="$chat"
	# El mensaje de prueba ya esta leido: que el bot no lo conteste al arrancar.
	[ "${ultimo:-0}" -gt 0 ] && echo "$((ultimo + 1))" > offset

	# 3. OpenWebIF
	echo
	echo "3/5 OPENWEBIF (la web del deco; el bot la usa para encender, apagar y ver streams)"
	while :; do
		preguntar WEBIF "    Direccion" "$WEBIF"
		WEBIF_AUTH=()
		[ -n "$WEBIF_USUARIO" ] && WEBIF_AUTH=(-u "$WEBIF_USUARIO:$WEBIF_CLAVE")
		codigo=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${WEBIF_AUTH[@]}" "$WEBIF/api/statusinfo")
		case "$codigo" in
			200)
				echo "    Correcto: OpenWebIF responde."
				break
				;;
			401)
				echo "    OpenWebIF pide usuario y contrasena."
				preguntar WEBIF_USUARIO "    Usuario" "${WEBIF_USUARIO:-root}"
				leer -s -p "    Contrasena (no se ve al escribir): " WEBIF_CLAVE
				echo
				;;
			*)
				echo "    No hay respuesta de OpenWebIF en $WEBIF (codigo ${codigo:-ninguno})."
				leer -p "    Guardar de todas formas? (s/n) [n]: " respuesta
				case "$respuesta" in s|S|si|SI|Si) break ;; esac
				;;
		esac
	done

	# 4. Lista de canales
	echo
	echo "4/5 LISTA DE CANALES DE GHOSTREAMY"
	echo "    En la web de ghostreamy entra en Listas y, en la lista que quieras usar,"
	echo "    pulsa el boton \"m3u URL\": copia esa direccion y pegala aqui (da igual"
	echo "    cual de las IPs). Con ella el bot descarga la lista el solo, ahora y cada"
	echo "    vez que le envies /actualizar_canales. Esa direccion lleva tu codigo de"
	echo "    ghostreamy: no la compartas."
	echo "    Si prefieres copiar tu el fichero lista.m3u8 al deco, pulsa Intro."
	while :; do
		if [ -n "$GHOSTLIST_URL" ]; then
			leer -p "    Direccion m3u [Intro = mantener la actual; 'ninguna' = usar fichero]: " url
			url="${url:-$GHOSTLIST_URL}"
		else
			leer -p "    Direccion m3u: " url
		fi
		url="${url//[[:space:]]/}"
		[ "$url" = "ninguna" ] && url=""
		if [ -z "$url" ]; then
			GHOSTLIST_URL=""
			break
		fi
		if ! url_local=$(url_lista_local "$url"); then
			echo "    Eso no parece una direccion (empieza por http://). Prueba otra vez."
			continue
		fi
		if descargar_lista "$url_local" "$GHOSTLIST"; then
			echo "    Correcto: lista descargada, $LISTA_CANALES canales."
			GHOSTLIST_URL="$url_local"
			break
		fi
		echo "    No funciona: $LISTA_ERROR."
		case "$url" in
			https:*) echo "    Prueba con la direccion que empieza por http:// (sin s)." ;;
			*) echo "    Esta ghostreamy en marcha? Has copiado la direccion m3u entera?" ;;
		esac
	done
	if [ -z "$GHOSTLIST_URL" ]; then
		preguntar GHOSTLIST "    Ruta del fichero" "$GHOSTLIST"
		if [ -f "$GHOSTLIST" ]; then
			n_canales=$(grep -cE '^https?://' "$GHOSTLIST" 2>/dev/null)
			detectado=$(detectar_puerto_ghost "$GHOSTLIST")
			echo "    Encontrada: $n_canales URLs${detectado:+, puerto de ghostreamy $detectado}."
		else
			echo "    Todavia no existe. El bot arrancara sin canales: cuando la tengas,"
			echo "    copiala ahi y envia /actualizar_canales al bot."
		fi
	fi

	# 5. Puertos de ghostreamy
	echo
	echo "5/5 PUERTOS DE GHOSTREAMY"
	echo "    Interno: donde escucha ghostreamy en el deco. 'auto' lo saca de la lista."
	preguntar GHOST_PORT_INT "    Puerto interno" "$GHOST_PORT_INT"
	while [ "$GHOST_PORT_INT" != "auto" ] && ! es_puerto "$GHOST_PORT_INT"; do
		preguntar GHOST_PORT_INT "    Tiene que ser un numero de 1 a 65535, o auto" "auto"
	done
	echo "    Externo: el que tu router abre hacia Internet y lleva al interno."
	echo "    Solo lo usa /canal X para darte la URL de fuera de casa. Intro: el mismo que el interno."
	preguntar GHOST_PORT_EXT "    Puerto externo" "$GHOST_PORT_EXT"
	while [ -n "$GHOST_PORT_EXT" ] && ! es_puerto "$GHOST_PORT_EXT"; do
		preguntar GHOST_PORT_EXT "    Tiene que ser un numero de 1 a 65535 (o Intro)" ""
	done

	# Carpeta de grabaciones: solo se pregunta si la de siempre no existe.
	if [ ! -d "$GRABACIONES" ]; then
		echo
		echo "    GRABACIONES: el bot avisa cuando el deco empieza a grabar algo, mirando"
		echo "    la carpeta donde graba. $GRABACIONES no existe en este deco."
		preguntar GRABACIONES "    Carpeta de grabaciones" "$GRABACIONES"
		[ -d "$GRABACIONES" ] || echo "    Tampoco existe ahora: se guarda igual (por si es un disco que aun no esta montado)."
	fi

	if ! guardar_conf; then
		echo
		echo "No he podido escribir $(pwd)/$CONF."
		return 1
	fi

	echo
	echo "Guardado en $(pwd)/$CONF:"
	echo "    bot @$nombre_bot | chat $ID | OpenWebIF $WEBIF${WEBIF_USUARIO:+ (usuario $WEBIF_USUARIO)}"
	echo "    lista $GHOSTLIST${GHOSTLIST_URL:+ (se descarga de ghostreamy)} | puertos ghostreamy ${GHOST_PORT_INT}->${GHOST_PORT_EXT:-(el mismo)}"
	echo "    grabaciones en $GRABACIONES"
	return 0
}

conf_completa() { token_valido "$TOKEN" && id_valido "$ID"; }

# ============================================================

# INSTALACION: arranque automatico con el deco
#
# Al terminar la configuracion inicial (o con "botikor.sh --instalar") se
# ofrece dejar el bot instalado:
#   1. copia este script a $DESTINO_SCRIPT, si no se esta ejecutando ya desde
#      ahi (la version que hubiera queda en .anterior);
#   2. crea $INIT_BOTIKOR, que arranca y para el bot con start-stop-daemon y
#      un fichero de PID, y lo activa en el arranque con update-rc.d (o, si
#      no existe, con los enlaces de /etc/rc?.d a mano);
#   3. arranca el bot en segundo plano.
# Si $INIT_BOTIKOR ya existe y no lo ha creado BOTikor, no se toca. Para
# quitarlo: "$INIT_BOTIKOR stop", "update-rc.d -f botikor remove" y borrar
# $INIT_BOTIKOR.

# ============================================================

DESTINO_SCRIPT="/usr/script/botikor.sh"
INIT_BOTIKOR="/etc/init.d/botikor"

# Texto de $INIT_BOTIKOR. start-stop-daemon de busybox no tiene --retry: la
# espera al parar se hace a mano.
script_arranque() {
	cat <<-EOF
	#!/bin/sh
	### BEGIN INIT INFO
	# Provides:          botikor
	# Required-Start:    \$network \$remote_fs
	# Required-Stop:
	# Default-Start:     2 3 4 5
	# Default-Stop:      0 1 6
	# Short-Description: BOTikor, bot de Telegram para el deco
	### END INIT INFO
	# Creado por BOTikor (botikor.sh --instalar lo vuelve a crear).

	SCRIPT="$DESTINO_SCRIPT"
	PIDFILE="/var/run/botikor.pid"

	en_marcha() {
	    [ -f "\$PIDFILE" ] && kill -0 "\$(cat "\$PIDFILE")" 2>/dev/null
	}

	case "\$1" in
	    start)
	        if en_marcha; then
	            echo "BOTikor ya esta en marcha (PID \$(cat "\$PIDFILE"))"
	            exit 0
	        fi
	        echo "Iniciando BOTikor..."
	        start-stop-daemon -S -b -m -p "\$PIDFILE" -x "\$SCRIPT"
	        ;;
	    stop)
	        echo "Deteniendo BOTikor..."
	        if en_marcha; then
	            kill "\$(cat "\$PIDFILE")"
	            for i in 1 2 3 4 5 6 7 8 9 10; do
	                en_marcha || break
	                sleep 1
	            done
	            en_marcha && kill -9 "\$(cat "\$PIDFILE")" 2>/dev/null
	        fi
	        rm -f "\$PIDFILE"
	        ;;
	    restart)
	        "\$0" stop
	        sleep 1
	        "\$0" start
	        ;;
	    status)
	        if en_marcha; then
	            echo "BOTikor en marcha (PID \$(cat "\$PIDFILE"))"
	        else
	            echo "BOTikor no esta en marcha"
	            exit 3
	        fi
	        ;;
	    *)
	        echo "Uso: \$0 {start|stop|restart|status}"
	        exit 1
	        ;;
	esac
	exit 0
	EOF
}

# Pregunta y hace la instalacion. Devuelve 0 si queda instalado.
instalar_arranque() {
	local respuesta

	echo
	echo "INSTALACION"
	echo "    Para que BOTikor arranque solo cada vez que se enciende el deco:"
	[ "$SCRIPT_PATH" != "$DESTINO_SCRIPT" ] && echo "      - se copia a $DESTINO_SCRIPT"
	echo "      - se crea $INIT_BOTIKOR y se activa en el arranque del deco"
	echo "      - se pone en marcha ahora, en segundo plano"

	if [ -e "$INIT_BOTIKOR" ] && ! grep -q 'Creado por BOTikor' "$INIT_BOTIKOR" 2>/dev/null; then
		echo "    Ya existe $INIT_BOTIKOR y no lo ha creado BOTikor: no lo toco."
		echo "    El bot arranca ahora en esta terminal (Ctrl+C lo para)."
		return 1
	fi

	leer -p "    Instalo? (s/n) [s]: " respuesta
	case "${respuesta:-s}" in
		s|S|si|SI|Si) ;;
		*)
			echo "    Sin instalar. El bot arranca ahora en esta terminal (Ctrl+C lo para)."
			echo "    Para instalarlo mas tarde: $SCRIPT_PATH --instalar"
			return 1
			;;
	esac

	# 1. El script, en su sitio (copia y mv: nunca queda a medio escribir).
	if [ "$SCRIPT_PATH" != "$DESTINO_SCRIPT" ]; then
		mkdir -p "$(dirname "$DESTINO_SCRIPT")"
		[ -f "$DESTINO_SCRIPT" ] && cp -p "$DESTINO_SCRIPT" "$DESTINO_SCRIPT.anterior"
		if ! cp "$SCRIPT_PATH" "$DESTINO_SCRIPT.nuevo" || ! chmod 755 "$DESTINO_SCRIPT.nuevo" || ! mv "$DESTINO_SCRIPT.nuevo" "$DESTINO_SCRIPT"; then
			rm -f "$DESTINO_SCRIPT.nuevo"
			echo "    No he podido copiar el script a $DESTINO_SCRIPT."
			return 1
		fi
		echo "    Copiado a $DESTINO_SCRIPT"
	fi

	# 2. El arranque automatico.
	if ! script_arranque > "$INIT_BOTIKOR.nuevo" || ! chmod 755 "$INIT_BOTIKOR.nuevo" || ! mv "$INIT_BOTIKOR.nuevo" "$INIT_BOTIKOR"; then
		rm -f "$INIT_BOTIKOR.nuevo"
		echo "    No he podido crear $INIT_BOTIKOR."
		return 1
	fi

	if command -v update-rc.d >/dev/null 2>&1; then
		update-rc.d botikor defaults 90 10 >/dev/null 2>&1
	fi
	# Sin update-rc.d (o si no ha dejado los enlaces), a mano.
	if ! ls /etc/rc3.d/S*botikor >/dev/null 2>&1; then
		for n in 2 3 4 5; do [ -d "/etc/rc$n.d" ] && ln -sf ../init.d/botikor "/etc/rc$n.d/S90botikor"; done
		for n in 0 1 6; do [ -d "/etc/rc$n.d" ] && ln -sf ../init.d/botikor "/etc/rc$n.d/K10botikor"; done
	fi

	if ls /etc/rc3.d/S*botikor >/dev/null 2>&1; then
		echo "    Creado $INIT_BOTIKOR y activado en el arranque."
	else
		echo "    Creado $INIT_BOTIKOR, pero no he podido activarlo en el arranque"
		echo "    (no hay /etc/rc3.d). Tendras que hacerlo a mano."
	fi
	return 0
}

# Arranca el bot ya instalado, en segundo plano, y explica como manejarlo.
iniciar_instalado() {
	echo
	"$INIT_BOTIKOR" start
	sleep 2
	"$INIT_BOTIKOR" status
	echo
	echo "Listo. Ya puedes cerrar esta terminal: el bot sigue en marcha y"
	echo "arrancara solo cada vez que se encienda el deco. Te ha escrito por"
	echo "Telegram; prueba a enviarle /lista."
	echo "    Parar / arrancar / reiniciar:  $INIT_BOTIKOR stop | start | restart"
	echo "    Cambiar la configuracion:      $INIT_BOTIKOR stop; $DESTINO_SCRIPT --configurar"
	echo "    Log:                           $(pwd)/$log"
	echo
}

leer_conf

case "$1" in
	--instalar)
		if [ ! -t 0 ]; then
			echo "--instalar hace preguntas: lanzalo desde una terminal."
			exit 1
		fi
		if ! conf_completa; then
			echo "Antes de instalar hay que configurar el bot: lanza $SCRIPT_PATH sin opciones."
			exit 1
		fi
		instalar_arranque && iniciar_instalado
		exit $?
		;;
	*)
		if [ "$1" = "--configurar" ] || ! conf_completa; then
			if [ -t 0 ]; then
				configuracion_inicial || exit 1
				leer_conf
				if instalar_arranque; then
					iniciar_instalado
					exit 0
				fi
			fi
		fi
		;;
esac

# ============================================================

# RECORTE DEL LOG
#
# El log crece sin parar, asi que en cada arranque se dejan solo los
# registros de los MAX_ARRANQUES ultimos arranques (contando el que
# empieza ahora). Cada arranque se identifica por su cabecera
# "BOTIKOR vX.Y.Z ..." + "Started on ...", asi que basta con contar
# esas marcas y tirar todo lo anterior a la que toque.
#
# Se hace ANTES del `exec >> "$log"` para no pelearse con el propio
# descriptor de escritura del script.

# ============================================================

MAX_ARRANQUES=3

# Cuenta marcas de arranque en el fichero pasado como $1. Se considera
# marca la linea del banner "BOTIKOR v..." y, si algun arranque no la
# tuviera, su "Started on ..." (el flag banner evita contar dos veces
# el mismo arranque).
contar_arranques() {
	awk '
		{
			if ($0 ~ /^BOTIKOR v/) { n++; banner = 1 }
			else if ($0 ~ /^Started on /) { if (!banner) n++; banner = 0 }
			else { banner = 0 }
		}
		END { print n + 0 }
	' "$1" 2>/dev/null
}

# Deja en RECORTE_INFO un resumen de lo que ha hecho, para poder
# registrarlo en cuanto el log este redirigido (unas lineas mas abajo).
recortar_log() {
	if [ ! -f "$log" ]; then
		RECORTE_INFO="no habia log previo, se crea uno nuevo"
		return 0
	fi

	total=$(contar_arranques "$log")
	total=${total:-0}

	# Se deja hueco para el arranque actual, que todavia no esta escrito.
	conservar=$((MAX_ARRANQUES - 1))

	if [ "$total" -le "$conservar" ]; then
		RECORTE_INFO="log con $total arranque(s) previo(s), no hace falta recortar (maximo $MAX_ARRANQUES)"
		return 0
	fi

	saltar=$((total - conservar))

	if awk -v saltar="$saltar" '
		{
			if ($0 ~ /^BOTIKOR v/) { n++; banner = 1 }
			else if ($0 ~ /^Started on /) { if (!banner) n++; banner = 0 }
			else { banner = 0 }
			if (n > saltar) print
		}
	' "$log" > "$log.tmp" 2>/dev/null && mv "$log.tmp" "$log"
	then
		RECORTE_INFO="log recortado: habia $total arranques previos, se han tirado $saltar y se conservan los $conservar mas recientes"
	else
		rm -f "$log.tmp"
		RECORTE_INFO="ATENCION: ha fallado el recorte del log, se deja tal cual estaba"
	fi
}

recortar_log

# A PARTIR DE AQUI toda la salida (stdout y stderr) del script va a $log.
# Consecuencias: un echo suelto acaba en el log SIN hora (por eso se usa
# registrar) y la persona no lo ve (para hablarle se usa telegram).
exec >> "$log" 2>&1

if test -s "$log"; then
printf "\n\n\n\n\n"
fi

fecha=$(date +%a--%d/%m--%H:%M)

# Cabecera de cada arranque. recortar_log() y contar_arranques() (mas arriba)
# cuentan los arranques buscando lineas que empiezan por "BOTIKOR v" y por
# "Started on ": si se cambia el texto de estas dos lineas hay que cambiar
# tambien esos awk, o el recorte del log dejara de funcionar.
printf "\nBOTIKOR v%s (version ghostreamy) by VkThor\n" "$VERSION"
echo "Started on $fecha"

# ============================================================

# REGISTRO EN EL LOG
#
# Todo lo que el script escribe por stdout/stderr acaba en $log (por el
# exec de arriba), asi que registrar() solo antepone la hora para que el
# log se pueda leer de un vistazo y se sepa CUANDO paso cada cosa.
#
# Norma: por aqui NUNCA pasa el TOKEN. Los mensajes de Telegram se
# registran recortados a una linea, para no llenar el log con la lista
# de canales entera.

# ============================================================

registrar() {
	printf '[%s] %s\n' "$(date '+%d/%m %H:%M:%S')" "$*"
}

# Recorta un texto a una sola linea de como mucho 200 caracteres, para
# que las respuestas de curl no revienten el log.
resumir() {
	printf '%s' "$1" | tr '\n\t' '  ' | cut -c1-200
}

registrar "Arranque de BOTikor v$VERSION | PID $$ | script $SCRIPT_PATH | directorio $(pwd)"
registrar "Recorte del log: $RECORTE_INFO"

# GRABACIONES: ESTADO INICIAL
# listagrabaciones guarda los nombres de las grabaciones (*.ts) que ya existian
# al arrancar, mas las que se vayan anunciando: asi solo se avisa de las nuevas.
# Se rehace en cada arranque. Los nombres son los de nombre_grabacion: Enigma2
# llama a los ficheros "AAAAMMDD HHMM - Canal - Titulo.ts" (algunas imagenes,
# con _ en vez de espacios); se quita la carpeta, la fecha, la extension y los _.

# Nombre de una grabacion para mostrar: "Canal - Titulo".
nombre_grabacion() {
	local n="${1##*/}"
	n="${n%.ts}"
	printf '%s\n' "$n" | sed -E 's/^[0-9]{8}[ _][0-9]{4}[ _]-[ _]//; s/_/ /g; s/  +/ /g'
}

# Ruta del *.ts mas reciente de $GRABACIONES, o nada.
ultima_grabacion() {
	ls -t "$GRABACIONES"/*.ts 2>/dev/null | head -n 1
}

rm -f listagrabaciones
for f in "$GRABACIONES"/*.ts; do
	[ -e "$f" ] && nombre_grabacion "$f"
done > listagrabaciones

lastfile=$(ultima_grabacion)
[ -n "$lastfile" ] && lastfile=$(nombre_grabacion "$lastfile")

registrar "Grabaciones existentes en $GRABACIONES: $(grep -c . listagrabaciones 2>/dev/null) | ultima conocida: ${lastfile:-(ninguna)}"

# OFFSET: id del siguiente mensaje de Telegram que se pide (getUpdates?offset=N).
# Telegram descarta lo anterior a N, asi que no hay que borrar nada. Se guarda
# en fichero para sobrevivir a los reinicios: sin el, al volver a arrancar se
# reprocesarian mensajes ya atendidos (por ejemplo, un "apagar" en bucle).
OFFSET_FILE="offset"

if [ -f "$OFFSET_FILE" ]; then
	OFFSET=$(cat "$OFFSET_FILE")
else
	OFFSET=0
fi
OFFSET=${OFFSET:-0}

registrar "Offset de Telegram al arrancar: $OFFSET (fichero ./$OFFSET_FILE)"

# ===================== CONFIGURACION EN USO =====================

# Los valores ya vienen de botikor.conf (ver "CONFIGURACION: botikor.conf" al
# principio del script). Aqui solo se validan, se completan y se calculan los
# derivados. Para cambiar algo se edita botikor.conf, no este bloque.

if [ -n "$CONF_AVISOS" ]; then
	registrar "ATENCION: en $CONF hay lineas que no se entienden y se ignoran:$CONF_AVISOS"
fi

if ! conf_completa; then
	if [ -f "$CONF" ]; then
		registrar "ERROR: en $(pwd)/$CONF falta el TOKEN o el ID, o no son validos. Sin ellos el bot no puede funcionar. Para arreglarlo, lanza a mano desde una terminal: $SCRIPT_PATH --configurar"
	else
		registrar "ERROR: no existe $(pwd)/$CONF. Para crearlo, lanza a mano desde una terminal: $SCRIPT_PATH"
	fi
	exit 1
fi

# Lleva el token: que solo lo pueda leer root aunque se haya creado a mano.
chmod 600 "$CONF" 2>/dev/null

if ! es_puerto "$STREAMPORT_NATIVO"; then
	registrar "ATENCION: STREAMPORT_NATIVO='$STREAMPORT_NATIVO' no es un puerto valido; se usa 8001"
	STREAMPORT_NATIVO=8001
fi

GRABACIONES="${GRABACIONES%/}"
if [ ! -d "$GRABACIONES" ]; then
	registrar "ATENCION: la carpeta de grabaciones $GRABACIONES no existe (o no esta montada): no se avisara de grabaciones hasta que aparezca"
fi

# Usuario y contrasena de OpenWebIF como argumentos de curl. Es un array para
# que la contrasena llegue entera aunque lleve espacios o simbolos.
WEBIF_AUTH=()
[ -n "$WEBIF_USUARIO" ] && WEBIF_AUTH=(-u "$WEBIF_USUARIO:$WEBIF_CLAVE")

# Lo que dice botikor.conf de los puertos de ghostreamy ("auto" o numero; el
# externo, vacio o numero). GHOST_PORT_INT y GHOST_PORT_EXT son los que se usan.
GHOST_PORT_CONF="$GHOST_PORT_INT"
GHOST_PORT_EXT_CONF="$GHOST_PORT_EXT"

# Fija GHOST_PORT_INT (si es "auto", el puerto mas repetido en las URLs de
# GHOSTLIST; si no se puede, 3138), GHOST_PORT_EXT (vacio: igual al interno) y
# PUERTO_HEX_GHOST. Se llama al arrancar y tras "actualizar_canales", porque
# una lista nueva puede traer otro puerto.
fijar_puerto_ghost() {
	local detectado origen
	if es_puerto "$GHOST_PORT_CONF"; then
		GHOST_PORT_INT="$GHOST_PORT_CONF"
		origen="fijado en $CONF"
	else
		[ "$GHOST_PORT_CONF" != "auto" ] && registrar "ATENCION: GHOST_PORT_INT='$GHOST_PORT_CONF' no es un puerto ni 'auto'; se detecta de la lista"
		detectado=$(detectar_puerto_ghost "$GHOSTLIST")
		if es_puerto "$detectado"; then
			GHOST_PORT_INT="$detectado"
			origen="detectado en las URLs de $GHOSTLIST"
		else
			GHOST_PORT_INT=3138
			origen="no se ha podido detectar en $GHOSTLIST, se usa el de fabrica"
		fi
	fi
	if es_puerto "$GHOST_PORT_EXT_CONF"; then
		GHOST_PORT_EXT="$GHOST_PORT_EXT_CONF"
	else
		[ -n "$GHOST_PORT_EXT_CONF" ] && registrar "ATENCION: GHOST_PORT_EXT='$GHOST_PORT_EXT_CONF' no es un puerto valido; se usa el interno"
		GHOST_PORT_EXT="$GHOST_PORT_INT"
	fi
	printf -v PUERTO_HEX_GHOST '%04X' "$GHOST_PORT_INT"
	registrar "Puerto de ghostreamy: $GHOST_PORT_INT ($origen) | externo $GHOST_PORT_EXT"
}

# Puertos en hexadecimal, tal como aparecen en /proc/net/tcp (printf -v no
# lanza ningun proceso). El de ghostreamy lo calcula fijar_puerto_ghost.
printf -v PUERTO_HEX_NATIVO '%04X' "$STREAMPORT_NATIVO"
fijar_puerto_ghost

# Conexiones a ghostreamy que NO tienen un stream detras (alguien navegando
# por su web, bajando la guia o los picons): no se anuncian. Mientras una
# conexion siga viva sin canal asociado se reintenta la resolucion en cada
# ciclo durante ALTA_REINTENTOS ciclos (por si ghostreamy tarda en pedir el
# canal a Enigma2) y despues solo una vez cada ALTA_REINTENTO_LENTO ciclos.
ALTA_REINTENTOS=8
ALTA_REINTENTO_LENTO=12

# ============================================================

URL="https://api.telegram.org/bot$TOKEN/sendMessage"
URL_DOC="https://api.telegram.org/bot$TOKEN/sendDocument"

# Variables de control del bucle principal:
#   errore      bandera del bucle ("while errore == 0"). Nunca se pone a 1: el
#               bot solo se cierra con el comando exit.
#   ciclos      ciclos completados (1 ciclo = ~5 s); solo sirve para el latido.
#   fallos_red  ciclos seguidos sin respuesta valida de Telegram (para no
#               llenar el log si el deco se queda sin Internet).
#   myip, myip_ts, IP_TTL   cache de la IP publica (ver obtener_ip_publica).
errore=0
ciclos=0
fallos_red=0
# IP publica: se consulta una vez al arrancar y despues solo bajo demanda
# (ver obtener_ip_publica())
myip=""
myip_ts=0
IP_TTL=300

registrar "Configuracion ($(pwd)/$CONF): TOKEN presente (${#TOKEN} caracteres, no se registra) | ID $ID | WEBIF $WEBIF${WEBIF_USUARIO:+ (usuario $WEBIF_USUARIO)} | lista $GHOSTLIST${GHOSTLIST_URL:+ (descarga: $(url_lista_segura "$GHOSTLIST_URL"))} | puertos ghostreamy $GHOST_PORT_INT->$GHOST_PORT_EXT | puerto nativo $STREAMPORT_NATIVO | grabaciones $GRABACIONES"

# ============================================================

# FUNCION PARA ENVIAR MENSAJES A TELEGRAM

# ============================================================

# telegram "texto": manda un mensaje de texto plano a $ID (puede ser de varias
# lineas). Si Telegram no contesta ok se registra ATENCION, pero no se
# reintenta ni se aborta nada. Para texto con formato ver telegram_html.
telegram() {
	respuesta_tg=$(curl -s --max-time 15 -X POST "$URL" -d "chat_id=$ID" --data-urlencode "text=$1" 2>&1)

	# Solo la primera linea del mensaje, para que "lista" no vuelque los
	# 200 canales en el log.
	resumen_tg=$(printf '%s' "$1" | head -n 1 | cut -c1-120)

	if printf '%s' "$respuesta_tg" | grep -q '"ok":true'; then
		registrar "Telegram OK -> $resumen_tg"
	else
		registrar "ATENCION: Telegram NO ha aceptado el mensaje -> $resumen_tg | respuesta: $(resumir "$respuesta_tg")"
	fi
}

# ============================================================

# VARIANTE EN HTML/MONOESPACIADO (parse_mode=HTML)
#
# Para tablas como la de "lista": en texto normal, Telegram usa una
# fuente proporcional y ni el relleno con espacios ni los tabuladores
# alinean columnas de forma fiable. Envuelto en <pre>...</pre> con
# parse_mode=HTML, Telegram sí lo muestra en monoespaciado y los
# espacios s­í alinean. escapar_html() debe aplicarse SIEMPRE al
# contenido antes de meterlo aqui (nombres de canal, etc.), para que
# un "&", "<" o ">" suelto no rompa el parseo.

# ============================================================

escapar_html() {
	printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

telegram_html() {
	respuesta_tg=$(curl -s --max-time 15 -X POST "$URL" -d "chat_id=$ID" -d "parse_mode=HTML" --data-urlencode "text=$1" 2>&1)

	resumen_tg=$(printf '%s' "$1" | head -n 1 | cut -c1-120)

	if printf '%s' "$respuesta_tg" | grep -q '"ok":true'; then
		registrar "Telegram OK (HTML) -> $resumen_tg"
	else
		registrar "ATENCION: Telegram NO ha aceptado el mensaje HTML -> $resumen_tg | respuesta: $(resumir "$respuesta_tg")"
	fi
}

# ============================================================

# ENVIO DE FICHEROS A TELEGRAM (comando "log")
#
# sendDocument, no sendMessage: hace falta multipart/form-data
# (-F en vez de -d) para adjuntar el fichero. filename=log.txt fuerza
# el nombre con el que le llega al usuario, aunque en disco se llame
# botikor.log.

# ============================================================

telegram_documento() {
	ruta="$1"
	nombre="$2"

	if [ ! -s "$ruta" ]; then
		registrar "ATENCION: '$ruta' no existe o esta vacio, no se envia"
		telegram "El fichero '$ruta' no existe o esta vacio"
		return 1
	fi

	respuesta_tg=$(curl -s --max-time 30 -X POST "$URL_DOC" -F "chat_id=$ID" -F "document=@${ruta};filename=${nombre}" 2>&1)

	if printf '%s' "$respuesta_tg" | grep -q '"ok":true'; then
		registrar "Telegram OK -> enviado $ruta como $nombre ($(wc -c < "$ruta" 2>/dev/null) bytes)"
	else
		registrar "ATENCION: Telegram NO ha aceptado el documento $ruta -> $(resumir "$respuesta_tg")"
	fi
}

# ============================================================

# ORDENES DE ENCENDIDO/APAGADO VIA OPENWEBIF
#
# Centralizadas aqui para que todas registren igual el codigo de salida
# y la respuesta del deco. newstate: 1=apagado profundo, 2=reinicio,
# 3=reinicio de enigma2, 4=salir de standby, 5=standby.

# ============================================================

powerstate() {
	estado="$1"
	descripcion="$2"

	registrar "Enviando a OpenWebIF powerstate=$estado ($descripcion)"

	respuesta_ws=$(curl -s -S -f --max-time 5 "${WEBIF_AUTH[@]}" "$WEBIF/api/powerstate?newstate=$estado" 2>&1)
	rc_ws=$?

	if [ "$rc_ws" -eq 0 ]; then
		registrar "OpenWebIF powerstate=$estado OK -> $(resumir "$respuesta_ws")"
	else
		registrar "ATENCION: OpenWebIF powerstate=$estado ha fallado (curl rc=$rc_ws) -> $(resumir "$respuesta_ws")"
	fi

	return $rc_ws
}

# ============================================================

# CORTE DE STREAMS SIN REINICIAR ENIGMA2 ("parar_stream")
#
# OpenWebIF no tiene ninguna llamada para esto: solo LEE los clientes de
# streaming. Cortarlos de verdad (lo que hace el boton azul de "Info de
# streams" del mando) exige llamar a eStreamServer.stopStream() DENTRO
# del proceso de Enigma2, algo a lo que un script externo no llega.
#
# Alternativa sin tocar Enigma2 ni instalar nada en el deco: cerrar la
# conexion TCP por la via de red, mandando un RST falsificado al lado
# SERVIDOR de cada conexion (Enigma2 en el 8001, ghostreamy en el
# 3138), que es el que sigue mandando video. Al morir su socket el
# stream se para, y el cliente se entera porque el kernel del deco le
# contesta con RST a lo que le siga mandando. Se cortan los dos puertos
# a la vez, asi caen tanto los clientes directos como los de ghostreamy.
#
# Detalle clave (RFC 5961, kernel >= 3.6): el kernel solo acepta un RST
# si su seq es EXACTAMENTE el siguiente que espera. Si cae dentro de la
# ventana pero no coincide, lo ignora y contesta con un "challenge ACK"
# (es lo que hacia fallar la version anterior, que se pasaba por 1 en
# los ACK puros). El seq se saca de un paquete esnifado de esa conexion:
#   - de un paquete cliente->servidor: su seq + bytes de datos (un ACK
#     puro ocupa 0; SYN y FIN ocupan 1 cada uno);
#   - de un paquete servidor->cliente: su campo ACK, que es justo el
#     seq que el servidor espera del cliente (el truco de tcpkill).
# Sirve cualquiera de los dos, no hace falta ver los dos sentidos. Y el
# seq del cliente no avanza mientras solo manda ACKs, asi que el RST no
# se queda viejo aunque el video siga fluyendo. Por la misma razon NO
# se manda RST al lado cliente: su seq avanza con cada paquete de video
# y siempre llegaria tarde.
#
# Se reintenta hasta 8s: cada 0,5s se relee /proc/net/tcp y, mientras
# la conexion siga ESTABLISHED, se manda otro RST con el seq del ultimo
# paquete visto. Asi tambien se corta a un cliente que reconecte solo.
#
# Necesita python3 como root con sockets AF_PACKET y raw IP (el bot ya
# corre como root en el deco). No necesita iptables ni deja nada
# instalado ni ninguna regla que haya que quitar despues. Solo IPv4
# (o IPv6 mapeado, que es como aparece el IPv4 en /proc/net/tcp6).
#
# Deja en CORTE_ANTES / CORTE_CORTADAS / CORTE_RST / CORTE_CHALLENGE /
# CORTE_CLIENTES / CORTE_DETALLE / CORTE_ERROR lo que informa el script y
# en RESTANTES las conexiones
# que siguen abiertas pasados unos segundos. OJO: CORTADAS son las
# conexiones que de verdad han desaparecido de /proc/net/tcp, no los RST
# enviados (esos son CORTE_RST). Un solo stream puede ser varias
# conexiones (ghostreamy abre una hacia el cliente y otra, interna, al
# 8001, y si algo reconecta salen mas), asi que a Telegram se le cuentan
# CLIENTES = IPs distintas, no conexiones. CORTE_CHALLENGE es lo que ha subido el
# contador TCPChallengeACK del kernel durante el corte: si sube y no se
# corta nada, los RST llegan pero con un seq que no es el exacto.

# ============================================================

parar_streams() {
	CORTE_ANTES=""
	CORTE_CORTADAS=""
	CORTE_RST=""
	CORTE_CHALLENGE=""
	CORTE_CLIENTES=""
	CORTE_NCLIENTES=0
	CORTE_DETALLE=""
	CORTE_ERROR=""
	RESTANTES=""

	registrar "Cortando streams por RST en los puertos $STREAMPORT_NATIVO y $GHOST_PORT_INT"

	resultado=$(python3 - "$STREAMPORT_NATIVO" "$GHOST_PORT_INT" 2>&1 <<-'PYEOF'
	import socket
	import struct
	import sys
	import time

	PLAZO = 8.0       # segundos maximos intentando cortar
	PAUSA_RST = 0.3   # minimo entre dos RST a la misma conexion
	CHEQUEO = 0.5     # cada cuanto se relee /proc/net/tcp

	OMITIDAS_IPV6 = []


	def decode_addr(campo):
	    iphex, porthex = campo.split(":")
	    port = int(porthex, 16)
	    if len(iphex) == 8:
	        ip = socket.inet_ntoa(struct.pack("<I", int(iphex, 16)))
	    else:
	        raw = b"".join(bytes.fromhex(iphex[i:i + 8])[::-1] for i in range(0, 32, 8))
	        ip6 = socket.inet_ntop(socket.AF_INET6, raw)
	        ip = ip6.split(":")[-1] if ip6.startswith("::ffff:") else ip6
	    return ip, port


	def leer_conexiones(puertos):
	    """Conexiones ESTABLISHED cuyo puerto local esta en `puertos`, como
	    conjunto de tuplas (ip_local, puerto_local, ip_remota, puerto_remoto)."""
	    conexiones = set()
	    for ruta in ("/proc/net/tcp", "/proc/net/tcp6"):
	        try:
	            with open(ruta) as f:
	                lineas = f.readlines()[1:]
	        except FileNotFoundError:
	            continue
	        for linea in lineas:
	            campos = linea.split()
	            if len(campos) < 4 or campos[3] != "01":  # 01 = ESTABLISHED
	                continue
	            lip, lport = decode_addr(campos[1])
	            rip, rport = decode_addr(campos[2])
	            if lport not in puertos:
	                continue
	            if ":" in lip or ":" in rip:  # IPv6 de verdad: no se sabe cortar
	                OMITIDAS_IPV6.append("%s:%d" % (rip, rport))
	                continue
	            conexiones.add((lip, lport, rip, rport))
	    return conexiones


	def challenge_acks():
	    """Contador del kernel de 'challenge ACK' (RFC 5961). Sube cuando llega
	    un RST con seq dentro de la ventana pero NO exacto: el kernel lo ignora."""
	    try:
	        with open("/proc/net/netstat") as f:
	            lineas = f.read().splitlines()
	    except OSError:
	        return None
	    for i in range(0, len(lineas) - 1, 2):
	        if lineas[i].startswith("TcpExt:"):
	            nombres = lineas[i].split()[1:]
	            valores = lineas[i + 1].split()[1:]
	            if "TCPChallengeACK" in nombres:
	                return int(valores[nombres.index("TCPChallengeACK")])
	    return None


	def checksum(data):
	    if len(data) % 2:
	        data += b"\x00"
	    s = sum(struct.unpack("!%dH" % (len(data) // 2), data))
	    while s >> 16:
	        s = (s & 0xFFFF) + (s >> 16)
	    return (~s) & 0xFFFF


	def build_rst(src_ip, src_port, dst_ip, dst_port, seq):
	    ip_hdr_nocsum = struct.pack(
	        "!BBHHHBBH4s4s", 0x45, 0, 40, 0, 0, 64, socket.IPPROTO_TCP, 0,
	        socket.inet_aton(src_ip), socket.inet_aton(dst_ip),
	    )
	    ip_csum = checksum(ip_hdr_nocsum)
	    ip_hdr = struct.pack(
	        "!BBHHHBBH4s4s", 0x45, 0, 40, 0, 0, 64, socket.IPPROTO_TCP, ip_csum,
	        socket.inet_aton(src_ip), socket.inet_aton(dst_ip),
	    )
	    offset_flags = (5 << 12) | 0x04  # RST
	    tcp_nocsum = struct.pack("!HHIIHHHH", src_port, dst_port, seq, 0, offset_flags, 0, 0, 0)
	    pseudo = struct.pack("!4s4sBBH", socket.inet_aton(src_ip), socket.inet_aton(dst_ip), 0, socket.IPPROTO_TCP, 20)
	    tcp_csum = checksum(pseudo + tcp_nocsum)
	    tcp_hdr = struct.pack("!HHIIHHHH", src_port, dst_port, seq, 0, offset_flags, 0, tcp_csum, 0)
	    return ip_hdr + tcp_hdr


	def parse_ip_tcp(paquete):
	    """Devuelve (src_ip, sport, dst_ip, dport, seq, ack, payload_len, flags) o None."""
	    if len(paquete) < 34:
	        return None
	    if paquete[12:14] != b"\x08\x00":  # solo IPv4
	        return None
	    ip = paquete[14:34]
	    ihl = (ip[0] & 0x0F) * 4
	    if ip[9] != socket.IPPROTO_TCP:
	        return None
	    src_ip = socket.inet_ntoa(ip[12:16])
	    dst_ip = socket.inet_ntoa(ip[16:20])
	    tcp_off = 14 + ihl
	    if len(paquete) < tcp_off + 20:
	        return None
	    tcp = paquete[tcp_off:tcp_off + 20]
	    sport, dport, seq, ack = struct.unpack("!HHII", tcp[0:12])
	    data_off = (tcp[12] >> 4) * 4
	    flags = tcp[13]
	    total_ip_len = struct.unpack("!H", ip[2:4])[0]
	    payload_len = max(total_ip_len - ihl - data_off, 0)
	    return src_ip, sport, dst_ip, dport, seq, ack, payload_len, flags


	def main():
	    puertos = set(int(p) for p in sys.argv[1:])
	    if not puertos:
	        print("0|0|0|?|||uso: PUERTO [PUERTO ...]")
	        sys.exit(1)

	    inicial = leer_conexiones(puertos)
	    if not inicial:
	        extra = "IPv6 sin soporte: " + ", ".join(OMITIDAS_IPV6[:3]) if OMITIDAS_IPV6 else ""
	        print("0|0|0|0|||%s" % extra)
	        return

	    try:
	        sniff = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(0x0003))
	        sniff.settimeout(0.2)
	        envio = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_TCP)
	        envio.setsockopt(socket.IPPROTO_IP, socket.IP_HDRINCL, 1)
	    except OSError as e:
	        print("%d|0|0|?|||no se pueden abrir sockets AF_PACKET/RAW (hace falta root): %s" % (len(inicial), e))
	        return

	    challenge_antes = challenge_acks()
	    vivas = set(inicial)
	    vistas = set(inicial)   # todas las conexiones que se han visto, incluidas reconexiones
	    orden = sorted(inicial) # las mismas en orden de aparicion (solo para el log)
	    ultimo_rst = {}
	    rst_enviados = 0
	    proximo_chequeo = 0.0
	    fin = time.time() + PLAZO

	    while time.time() < fin:
	        ahora = time.time()
	        if ahora >= proximo_chequeo:
	            vivas = leer_conexiones(puertos)
	            orden.extend(sorted(vivas - vistas))
	            vistas |= vivas
	            proximo_chequeo = ahora + CHEQUEO
	            if not vivas:
	                break

	        try:
	            paquete = sniff.recv(65535)
	        except socket.timeout:
	            continue
	        info = parse_ip_tcp(paquete)
	        if not info:
	            continue
	        src_ip, sport, dst_ip, dport, seq, ack, plen, flags = info
	        if flags & 0x04:  # ignora RST ajenos
	            continue

	        # clave = (ip_local, puerto_local, ip_remota, puerto_remota), como en /proc.
	        # "Local" es el lado servidor (Enigma2 o ghostreamy); es al que se manda el RST.
	        if (dst_ip, dport, src_ip, sport) in vivas:
	            # cliente -> servidor. El siguiente seq que espera el servidor es
	            # exactamente el seq de este paquete + lo que ocupa (datos, SYN, FIN).
	            clave = (dst_ip, dport, src_ip, sport)
	            seq_rst = seq + plen + (1 if flags & 0x02 else 0) + (1 if flags & 0x01 else 0)
	        elif (src_ip, sport, dst_ip, dport) in vivas:
	            # servidor -> cliente. El campo ACK de este paquete es justo el seq
	            # que el servidor espera del cliente (truco de tcpkill).
	            if not flags & 0x10:
	                continue
	            clave = (src_ip, sport, dst_ip, dport)
	            seq_rst = ack
	        else:
	            continue

	        if ahora - ultimo_rst.get(clave, 0.0) < PAUSA_RST:
	            continue
	        ultimo_rst[clave] = ahora

	        lip, lport, rip, rport = clave
	        # RST que parece venir del cliente, para cerrar el socket del servidor.
	        # El seq tiene que ser EXACTO (RFC 5961): uno solo, sin margenes.
	        envio.sendto(build_rst(rip, rport, lip, lport, seq_rst & 0xFFFFFFFF), (lip, 0))
	        rst_enviados += 1

	    sniff.close()
	    envio.close()

	    finales = leer_conexiones(puertos)
	    cortadas = len(vistas - finales)
	    # Clientes = IPs distintas (no loopback) que se quedan sin ninguna
	    # conexion. Las conexiones internas de ghostreamy (127.0.0.1) y las
	    # reconexiones del mismo cliente NO cuentan como otro stream.
	    ips_vistas = set(c[2] for c in vistas if not c[2].startswith("127."))
	    ips_vivas = set(c[2] for c in finales)
	    clientes = sorted(ips_vistas - ips_vivas)
	    detalle = ",".join("%s:%d>%d" % (c[2], c[3], c[1]) for c in orden)[:300]
	    challenge_despues = challenge_acks()
	    if challenge_antes is None or challenge_despues is None:
	        challenge = "?"
	    else:
	        challenge = str(challenge_despues - challenge_antes)

	    errores = []
	    if OMITIDAS_IPV6:
	        errores.append("IPv6 sin soporte: " + ", ".join(sorted(set(OMITIDAS_IPV6))[:3]))
	    if finales and rst_enviados == 0:
	        errores.append("sin trafico visible de la conexion en %.0fs, no se pudo capturar el seq" % PLAZO)
	    resumen_error = "; ".join(errores)[:200].replace("|", "/").replace("\n", " ")

	    print("%d|%d|%d|%s|%s|%s|%s" % (len(inicial), cortadas, rst_enviados, challenge,
	                                  ",".join(clientes), detalle, resumen_error))


	if __name__ == "__main__":
	    main()
		PYEOF
	)
	rc_python=$?

	if [ "$rc_python" -ne 0 ]; then
		CORTE_ERROR=$(resumir "$resultado")
		registrar "ATENCION: el script de corte ha fallado (rc=$rc_python) -> $CORTE_ERROR"
		return 2
	fi

	IFS='|' read -r CORTE_ANTES CORTE_CORTADAS CORTE_RST CORTE_CHALLENGE CORTE_CLIENTES CORTE_DETALLE CORTE_ERROR <<-EOF
		$resultado
		EOF

	# Numero de clientes distintos (IPs) cortados, para el mensaje de Telegram.
	if [ -n "$CORTE_CLIENTES" ]; then
		CORTE_NCLIENTES=$(printf '%s' "$CORTE_CLIENTES" | tr ',' '\n' | grep -c .)
	fi

	# Python ya ha comprobado en /proc/net/tcp que las conexiones
	# desaparecen. Este margen es solo para ver si el cliente (o
	# ghostreamy) reconecta por su cuenta.
	if [ "${CORTE_ANTES:-0}" -gt 0 ]; then
		sleep 2
	fi

	RESTANTES=$(cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | awk -v p1=":$(printf '%04X' "$STREAMPORT_NATIVO")" -v p2=":$(printf '%04X' "$GHOST_PORT_INT")" '$4 == "01" && ($2 ~ p1"$" || $2 ~ p2"$")' | grep -c .)
	RESTANTES=${RESTANTES:-0}

	registrar "Corte de streams: antes=${CORTE_ANTES:-?} conexiones_cortadas=${CORTE_CORTADAS:-?} clientes='${CORTE_CLIENTES}' rst=${CORTE_RST:-?} challenge_ack=${CORTE_CHALLENGE:-?} error='${CORTE_ERROR}' detalle=[${CORTE_DETALLE}] | conexiones en los puertos $STREAMPORT_NATIVO/$GHOST_PORT_INT tras 2s: $RESTANTES"

	return 0
}

# ============================================================

# IP PUBLICA (AL ARRANCAR Y BAJO DEMANDA)
#
# La IP publica solo se necesita para montar las URLs del comando
# "canal N". Se consulta una vez al arrancar (queda en el log, con el
# aviso de cambio si ya habia otra) y luego solo cuando "canal N" la
# pide; NO se consulta en el bucle principal (antes se hacia un curl a
# ipinfo.io en cada ciclo, ~17.000 al dia). Ya no se etiqueta a los
# clientes de ghostreamy como "locales": Streaming_list da el canal
# igualmente y la etiqueta era solo informativa.
#
# Se guarda en $myip con la hora de la consulta ($myip_ts) y se reutiliza
# durante IP_TTL segundos, asi que aunque se llame varias veces seguidas
# solo sale una consulta. Si la consulta falla se conserva la ultima IP
# conocida (si la hay) y devuelve 1; quien llama debe mirar si $myip esta
# vacio antes de usarla.

# ============================================================

obtener_ip_publica() {
	ip_ahora=$(date +%s 2>/dev/null)
	ip_ahora=${ip_ahora:-0}

	# Cache valida: hay IP, la hora es fiable y no ha pasado el TTL (si el
	# reloj ha retrocedido, por un ajuste de NTP, tambien se vuelve a consultar).
	if [ -n "$myip" ] && [ "$ip_ahora" -gt 0 ] && [ "$ip_ahora" -ge "$myip_ts" ] && [ $((ip_ahora - myip_ts)) -lt "$IP_TTL" ]; then
		return 0
	fi

	myip_nueva=$(curl -s --max-time 5 ipinfo.io/ip)

	# Si el servicio devuelve una pagina de error en vez de una IP, se
	# descarta: solo se acepta algo formado por digitos y puntos.
	case "$myip_nueva" in
		""|*[!0-9.]*) myip_nueva="" ;;
	esac

	if [ -z "$myip_nueva" ]; then
		registrar "ATENCION: no se ha podido consultar la IP publica (ipinfo.io). Se mantiene la ultima conocida: ${myip:-(ninguna)}"
		return 1
	fi

	if [ "$myip_nueva" != "$myip" ]; then
		registrar "IP publica: ${myip:-(desconocida)} -> $myip_nueva"
		myip="$myip_nueva"
	fi

	myip_ts=$ip_ahora
	return 0
}

# ============================================================

# ESTADO DE LOS STREAMS: FUNCIONES DE APOYO
#
# El estado se guarda como texto delimitado por tabuladores en variables
# normales (sin arrays ni declare -A), una linea por stream:
#
#   VIVOS    tipo  ip  puerto                     lo que hay conectado ahora
#   PEND     tipo  ip  puerto  ciclos  visto      vistos pero sin confirmar
#   ESTADO   tipo  ip  puerto  canal   inicio     confirmados (anunciados)
#
# "tipo" es "directo" (cliente al puerto nativo) o "ghostreamy" (cliente al
# puerto de ghostreamy); "puerto" es el puerto de ORIGEN del cliente, asi que
# dos ventanas de VLC desde la misma IP son dos streams distintos. "inicio" y
# "visto" son valores de $SECONDS (segundos desde que arranco el script: no
# los afectan los saltos de hora por NTP y no hace falta lanzar `date`).
# Un canal desconocido se guarda como "-" (un campo vacio no vale: el
# tabulador es IFS "blanco" y `read` colapsaria los tabuladores seguidos).
#
# Todas estas funciones trabajan solo con texto y builtins de bash (sin
# lanzar procesos), salvo las dos que llaman a python3, que solo se ejecutan
# cuando hace falta.

# ============================================================

TAB=$'\t'
NL=$'\n'

VIVOS=""
PEND=""
ESTADO=""
N_ESTADO=0
RAW_PREVIO=""
fallos_decod=0

# agregar_linea NOMBRE_VARIABLE "linea": anade una linea al final de la variable.
agregar_linea() {
	if [ -n "${!1}" ]; then
		printf -v "$1" '%s\n%s' "${!1}" "$2"
	else
		printf -v "$1" '%s' "$2"
	fi
}

# contar_lineas "texto": deja en N_LINEAS el numero de lineas no vacias.
contar_lineas() {
	local texto="$1" solo_nl
	if [ -z "$texto" ]; then
		N_LINEAS=0
	else
		solo_nl="${texto//[^$NL]/}"
		N_LINEAS=$(( ${#solo_nl} + 1 ))
	fi
}

# clave_en "lineas" "clave": ¿hay alguna linea que empiece por esa clave
# (tipo TAB ip TAB puerto), sea la linea solo la clave o la clave + mas campos?
clave_en() {
	case "$NL$1$NL" in
		*"$NL$2$TAB"*|*"$NL$2$NL"*) return 0 ;;
	esac
	return 1
}

# duracion_txt SEGUNDOS: deja en DUR_TXT "45 s", "12 min" o "1 h 05 min".
duracion_txt() {
	local s=$1
	[ "$s" -ge 0 ] 2>/dev/null || s=0
	if [ "$s" -lt 60 ]; then
		printf -v DUR_TXT '%d s' "$s"
	elif [ "$s" -lt 3600 ]; then
		printf -v DUR_TXT '%d min' $((s / 60))
	else
		printf -v DUR_TXT '%d h %02d min' $((s / 3600)) $(((s % 3600) / 60))
	fi
}

# lista_activos: deja en LISTA_ACTIVOS el texto con los streams de $ESTADO.
lista_activos() {
	local l_tipo l_ip l_puerto l_canal l_inicio
	LISTA_ACTIVOS="Streams activos:"
	while IFS=$'\t' read -r l_tipo l_ip l_puerto l_canal l_inicio; do
		[ -n "$l_tipo" ] || continue
		[ "$l_canal" = "-" ] && l_canal=""
		LISTA_ACTIVOS="$LISTA_ACTIVOS$NL• $l_ip (vía $l_tipo)${l_canal:+ — $l_canal}"
	done <<< "$ESTADO"
}

# decodificar_conexiones "RAW": convierte las lineas "puertoHEX ipHEX:puertoHEX"
# que saca el awk del bucle en lineas "tipo ip puerto" (una por conexion real).
# Descarta las loopback: son las conexiones internas de ghostreamy al 8001
# (el propio ghostreamy tirando del canal), no un stream en si. Los datos
# entran por variable de entorno porque el stdin de python3 lo ocupa el
# propio codigo del heredoc (un pipe mas heredoc no funciona).
decodificar_conexiones() {
	RAW="$1" P_GHOST="$PUERTO_HEX_GHOST" python3 - <<-'PYEOF'
	import os
	import socket
	import struct
	import ipaddress

	def decode(a):
	    iphex, porthex = a.split(':')
	    puerto = int(porthex, 16)
	    if len(iphex) == 8:
	        ip = socket.inet_ntoa(struct.pack('<I', int(iphex, 16)))
	    else:
	        raw = b''.join(bytes.fromhex(iphex[i:i + 8])[::-1] for i in range(0, 32, 8))
	        ip = socket.inet_ntop(socket.AF_INET6, raw)
	        if ip.startswith('::ffff:'):
	            ip = ip.split(':')[-1]
	    return ip, puerto

	ghost = os.environ.get('P_GHOST', '').upper()
	salida = set()
	for linea in os.environ.get('RAW', '').splitlines():
	    try:
	        local, remoto = linea.split()
	        ip, puerto = decode(remoto)
	        if ipaddress.ip_address(ip).is_loopback:
	            continue
	    except Exception:
	        continue
	    via = 'ghostreamy' if local.upper() == ghost else 'directo'
	    salida.add((via, ip, puerto))

	for via, ip, puerto in sorted(salida):
	    print('%s\t%s\t%d' % (via, ip, puerto))
	PYEOF
}

# resolver_canales "json de statusinfo" "ESTADO actual" "NUEVOS": averigua el
# canal de cada stream recien confirmado con UNA sola consulta a OpenWebIF.
# Streaming_list trae entradas "IP: Canal - Programa":
#   - un cliente directo casa con la entrada de su misma IP;
#   - ghostreamy free solo admite un cliente a la vez y su conexion interna
#     es loopback, asi que cualquier entrada loopback es de un stream
#     ghostreamy.
# Las entradas que ya corresponden a streams anunciados se descuentan
# primero (asi, dos ventanas desde la misma IP no se pisan el canal).
# Entrada: NUEVOS = "tipo ip puerto visto". Salida: "tipo ip puerto canal visto".
# Valor del campo canal en la salida (desde la 3.1.13):
#   nombre   el canal que ve ese stream segun Streaming_list;
#   -        canal desconocido: se anuncia el stream sin canal (tambien si
#            OpenWebIF no respondio o no trajo Streaming_list);
#   !        conexion a ghostreamy SIN stream detras (alguien navegando por su
#            web, la guia, los picons...): NO se anuncia; el bucle principal la
#            devuelve a PEND conservando su contador.
# Las entradas de Streaming_list se reparten primero a las conexiones MAS
# RECIENTES (campo "visto" mayor): si hay un navegador abierto desde antes y
# llega un stream, el canal es del stream. Los campos que sobran en la
# entrada (el contador de ciclos) viajan intactos como ultima columna.
resolver_canales() {
	SL_JSON="$1" ESTADO_ACT="$2" NUEVOS="$3" python3 - <<-'PYEOF'
	import os
	import json
	import ipaddress

	def es_loopback(ip):
	    try:
	        return ipaddress.ip_address(ip).is_loopback
	    except ValueError:
	        return False

	def norm(ip):
	    return ip.split(':')[-1] if ip.startswith('::ffff:') else ip

	# leido_ok: OpenWebIF respondio con un JSON que trae Streaming_list. Solo
	# entonces se puede afirmar que una conexion a ghostreamy no tiene stream.
	leido_ok = False
	try:
	    datos = json.loads(os.environ.get('SL_JSON') or '{}')
	    leido_ok = isinstance(datos, dict) and 'Streaming_list' in datos
	    sl = datos.get('Streaming_list') or ''
	except Exception:
	    sl = ''
	if isinstance(sl, list):
	    sl = '\n'.join(str(x) for x in sl)
	if not isinstance(sl, str):
	    sl = ''

	entradas = []  # [ip, canal, usada]
	for l in sl.splitlines():
	    l = l.strip()
	    if not l:
	        continue
	    if ': ' in l:
	        ip, resto = l.split(': ', 1)
	        ip = norm(ip.strip())
	    else:
	        ip, resto = '', l
	    entradas.append([ip, resto.split(' - ', 1)[0].strip(), False])

	# Devuelve el canal (puede ser '') o None si no hay entrada que case.
	def tomar(via, ip, preferido=''):
	    cands = [e for e in entradas if not e[2] and e[0] != ''
	             and (es_loopback(e[0]) if via == 'ghostreamy' else e[0] == ip)]
	    cands += [e for e in entradas if not e[2] and e[0] == '']
	    if preferido:
	        for e in cands:
	            if e[1] == preferido:
	                e[2] = True
	                return e[1]
	    if cands:
	        cands[0][2] = True
	        return cands[0][1]
	    return None

	for l in os.environ.get('ESTADO_ACT', '').splitlines():
	    c = l.split('\t')
	    if len(c) >= 4:
	        tomar(c[0], c[1], '' if c[3] == '-' else c[3])

	nuevos = []
	for l in os.environ.get('NUEVOS', '').splitlines():
	    c = l.split('\t')
	    if len(c) >= 4:
	        nuevos.append(c)

	def visto(c):
	    try:
	        return int(c[3])
	    except ValueError:
	        return 0

	# Las entradas se reparten primero a las conexiones MAS RECIENTES: si hay
	# una conexion vieja (navegador abierto) y otra nueva (el stream real),
	# el canal es de la nueva.
	resultado = {}
	for i in sorted(range(len(nuevos)), key=lambda i: -visto(nuevos[i])):
	    c = nuevos[i]
	    canal = tomar(c[0], c[1])
	    if canal is None:
	        # '!' = conexion a ghostreamy sin stream detras (no anunciar);
	        # '-' = canal desconocido (se anuncia sin canal, como siempre).
	        canal_txt = '!' if (c[0] == 'ghostreamy' and leido_ok) else '-'
	    else:
	        canal_txt = canal or '-'
	    resultado[i] = canal_txt

	# Salida en el orden original: tipo ip puerto canal visto [n]
	for i, c in enumerate(nuevos):
	    extra = '\t' + c[4] if len(c) > 4 else ''
	    print('%s\t%s\t%s\t%s\t%s%s' % (c[0], c[1], c[2], resultado[i], c[3], extra))
	PYEOF
}

# ============================================================

# CARGA DE CANALES DESDE EL M3U8 DE GHOSTREAMY
#
# Cada canal aparece dos veces en el m3u8 (normal y "?t=transcoding"),
# identificable de forma estable por el atributo tvg-name (el texto
# tras la coma en #EXTINF varía: "Canal " vs "Canal transcoding").
# Se genera canales.tsv (nombre / url normal / url transcodificada) y
# de ahí los ficheros canalnombres / canalurls / canalurlstrans, que
# se consultan por número de línea.

# ============================================================

cargar_canales() {
	python3 - "$GHOSTLIST" > canales.tsv 2>/dev/null <<-'PYEOF'
		import re, sys

		path = sys.argv[1]

		try:
		    with open(path, encoding="utf-8", errors="replace") as f:
		        lineas = [l.rstrip("\n") for l in f]
		except Exception:
		    sys.exit(1)

		canales = {}
		orden = []
		i = 0
		while i < len(lineas):
		    linea = lineas[i]
		    if linea.startswith("#EXTINF"):
		        m = re.search(r'tvg-name="([^"]*)"', linea)
		        nombre = m.group(1) if m else None
		        url = lineas[i + 1].strip() if i + 1 < len(lineas) else ""
		        if nombre and url.startswith("http"):
		            if nombre not in canales:
		                canales[nombre] = {"normal": "", "trans": ""}
		                orden.append(nombre)
		            if "t=transcoding" in url:
		                canales[nombre]["trans"] = url
		            else:
		                canales[nombre]["normal"] = url
		        i += 2
		    else:
		        i += 1

		for nombre in orden:
		    c = canales[nombre]
		    print(f"{nombre}\t{c['normal']}\t{c['trans']}")
		PYEOF

	if [ -s canales.tsv ]; then
		cut -f1 canales.tsv > canalnombres
		cut -f2 canales.tsv > canalurls
		cut -f3 canales.tsv > canalurlstrans
		registrar "Canales cargados desde $GHOSTLIST: $(grep -c . canalnombres 2>/dev/null)"
		return 0
	else
		registrar "ATENCION: no se han podido leer canales de $GHOSTLIST (no existe, esta vacio o tiene un formato inesperado)"
		return 1
	fi
}

# ============================================================

# AUTO-ACTUALIZACION DEL PROPIO SCRIPT ("actualizar_botikor")
#
# Descarga la última release de $REPO_GITHUB (con su huella SHA-256, ver
# descargar_verificado), lee su VERSION="X.Y.Z" y la compara con la
# local. Si es más nueva: valida sintaxis del fichero descargado,
# sobreescribe SCRIPT_PATH (la ruta real desde la que se lanzó, ver
# captura al principio del fichero) y relanza con exec, de forma que
# el proceso pasa a correr el código nuevo con el mismo PID.
#
# Si la versión no es más nueva, o falla la descarga/lectura de
# versión/sintaxis, no se toca nada y se informa por Telegram.

# ============================================================

# ============================================================

# INSTALACION DE UN SCRIPT YA DESCARGADO (comun a "actualizar_botikor" y
# "downgrade X")
#
# $1 = fichero descargado, $2 = version que contiene, $3 = verbo para el
# aviso de Telegram ("Actualizando" / "Cambiando"). Valida sintaxis, guarda
# copia de seguridad de la version actual en SCRIPT_PATH.anterior, instala y
# relanza con exec. La configuracion no se toca: vive en botikor.conf. Si
# algo falla no se toca el script instalado: borra el fichero descargado y
# devuelve 1. Si todo va bien no vuelve (exec).

# ============================================================

instalar_script_descargado() {
	tmp="$1"
	version_remota="$2"
	verbo="$3"

	if ! bash -n "$tmp" 2>/dev/null; then
		registrar "ATENCION: el script descargado (v$version_remota) no pasa bash -n, no se instala"
		telegram "El script descargado (v$version_remota) tiene errores de sintaxis, no lo instalo"
		rm -f "$tmp"
		return 1
	fi

	if cp "$SCRIPT_PATH" "$SCRIPT_PATH.anterior" 2>/dev/null; then
		registrar "Copia de seguridad de la v$VERSION en $SCRIPT_PATH.anterior"
	else
		registrar "ATENCION: no se ha podido guardar copia de seguridad de $SCRIPT_PATH"
	fi

	# Copia a un temporal junto al destino y mv: el script instalado nunca
	# queda a medio escribir.
	if ! cp "$tmp" "$SCRIPT_PATH.nuevo" || ! chmod +x "$SCRIPT_PATH.nuevo" || ! mv "$SCRIPT_PATH.nuevo" "$SCRIPT_PATH"; then
		registrar "INSTALACION ABORTADA: no se puede escribir $SCRIPT_PATH"
		telegram "No he podido instalar la v$version_remota (no se puede escribir $SCRIPT_PATH). Sigo en v$VERSION"
		rm -f "$tmp" "$SCRIPT_PATH.nuevo"
		return 1
	fi
	rm -f "$tmp"

	registrar "Instalada v$version_remota en $SCRIPT_PATH. Relanzando con exec (mismo PID $$)"

	telegram "$verbo BOTikor de v$VERSION a v$version_remota. Relanzando..."

	exec "$SCRIPT_PATH"
}

# ============================================================

# DESCARGA VERIFICADA DE UNA VERSION PUBLICADA (comun a "actualizar_botikor"
# y "downgrade X")
#
# $1 = URL base de una release de GitHub (.../releases/latest/download o
# .../releases/download/vX.Y.Z), $2 = fichero de destino. Descarga
# botikor.sh y botikor.sh.sha256 y comprueba que la huella SHA-256 del
# script coincide con la publicada. Si algo falla, borra lo descargado,
# avisa por Telegram y devuelve 1.
#
# SEGURIDAD: todo va por HTTPS y --proto/--proto-redir impiden que ni
# siquiera una redireccion baje a HTTP, asi que nadie en el camino puede
# cambiar el script. La huella detecta descargas cortadas o corruptas.
# Ninguna de las dos cosas protege si alguien entra en la cuenta de GitHub
# que publica las versiones: esa cuenta debe tener verificacion en dos pasos.

# ============================================================

descargar_verificado() {
	base="$1"
	destino="$2"
	huella_tmp="./botikor_nuevo.sha256"

	rm -f "$destino" "$huella_tmp"

	if ! error_curl=$(curl -fsSL --proto '=https' --proto-redir '=https' --max-time 30 -o "$destino" "$base/botikor.sh" 2>&1) || [ ! -s "$destino" ]; then
		registrar "ATENCION: descarga fallida o fichero vacio ($base/botikor.sh) $(resumir "$error_curl")"
		telegram "No se ha podido descargar el script ($base/botikor.sh)"
		rm -f "$destino"
		return 1
	fi

	if ! error_curl=$(curl -fsSL --proto '=https' --proto-redir '=https' --max-time 15 -o "$huella_tmp" "$base/botikor.sh.sha256" 2>&1); then
		registrar "ATENCION: descarga fallida de la huella ($base/botikor.sh.sha256) $(resumir "$error_curl")"
		telegram "No se ha podido descargar la huella SHA-256 del script, así que no lo instalo"
		rm -f "$destino" "$huella_tmp"
		return 1
	fi

	# Formato de sha256sum: "<64 cifras hex>  botikor.sh". Solo cuenta el
	# primer campo de la primera linea.
	huella_publicada=$(tr -d '\r' < "$huella_tmp" | awk 'NR == 1 { print tolower($1) }')
	rm -f "$huella_tmp"

	case "$huella_publicada" in
		*[!0-9a-f]*) huella_publicada="" ;;
	esac

	if [ ${#huella_publicada} -ne 64 ]; then
		registrar "ATENCION: el fichero de huella no contiene un SHA-256 valido. No se instala"
		telegram "La huella SHA-256 publicada no es válida, así que no instalo nada. Sigo en v$VERSION"
		rm -f "$destino"
		return 1
	fi

	huella_real=$(python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$destino" 2>/dev/null)

	if [ "$huella_real" != "$huella_publicada" ]; then
		registrar "ATENCION: la huella no coincide (publicada $huella_publicada, descargada ${huella_real:-?}). No se instala"
		telegram "El script descargado no coincide con su huella SHA-256 (descarga corrupta o alterada), así que no lo instalo. Sigo en v$VERSION"
		rm -f "$destino"
		return 1
	fi

	registrar "Descargados $(wc -c < "$destino" 2>/dev/null) bytes; huella SHA-256 correcta ($huella_real)"
	return 0
}

# Imprime la VERSION="X.Y.Z" que declara el fichero $1, o nada si no declara
# una con ese formato.
version_de() {
	grep -m1 '^VERSION=' "$1" 2>/dev/null | sed -E 's/^VERSION="?([0-9]+\.[0-9]+\.[0-9]+)"?.*/\1/' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'
}

actualizar_botikor() {

	tmp="./botikor_nuevo.sh"
	base="https://github.com/$REPO_GITHUB/releases/latest/download"

	registrar "Actualizacion solicitada. Descargando la ultima version de $base"

	descargar_verificado "$base" "$tmp" || return 1

	version_remota=$(version_de "$tmp")

	if [ -z "$version_remota" ]; then
		registrar "ATENCION: el fichero descargado no tiene una linea VERSION=\"X.Y.Z\" legible"
		telegram "No se ha podido leer la versión del script remoto"
		rm -f "$tmp"
		return 1
	fi

	es_mas_nueva=$(python3 - "$VERSION" "$version_remota" <<-'PYEOF' 2>/dev/null
		import sys
		def partes(v):
		    return tuple(int(x) for x in v.split("."))
		print("1" if partes(sys.argv[2]) > partes(sys.argv[1]) else "0")
		PYEOF
	)

	registrar "Version local v$VERSION, version remota v$version_remota"

	if [ "$es_mas_nueva" != "1" ]; then
		registrar "No se actualiza: la version remota no es mas nueva"
		telegram "BOTikor ya está actualizado (v$VERSION, remota v$version_remota)"
		rm -f "$tmp"
		return 0
	fi

	instalar_script_descargado "$tmp" "$version_remota" "Actualizando"
}

# ============================================================

# CAMBIO A UNA VERSION CONCRETA ("downgrade X")
#
# Cada vez que se lanza el comando se pide a la API de GitHub la lista de
# releases de $REPO_GITHUB (nunca se reutiliza una copia anterior). Solo
# cuentan las publicadas (no borradores) con etiqueta vX.Y.Z. X puede
# escribirse 4.0.0, v4.0.0 o 400; si sin puntos encaja con varias (3.1.11 y
# 31.1.1), se pide que se escriba con puntos. Si existe, se descarga y se
# instala igual que una actualizacion (huella SHA-256, validacion de
# sintaxis, copia en .anterior, exec), sea
# mas vieja o mas nueva que la instalada.
#
# Como red de seguridad, el script descargado debe declarar la VERSION
# pedida: si no, se aborta. Sin parametro, o con una version que no existe,
# se listan las disponibles. Si la pedida ya es la instalada, no se toca
# nada. La API admite 60 consultas por hora y por IP sin identificarse.

# ============================================================

downgrade_botikor() {
	numero_pedido="$1"
	lista_tmp="./botikor_versiones.tmp"
	tmp="./botikor_nuevo.sh"
	api="https://api.github.com/repos/$REPO_GITHUB/releases?per_page=100"

	registrar "Downgrade solicitado (parametro: '${numero_pedido}'). Consultando $api"

	if ! error_curl=$(curl -fsSL --proto '=https' --proto-redir '=https' --max-time 15 -H 'Accept: application/vnd.github+json' -o "$lista_tmp" "$api" 2>&1) || [ ! -s "$lista_tmp" ]; then
		registrar "ATENCION: consulta fallida o respuesta vacia ($api) $(resumir "$error_curl")"
		telegram "No se ha podido consultar la lista de versiones en GitHub"
		rm -f "$lista_tmp"
		return 1
	fi

	# Una version X.Y.Z por linea, de la mas nueva a la mas vieja.
	versiones=$(python3 - "$lista_tmp" <<-'PYEOF' 2>/dev/null
		import json, re, sys
		try:
		    with open(sys.argv[1], encoding="utf-8") as f:
		        releases = json.load(f)
		except Exception:
		    sys.exit(1)
		if not isinstance(releases, list):
		    sys.exit(1)
		lista = []
		for r in releases:
		    if not isinstance(r, dict) or r.get("draft"):
		        continue
		    m = re.fullmatch(r"v(\d+\.\d+\.\d+)", str(r.get("tag_name", "")))
		    if m and m.group(1) not in lista:
		        lista.append(m.group(1))
		lista.sort(key=lambda v: tuple(int(x) for x in v.split(".")), reverse=True)
		for v in lista:
		    print(v)
		PYEOF
	)
	rc_lista=$?
	rm -f "$lista_tmp"

	if [ "$rc_lista" -ne 0 ]; then
		registrar "ATENCION: la respuesta de la API de GitHub no es una lista de releases (¿limite de consultas?)"
		telegram "GitHub no ha devuelto la lista de versiones (quizá por el límite de consultas). Prueba dentro de un rato"
		return 1
	fi

	disponibles=$(printf '%s\n' "$versiones" | awk 'NF { printf "%s%s", (n++ ? ", " : ""), $0 }')

	case "$numero_pedido" in
		""|"downgrade"|*[!0-9.vV]*)
			registrar "Downgrade: parametro no valido '${numero_pedido}'. Disponibles: ${disponibles:-(ninguna)}"
			telegram "Uso: downgrade X (por ejemplo: downgrade 4.0.0)
Versiones disponibles: ${disponibles:-(ninguna)}"
			return 1
			;;
	esac

	pedido="${numero_pedido#[vV]}"

	case "$pedido" in
		*.*) version_pedida=$(printf '%s\n' "$versiones" | grep -Fx -- "$pedido") ;;
		*)   version_pedida=$(printf '%s\n' "$versiones" | awk -v k="$pedido" '{ c = $0; gsub(/\./, "", c); if (c == k) print }') ;;
	esac

	if [ -z "$version_pedida" ]; then
		registrar "Downgrade: la version '$numero_pedido' no esta publicada. Disponibles: ${disponibles:-(ninguna)}"
		telegram "La versión $numero_pedido no existe online. Versiones disponibles: ${disponibles:-(ninguna)}"
		return 1
	fi

	case "$version_pedida" in
		*$'\n'*)
			registrar "Downgrade: '$numero_pedido' es ambiguo ($(printf '%s' "$version_pedida" | tr '\n' ' '))"
			telegram "Hay varias versiones que encajan con $numero_pedido: $(printf '%s' "$version_pedida" | tr '\n' ' ')
Escríbela con puntos, por ejemplo: downgrade $(printf '%s\n' "$version_pedida" | head -n 1)"
			return 1
			;;
	esac

	if [ "$version_pedida" = "$VERSION" ]; then
		registrar "Downgrade: ya se esta en la v$VERSION, no se toca nada"
		telegram "Ya estoy en la v$VERSION, no hay nada que cambiar"
		return 0
	fi

	base="https://github.com/$REPO_GITHUB/releases/download/v$version_pedida"

	registrar "Downgrade: version $version_pedida. Descargando de $base"

	descargar_verificado "$base" "$tmp" || return 1

	version_remota=$(version_de "$tmp")

	if [ "$version_remota" != "$version_pedida" ]; then
		registrar "ATENCION: se ha pedido la v$version_pedida pero el fichero descargado declara la v${version_remota:-?}. No se instala"
		telegram "El fichero de la versión $version_pedida declara ser la v${version_remota:-?}, así que no lo instalo. Sigo en v$VERSION"
		rm -f "$tmp"
		return 1
	fi

	instalar_script_descargado "$tmp" "$version_remota" "Cambiando"
}

# ============================================================

# ESTADO DEL BOT ("estado")
#
# Resumen de un vistazo para saber si todo funciona: version, tiempo en
# marcha, si responden OpenWebIF y ghostreamy, como va OSCam, canales,
# streams, IP publica y grabaciones. Solo consulta: no cambia nada. Los tiempos salen de
# /proc/uptime (no del reloj, que sincronizar_hora puede mover).

# ============================================================

segundos_encendido() {
	local up resto
	read -r up resto < /proc/uptime 2>/dev/null
	printf '%s\n' "${up%%.*}"
}

INICIO_UPTIME=$(segundos_encendido)

# Estado de OSCam (el servidor de claves) para "estado", a partir de su log
# ($OSCAM_LOG; cualquier version de OSCam lo escribe igual). Se miran los
# ultimos OSCAM_VENTANA segundos:
#   - ECM: "found" y "cacheN" son descifrados correctos; "not found",
#     "timeout", "rejected"... son fallos;
#   - lectores: "connect failed" o "disconnected" sin un ECM correcto despues
#     del mismo lector = lector caido;
#   - dvbapi "waiting for matching readers" = el deco espera un lector.
# Sin ECM en la ventana (canal en abierto, standby) no hay alarma: se dice
# cuando fue el ultimo. Imprime las lineas para el mensaje; nunca imprime las
# direcciones de los servidores.
OSCAM_VENTANA=300

estado_oscam() {
	local procesos
	if [ -z "$OSCAM_LOG" ]; then
		echo "OSCam: no se comprueba (OSCAM_LOG vacío en botikor.conf)"
		return 0
	fi
	procesos=$(pgrep oscam 2>/dev/null | grep -c .)
	if [ ! -f "$OSCAM_LOG" ]; then
		if [ "$procesos" -gt 0 ]; then
			echo "OSCam: en marcha, pero no encuentro su log en $OSCAM_LOG (mira OSCAM_LOG en botikor.conf)"
		else
			echo "OSCam: NO está en marcha (no hay proceso ni log en $OSCAM_LOG)"
		fi
		return 0
	fi
	[ "$procesos" -gt 0 ] || echo "OSCam: ATENCIÓN, no veo el proceso de OSCam en marcha"
	python3 - "$OSCAM_LOG" "$OSCAM_VENTANA" <<-'PYEOF' 2>/dev/null || echo "OSCam: no he podido leer $OSCAM_LOG"
		import os, re, sys, time

		ruta, ventana = sys.argv[1], int(sys.argv[2])
		with open(ruta, "rb") as f:
		    f.seek(max(0, os.path.getsize(ruta) - 400000))
		    texto = f.read().decode("utf-8", "replace")

		re_hora = re.compile(r"^\*?\s*(\d{4}/\d\d/\d\d \d\d:\d\d:\d\d) ")
		re_ecm = re.compile(r"\(ecm\) .*?\): ([a-z][a-z0-9 ]*?) \((\d+) ms\) by (\S+)")
		re_lector = re.compile(r"\(reader\) (\S+) \[\w+\] (connect failed|disconnected)")

		ahora = time.time()
		lineas = []
		for l in texto.splitlines():
		    m = re_hora.match(l)
		    if not m:
		        continue
		    try:
		        t = time.mktime(time.strptime(m.group(1), "%Y/%m/%d %H:%M:%S"))
		    except ValueError:
		        continue
		    lineas.append((t, l))
		if not lineas:
		    print("OSCam: el log está vacío")
		    sys.exit(0)
		# Si el reloj del deco va por detras del log, manda el log.
		ahora = max(ahora, lineas[-1][0])
		desde = ahora - ventana

		def hace(t):
		    s = int(ahora - t)
		    if s < 60:
		        return "%d s" % s
		    if s < 3600:
		        return "%d min" % (s // 60)
		    return "%d h %02d min" % (s // 3600, (s % 3600) // 60)

		ok = 0
		tiempos = []
		fallos = {}
		ultimo = None
		ok_lector = {}
		caida_lector = {}
		esperando = 0
		for t, l in lineas:
		    m = re_ecm.search(l)
		    if m:
		        res, ms, lector = m.group(1).strip(), int(m.group(2)), m.group(3)
		        bueno = res == "found" or res.startswith("cache")
		        ultimo = (t, res, lector)
		        if bueno:
		            ok_lector[lector] = t
		        if t >= desde:
		            if bueno:
		                ok += 1
		                tiempos.append(ms)
		            else:
		                fallos[res] = fallos.get(res, 0) + 1
		        continue
		    m = re_lector.search(l)
		    if m and t >= desde:
		        n, _ = caida_lector.get(m.group(1), (0, 0))
		        caida_lector[m.group(1)] = (n + 1, t)
		        continue
		    if t >= desde and "waiting for matching readers" in l:
		        esperando += 1

		n_fallos = sum(fallos.values())
		total = ok + n_fallos
		minutos = ventana // 60
		lectores_caidos = {r: v for r, v in caida_lector.items() if ok_lector.get(r, 0) < v[1]}

		if total == 0:
		    if ultimo:
		        estado = "sin descifrar nada en los últimos %d min (último: %s por %s, hace %s)" % (minutos, ultimo[1], ultimo[2], hace(ultimo[0]))
		    else:
		        estado = "sin descifrar nada en el log"
		    if lectores_caidos or esperando:
		        estado = "PROBLEMAS: " + estado
		else:
		    media = sum(tiempos) // len(tiempos) if tiempos else 0
		    fallos_txt = "%d fallo%s" % (n_fallos, "" if n_fallos == 1 else "s")
		    detalle = ", ".join("%s %d" % (k, v) for k, v in sorted(fallos.items(), key=lambda x: -x[1]))
		    if n_fallos == 0 and not lectores_caidos:
		        estado = "bien (%d descifrados correctos en %d min, media %d ms)" % (ok, minutos, media)
		    elif ok / total >= 0.8 and ultimo and (ultimo[1] == "found" or ultimo[1].startswith("cache")) and not lectores_caidos:
		        estado = "bien, con algún fallo (%d correctos y %s en %d min: %s)" % (ok, fallos_txt, minutos, detalle)
		    else:
		        estado = "PROBLEMAS (%d correctos y %s en %d min%s)" % (ok, fallos_txt, minutos, ": " + detalle if detalle else "")
		        if ultimo:
		            estado += "; último: %s por %s, hace %s" % (ultimo[1], ultimo[2], hace(ultimo[0]))
		print("OSCam: " + estado)
		for r, (n, t) in sorted(lectores_caidos.items()):
		    print("  Lector %s: no conecta (%d fallo%s de conexión en %d min, el último hace %s)" % (r, n, "" if n == 1 else "s", minutos, hace(t)))
		if esperando:
		    print("  El deco está esperando un lector que le dé las claves")
		PYEOF
}

enviar_estado() {
	local ahora txt json estado_webif codigo_ghost n_can origen fecha_lista n_grab libre

	ahora=$(segundos_encendido)
	duracion_txt $(( ${ahora:-0} - ${INICIO_UPTIME:-0} ))
	txt="BOTikor v$VERSION
En marcha desde hace $DUR_TXT"
	duracion_txt "${ahora:-0}"
	txt="$txt (deco encendido hace $DUR_TXT)"

	# OpenWebIF: standby y canal que se esta viendo.
	json=$(curl -s --max-time 5 "${WEBIF_AUTH[@]}" "$WEBIF/api/statusinfo" 2>/dev/null)
	estado_webif=$(printf '%s' "$json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if str(d.get("inStandby", "")).lower() == "true":
    print("responde (deco en standby)")
else:
    c = d.get("currservice_name") or ""
    print("responde (viendo %s)" % c if c else "responde")
' 2>/dev/null) || estado_webif="NO responde en $WEBIF"
	txt="$txt
OpenWebIF: $estado_webif"

	# ghostreamy: cualquier respuesta HTTP (aunque sea 401) es que esta vivo.
	codigo_ghost=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$GHOST_PORT_INT/" 2>/dev/null)
	case "$codigo_ghost" in
		""|000) txt="$txt
ghostreamy: NO responde en el puerto $GHOST_PORT_INT" ;;
		*) txt="$txt
ghostreamy: responde en el puerto $GHOST_PORT_INT" ;;
	esac

	# OSCam: si se esta descifrando bien (ver estado_oscam).
	txt="$txt
$(estado_oscam)"

	# Canales y de donde salen.
	n_can=$(grep -c . canalnombres 2>/dev/null)
	if [ -n "$GHOSTLIST_URL" ]; then
		origen="descargada de ghostreamy"
	else
		origen="fichero $GHOSTLIST"
	fi
	fecha_lista=$(date -r "$GHOSTLIST" '+%d/%m %H:%M' 2>/dev/null)
	txt="$txt
Canales: ${n_can:-0} (lista $origen${fecha_lista:+, del $fecha_lista})
Streams en curso: ${N_ESTADO:-0}"

	# IP publica (la de "canal X").
	obtener_ip_publica
	txt="$txt
IP pública: ${myip:-no se ha podido consultar}"

	# Grabaciones: carpeta, cuantas hay y espacio libre.
	if [ -d "$GRABACIONES" ]; then
		n_grab=$(ls "$GRABACIONES"/*.ts 2>/dev/null | grep -c .)
		libre=$(df -k "$GRABACIONES" 2>/dev/null | awk 'END { if (NF >= 4) printf "%.1f GB", $(NF-2) / 1048576 }')
		txt="$txt
Grabaciones: $n_grab en $GRABACIONES${libre:+ (libres $libre)}"
	else
		txt="$txt
Grabaciones: la carpeta $GRABACIONES no existe"
	fi

	telegram "$txt"
}

# ============================================================

# Carga inicial de la lista de canales (genera canales.tsv, canalnombres,
# canalurls y canalurlstrans). Si falla (lista inexistente o ilegible) el bot
# arranca igualmente y conserva los canal* de la carga anterior; si nunca hubo
# carga, lista, canal y zap avisan de que no hay canales.
# Si la lista se descarga de ghostreamy y aun no esta en el deco, se baja
# ahora (solo si falta: al arrancar el deco ghostreamy puede ir mas lento que
# el bot; para refrescarla esta actualizar_canales).
if [ -n "$GHOSTLIST_URL" ] && [ ! -s "$GHOSTLIST" ]; then
	if descargar_lista "$GHOSTLIST_URL" "$GHOSTLIST"; then
		registrar "Lista de canales descargada de ghostreamy: $LISTA_CANALES canales"
		fijar_puerto_ghost
	else
		registrar "ATENCION: no se ha podido descargar la lista de ghostreamy: $LISTA_ERROR"
	fi
fi
cargar_canales

# ============================================================

# SINCRONIZACION HORARIA POR NTP (vía Python, pone el reloj del sistema
# directamente con clock_settime; evita líos de formato con `date -s`
# en busybox). Necesita que el script corra como root, que en un deco
# Enigma2 es lo normal.

# ============================================================

sincronizar_hora() {
	intentos=0
	while [ "$intentos" -lt 12 ]
	do
		epoch=$(python3 - <<-'PYEOF' 2>/dev/null
			import socket, struct, ctypes, sys

			def ntp_time(host="pool.ntp.org", port=123, timeout=5):
			    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
			    s.settimeout(timeout)
			    s.sendto(b"\x1b" + 47 * b"\0", (host, port))
			    data, _ = s.recvfrom(48)
			    return struct.unpack("!12I", data)[10] - 2208988800

			class timespec(ctypes.Structure):
			    _fields_ = [("tv_sec", ctypes.c_long), ("tv_nsec", ctypes.c_long)]

			try:
			    t = ntp_time()
			    ts = timespec(int(t), 0)
			    libc = ctypes.CDLL(None, use_errno=True)
			    if libc.clock_settime(0, ctypes.byref(ts)) != 0:
			        sys.exit(1)
			    print(int(t))
			except Exception:
			    sys.exit(1)
			PYEOF
		)
		if [ -n "$epoch" ]; then
			registrar "Hora sincronizada por NTP en el intento $((intentos + 1)): $(date '+%d/%m/%Y %H:%M:%S')"
			return 0
		fi
		intentos=$((intentos + 1))
		registrar "NTP: intento $intentos sin respuesta, reintento en 5s"
		sleep 5
	done
	registrar "ATENCION: no se ha podido sincronizar la hora tras $intentos intentos. La hora del deco puede estar mal"
	return 1
}

if sincronizar_hora
then
	fechainicio=$(date +"%a %d/%m/%Y %H:%M:%S")
	telegram "BOTikor v$VERSION iniciado. $fechainicio"
else
	fechainicio=$(date +"%a %d/%m/%Y %H:%M:%S")
	telegram "BOTikor v$VERSION iniciado (aviso: no se pudo sincronizar la hora por internet). $fechainicio"
fi

# epoch_inicio: instante de arranque, tomado DESPUES de sincronizar la hora (si
# no, un salto de reloj falsearia el calculo). Lo usan apagar y reiniciar_deco
# para su proteccion de 120 s.
epoch_inicio=$(date +%s)

# IP publica: una sola consulta al arrancar (queda en cache y en el log).
obtener_ip_publica

registrar "Entrando en el bucle principal (sondeo a Telegram cada 5s)"

# ==========================================================================
# BUCLE PRINCIPAL (un ciclo cada ~5 s)
# ==========================================================================
# Cada vuelta hace, en este orden:
#   1. SONDEO DE TELEGRAM: getUpdates?offset=$OFFSET (sin long-polling: contesta
#      al instante). Por cada mensaje nuevo: guarda el offset, comprueba que
#      viene del chat autorizado ($ID) y lo despacha en "case $comando in".
#   2. DETECCION DE NUEVAS GRABACIONES (mas abajo).
#   3. DETECCION DE STREAMING: altas y bajas, leyendo /proc/net/tcp (mas abajo).
#   4. Latido en el log cada ~30 minutos y sleep 5.
# Los comandos se ejecutan de forma SINCRONA dentro del bucle: mientras uno
# tarda no se vigila nada mas. No hay procesos en segundo plano, a proposito.
# ==========================================================================
while [ "$errore" -eq 0 ]
do

# UPDATES es el JSON crudo de Telegram. Cada mensaje se trocea con python3 por
# indice (tres llamadas por mensaje: chat id, texto y update_id). Es lento
# (decimas de segundo), pero solo ocurre cuando alguien escribe.
UPDATES=$(curl -s --max-time 20 "https://api.telegram.org/bot$TOKEN/getUpdates?offset=$OFFSET")
rc_updates=$?

# Caso normal (nada nuevo): Telegram devuelve {"ok":true,"result":[]} y no hace
# falta lanzar python3 para contar. Solo se lanza si hay algo que decodificar.
case "$UPDATES" in
	*'"result":[]'*) NUM_UPDATES=0 ;;
	*) NUM_UPDATES=$(printf '%s' "$UPDATES" | python3 -c 'import sys,json; print(len(json.load(sys.stdin).get("result",[])))' 2>/dev/null) ;;
esac

# Vigilancia de la conexion con Telegram. Se registra el primer fallo y
# despues uno de cada 60 ciclos (~5 min), para no llenar el log si el
# deco se queda sin internet una noche entera.
if [ -z "$UPDATES" ] || [ -z "$NUM_UPDATES" ] || printf '%s' "$UPDATES" | grep -q '"ok":false'; then

	fallos_red=$((fallos_red + 1))

	if [ "$fallos_red" -eq 1 ] || [ $((fallos_red % 60)) -eq 0 ]; then
		registrar "ATENCION: getUpdates sin respuesta valida (fallo consecutivo $fallos_red, curl rc=$rc_updates) -> $(resumir "$UPDATES")"
	fi

elif [ "$fallos_red" -gt 0 ]; then

	registrar "Conexion con Telegram recuperada tras $fallos_red ciclos fallidos"
	fallos_red=0

fi

NUM_UPDATES=${NUM_UPDATES:-0}


if [ "$NUM_UPDATES" -gt 0 ]
then

	for ((i = 0; i < NUM_UPDATES; i++))
	do

		CHAT_ID=$(printf '%s' "$UPDATES" | python3 -c 'import sys,json; d=json.load(sys.stdin); r=d.get("result",[]); i=int(sys.argv[1]); print(r[i].get("message",{}).get("chat",{}).get("id","") if i<len(r) else "")' "$i" 2>/dev/null)

		MESSAGE=$(printf '%s' "$UPDATES" | python3 -c 'import sys,json; d=json.load(sys.stdin); r=d.get("result",[]); i=int(sys.argv[1]); print(r[i].get("message",{}).get("text","null") if i<len(r) else "null")' "$i" 2>/dev/null)

		OFFSET=$(printf '%s' "$UPDATES" | python3 -c 'import sys,json; d=json.load(sys.stdin); r=d.get("result",[]); i=int(sys.argv[1]); print(r[i].get("update_id",0)+1 if i<len(r) else 0)' "$i" 2>/dev/null)

		# Se guarda YA, antes de ejecutar el comando: si el comando es
		# "apagar" y corta la corriente, al reiniciar el script ya
		# partimos de este offset y Telegram no reenvía el mensaje.
		echo "$OFFSET" > "$OFFSET_FILE"


		# Solo aceptar mensajes de tu ID de Telegram

		if [ "$CHAT_ID" != "$ID" ]; then
			registrar "Mensaje IGNORADO (viene del chat ID $CHAT_ID, que no es el autorizado)"
			continue
		fi


		if [ "$MESSAGE" != "null" ]; then

			registrar "Mensaje recibido: $(resumir "$MESSAGE") | offset guardado: $OFFSET"

			# Troceado del mensaje: comando = primera palabra (con o sin "/" delante) y
			# numero = segunda palabra (el parametro: numero de canal, version...).
			# OJO: si el mensaje no tiene espacios, "cut -f 2" devuelve la linea entera, es
			# decir, $numero == $MESSAGE. Por eso los comandos con parametro validan que sea
			# numerico y, si no, explican su uso. Desde la 3.1.14 el comando se pasa a
			# minusculas: el teclado del movil suele poner mayuscula inicial ("Lista").
			comando=$(echo "$MESSAGE" | cut -d ' ' -f 1)
			comando="${comando#/}"
			comando=$(printf '%s' "$comando" | tr '[:upper:]' '[:lower:]')
			numero=$(echo "$MESSAGE" | cut -d ' ' -f 2)


			# DESPACHO DE COMANDOS. Para ANADIR uno:
			#   1. Nueva rama aqui, con el nombre en minusculas y de UNA palabra (con _ si
			#      hace falta: Telegram solo vuelve clicables letras, cifras y _).
			#   2. Anadirlo al texto de ayuda de la rama final "*)".
			#   3. registrar al entrar y telegram con el resultado.
			#   4. Si es destructivo (apagar, reiniciar...), copiar la proteccion de 120 s
			#      de apagar: evita que un mensaje viejo reentregado por Telegram actue.
			#   5. Si lleva parametro, validar que sea numerico (ver canal y zap).
			#   6. Subir VERSION.
			case $comando in


				# lista: canales numerados. El numero de cada canal es su posicion en
				# canalnombres (la misma linea en canalurls y canalurlstrans) y es el que
				# esperan canal y zap. Va en <pre> (telegram_html) para que las columnas
				# alineen.
				"lista")

					if [ ! -s canalnombres ]; then
						registrar "Comando 'lista': no hay canales cargados"
						telegram "No hay lista de canales cargada. Prueba /actualizar_canales"
					else
						n_canales=$(grep -c . canalnombres)
						registrar "Comando 'lista': enviando $n_canales canales"

						# Ancho fijo para el numero (2 en 1-99, 3 en 100-999...),
						# asi la columna del nombre siempre empieza en la misma
						# posicion. El <pre> (ver telegram_html) es lo que hace
						# que ese relleno se vea realmente alineado.
						ancho=${#n_canales}
						# El ancho va horneado en la propia cadena de formato
						# (p.ej. "%2d  %s\n"): el busybox awk del deco no
						# soporta "%*d" (ancho tomado de un argumento).
						# printf -v (no un $(...)) para que el \n final no se
						# recorte al capturarlo.
						printf -v formato '%%%dd  %%s\n' "$ancho"
						listac=$(awk -v formato="$formato" '{ printf formato, NR, $0 }' canalnombres)

						# Telegram admite 4096 caracteres por mensaje: si la lista no
						# cabe, se manda en varios, cortando siempre entre lineas.
						# Se mide el texto ya escapado (&amp; cuenta mas que el "&"
						# que vera la persona), asi que nunca se pasa.
						trozo=""
						while IFS= read -r linea; do
							if [ -n "$trozo" ] && [ $(( ${#trozo} + ${#linea} + 1 )) -gt 3800 ]; then
								telegram_html "<pre>${trozo%$'\n'}</pre>"
								trozo=""
							fi
							trozo+="$linea"$'\n'
						done <<< "$(escapar_html "$listac")"
						[ -n "$trozo" ] && telegram_html "<pre>${trozo%$'\n'}</pre>"
					fi

				;;


				# downgrade X: instala la version X. Todo esta en downgrade_botikor(); sin X (o
				# con una X inexistente) lista las versiones disponibles.
				"downgrade")

					downgrade_botikor "$numero"

				;;


				# actualizar_canales: vuelve a LEER lista.m3u8 (no la descarga: la regenera la
				# persona desde ghostreamy, ver la documentación) y rehace canales.tsv y canal*. Si
				# la lectura falla se conservan los ficheros de la carga anterior.
				"actualizar_canales")

					registrar "Comando 'actualizar_canales'"

					# Con GHOSTLIST_URL primero se descarga; si falla, se sigue con
					# la lista que habia y no se recarga nada.
					lista_ok=1
					if [ -n "$GHOSTLIST_URL" ]; then
						if descargar_lista "$GHOSTLIST_URL" "$GHOSTLIST"; then
							registrar "Lista de canales descargada de ghostreamy: $LISTA_CANALES canales"
						else
							lista_ok=0
							registrar "ATENCION: no se ha podido descargar la lista de ghostreamy: $LISTA_ERROR"
							telegram "No he podido descargar la lista de ghostreamy ($LISTA_ERROR). Sigo con la que tenía."
						fi
					fi

					if [ "$lista_ok" = 0 ]; then
						:
					elif cargar_canales; then
						# Con GHOST_PORT_INT=auto, la lista nueva manda.
						puerto_antes="$GHOST_PORT_INT"
						fijar_puerto_ghost
						[ "$GHOST_PORT_INT" != "$puerto_antes" ] && registrar "ATENCION: el puerto de ghostreamy cambia de $puerto_antes a $GHOST_PORT_INT"
						telegram "Lista de canales ${GHOSTLIST_URL:+descargada de ghostreamy y }recargada: $(grep -c . canalnombres 2>/dev/null) canales"
					else
						telegram "No se ha podido leer $GHOSTLIST"
					fi

				;;


				# actualizar_botikor: ver actualizar_botikor(). Si hay una version mas nueva no
				# vuelve de la funcion (exec).
				"actualizar_botikor")

					actualizar_botikor

				;;


				# canal X: da la URL publica del canal X (y la transcodificada si la lista la
				# trae) para abrirla fuera de casa (VLC, Kodi...). Cambia "IP-local:INT" por
				# "IP-publica:EXT" (ver GHOST_PORT_EXT). Necesita la IP publica y el puerto
				# abierto en el router.
				"canal")

					case "$numero" in

						""|*[!0-9]*)

							registrar "Comando 'canal': falta o no es valido el numero de canal ('$numero')"
							telegram "Uso: canal X (por ejemplo: canal 3). Pide 'lista' para ver los números disponibles"

						;;

						*)

							nombre=$(sed "${numero}q;d" canalnombres 2>/dev/null)
							urlbase=$(sed "${numero}q;d" canalurls 2>/dev/null)
							urltrans=$(sed "${numero}q;d" canalurlstrans 2>/dev/null)

							if [ -z "$urlbase" ]; then

								registrar "Comando 'canal $numero': no existe ese numero"
								telegram "No existe ese número de canal. Pide 'lista' para ver los disponibles"

							else

								registrar "Comando 'canal $numero' -> $nombre (con transcodificada: $([ -n "$urltrans" ] && echo si || echo no))"

								obtener_ip_publica

								if [ -z "$myip" ]; then

									registrar "Comando 'canal $numero': sin IP publica, no se puede montar la URL"
									telegram "Ahora mismo no consigo averiguar la IP pública, así que no puedo montar la URL de $nombre. Inténtalo de nuevo en un momento"

								else

									urlpublica=$(printf '%s' "$urlbase" | sed -E "s#://[0-9.]+:$GHOST_PORT_INT#://$myip:$GHOST_PORT_EXT#")

									telegram "URL del canal $nombre:"
									telegram "$urlpublica"

									if [ -n "$urltrans" ]; then
										urlpublicatrans=$(printf '%s' "$urltrans" | sed -E "s#://[0-9.]+:$GHOST_PORT_INT#://$myip:$GHOST_PORT_EXT#")
										telegram "URL del canal $nombre transcodificado:"
										telegram "$urlpublicatrans"
									fi

								fi

							fi

						;;

					esac

				;;


				# zap X: pone el deco en el canal X. Truco: pide 3 s de stream a ghostreamy por
				# la URL local. Cambia el canal del deco SOLO si el usuario de ghostreamy tiene
				# activado "Forzar zap antes de reproducir un canal" Y el deco tiene activado
				# "zap before streaming" en OpenWebIF (sin ambos, ghostreamy abre un stream
				# aparte y el deco no se mueve). No necesita IP publica.
				"zap")

					case "$numero" in

						""|*[!0-9]*)

							registrar "Comando 'zap': falta o no es valido el numero de canal ('$numero')"
							telegram "Uso: zap X (por ejemplo: zap 3). Pide 'lista' para ver los números disponibles"

						;;

						*)

							urlbase=$(sed "${numero}q;d" canalurls 2>/dev/null)
							nombrezap=$(sed "${numero}q;d" canalnombres 2>/dev/null)

							if [ -z "$urlbase" ]; then

								registrar "Comando 'zap $numero': no existe ese numero"
								telegram "No existe ese número de canal. Pide 'lista' para ver los disponibles"

							else

								# Consumo corto del stream: como ghostreamy y Enigma2
								# tienen "zap before stream", esto ya provoca el
								# cambio real de canal en el deco. --max-time corta
								# la conexión por sí solo (sin depender de `timeout`,
								# que en algunos builds de busybox no existe).
								registrar "Comando 'zap $numero' -> $nombrezap"

								curl -s --max-time 3 -o /dev/null "$urlbase"
								rc_zap=$?

								# rc 28 es el corte por --max-time: aqui es lo
								# normal y significa que el stream iba bien.
								if [ "$rc_zap" -eq 28 ] || [ "$rc_zap" -eq 0 ]; then
									registrar "Zap completado (curl rc=$rc_zap)"
								else
									registrar "ATENCION: el zap puede no haber funcionado (curl rc=$rc_zap)"
								fi

								telegram "Zap a $nombrezap"

							fi

						;;

					esac

				;;


				# log: manda el fichero de log como documento (log.txt).
				# estado: resumen de si todo funciona. Ver enviar_estado().
				"estado")

					registrar "Comando 'estado'"
					enviar_estado

				;;


				"log")

					registrar "Comando 'log': enviando $log como log.txt"

					telegram_documento "$log" "log.txt"

				;;


				# encender: saca al deco de standby (powerstate 4). Solo sirve desde standby
				# normal: en apagado profundo el bot no esta corriendo.
				"encender")

					registrar "Comando 'encender'"

					powerstate 4 "salir de standby"

					telegram "Encendiendo el deco (saliendo de standby)"

				;;


				# suspender: standby normal (powerstate 5). El bot sigue vivo y puede despertar
				# al deco con encender.
				"suspender")

					registrar "Comando 'suspender'"

					powerstate 5 "standby"

					telegram "Deco a standby (no profundo)"

				;;


				# apagar: apagado PROFUNDO (powerstate 1). Despues el deco no tiene red y el bot
				# no corre: solo se vuelve a encender a mano. Se descarta si el bot lleva menos
				# de 120 s en marcha (un mensaje viejo reentregado no debe apagar un deco recien
				# arrancado).
				"apagar")

					segundos_encendido=$(( $(date +%s) - epoch_inicio ))

					if [ "$segundos_encendido" -lt 120 ]; then

						registrar "Comando 'apagar' DESCARTADO: el bot solo lleva ${segundos_encendido}s en marcha (proteccion de 120s)"
						telegram "El deco lleva menos de 2 minutos encendido, no proceso el apagado por seguridad (posible mensaje duplicado)"

					else

						registrar "Comando 'apagar' aceptado (bot en marcha desde hace ${segundos_encendido}s)"

						telegram "Apagando el deco (apagado profundo)"

						powerstate 1 "apagado profundo"

					fi

				;;


				"exit")

					# Cierra el bot del todo. El offset ya se ha guardado mas
					# arriba, asi que si se vuelve a lanzar a mano no se
					# reprocesa este mismo mensaje. Ojo: si el bot lo lanza
					# un init/cron/watchdog, este puede volver a arrancarlo.
					registrar "Comando 'exit': cerrando BOTikor v$VERSION (PID $$) tras $((SECONDS / 60)) min en marcha"

					telegram "Cerrando BOTikor v$VERSION. Para volver a arrancarlo hay que lanzarlo a mano en el deco"

					registrar "BOTikor cerrado por comando 'exit'"

					exit 0

				;;


				# reiniciar_deco: reinicia el deco entero (powerstate 2), con la misma proteccion
				# de 120 s que apagar.
				"reiniciar_deco")

					# Misma proteccion que "apagar": si el bot acaba de
					# arrancar, un mensaje viejo reentregado por Telegram
					# podria dejar el deco en bucle de reinicios.
					segundos_encendido=$(( $(date +%s) - epoch_inicio ))

					if [ "$segundos_encendido" -lt 120 ]; then

						registrar "Comando 'reiniciar_deco' DESCARTADO: el bot solo lleva ${segundos_encendido}s en marcha (proteccion de 120s)"
						telegram "El bot lleva menos de 2 minutos en marcha, no proceso el reinicio del deco por seguridad (posible mensaje duplicado)"

					else

						# Se avisa ANTES: el reinicio se lleva por delante
						# al propio script.
						registrar "Comando 'reiniciar_deco' aceptado (bot en marcha desde hace ${segundos_encendido}s)"

						telegram "Reiniciando el deco..."

						powerstate 2 "reinicio del deco"

					fi

				;;


				# reiniciar_bot: relanza este mismo script con exec (mismo PID) conservando el
				# offset, para que arranque limpio sin reiniciar el deco.
				"reiniciar_bot")

					# El offset ya se ha guardado mas arriba, asi que al
					# relanzar no se vuelve a procesar este mismo mensaje.
					registrar "Comando 'reiniciar_bot': relanzando $SCRIPT_PATH con offset $OFFSET"

					telegram "Reiniciando BOTikor v$VERSION..."

					echo "$OFFSET" > "$OFFSET_FILE"

					chmod +x "$SCRIPT_PATH" 2>/dev/null

					if [ -x "$SCRIPT_PATH" ]; then
						exec "$SCRIPT_PATH"
					else
						exec bash "$SCRIPT_PATH"
					fi

				;;


				# parar_stream: corta los streams activos (los de Enigma2 y los de ghostreamy)
				# sin reiniciar nada. Mecanismo en parar_streams() (RST); lo que sigue solo
				# decide que mensaje mandar segun el resultado.
				"parar_stream")

					# Cortar streams no reinicia nada ni es peligroso, asi que
					# aqui NO hay proteccion de 120s (solo la necesitan apagar y
					# reiniciar el deco). Ver parar_streams() mas arriba.
					registrar "Comando 'parar_stream' | streams confirmados=$N_ESTADO"

					parar_streams
					rc_parar=$?

					if [ "$rc_parar" -eq 2 ]; then

						telegram "No he podido cortar los streams: ha fallado el script de corte ($CORTE_ERROR)"

					elif [ "${CORTE_ANTES:-0}" -eq 0 ] && [ -z "$CORTE_ERROR" ]; then

						telegram "No había ningún stream activo que cortar"

					elif [ "${CORTE_CORTADAS:-0}" -eq 0 ]; then

						telegram "No he conseguido cortar el stream: he mandado ${CORTE_RST:-0} RST y la conexión sigue abierta (challenge ACK: ${CORTE_CHALLENGE:-?}).${CORTE_ERROR:+ $CORTE_ERROR} Mira el log para más detalles"

					else

						# Se cuentan clientes (IPs), no conexiones: ver parar_streams().
						if [ "$CORTE_NCLIENTES" -eq 1 ]; then
							cortado_txt="Stream cortado (cliente: $CORTE_CLIENTES)"
						elif [ "$CORTE_NCLIENTES" -gt 1 ]; then
							cortado_txt="Streams cortados: $CORTE_NCLIENTES clientes (${CORTE_CLIENTES//,/, })"
						else
							cortado_txt="Cortadas las conexiones internas de ghostreamy (sin ningún cliente visible)"
						fi

						if [ -n "$CORTE_ERROR" ]; then
							telegram "$cortado_txt. Algún aviso: $CORTE_ERROR"
						elif [ "$RESTANTES" -gt 0 ]; then
							telegram "$cortado_txt, pero siguen abiertas $RESTANTES conexión(es) en los puertos $STREAMPORT_NATIVO/$GHOST_PORT_INT (puede que algún cliente haya reconectado solo)"
						else
							telegram "$cortado_txt"
						fi

					fi

				;;


				# Cualquier otra cosa (incluido un "hola"): se contesta con la ayuda. Este texto
				# es la unica lista de comandos que ve la persona: mantenerla igual que el case
				# y que ARQUITECTURA.md.
				*)

					registrar "Comando no reconocido: '$(resumir "$MESSAGE")'"
					telegram "Comandos disponibles:
/lista
/canal X
/zap X
/actualizar_canales
/actualizar_botikor
/downgrade X
/log
/estado
/encender
/suspender
/apagar
/parar_stream
/reiniciar_deco
/reiniciar_bot
/exit"

				;;

			esac

		fi

	done

fi

# ========================================================
# DETECCION DE NUEVAS GRABACIONES
# ========================================================

# Solo se mira el *.ts MAS RECIENTE de $GRABACIONES (por fecha de modificacion).
# Si cambia y no esta en listagrabaciones, se anuncia como "grabacion iniciada".
# Limitaciones: avisa solo del INICIO (no del final); si dos grabaciones
# empiezan en el mismo ciclo solo se anuncia una; y el nombre se recorta con
# nombre_grabacion (ver la nota GRABACIONES al arrancar).
newlastfile=$(ultima_grabacion)
[ -n "$newlastfile" ] && newlastfile=$(nombre_grabacion "$newlastfile")

if [ "$lastfile" = "$newlastfile" ]
then

	felicidades=1

else

	numerob=${#newlastfile}

	if [ "$numerob" -gt 3 ]
	then

		existe=$(grep -Fx -- "$newlastfile" listagrabaciones 2>/dev/null || true)

		numerob=${#existe}

		if [ "$numerob" -lt 3 ]; then

			lastfile="$newlastfile"

			echo "$lastfile" >> listagrabaciones

			registrar "Nueva grabacion detectada: $lastfile"

			telegram "Se ha iniciado una grabación: $lastfile"

		fi

	fi

fi


# ========================================================
# DETECCION DE STREAMING
#
# Se vigilan los dos puertos: el NATIVO de Enigma2 (STREAMPORT_NATIVO,
# 8001), donde entran los clientes "tradicionales" directos (red local,
# VPN...), y el de ghostreamy (GHOST_PORT_INT, 3138), donde entran sus
# clientes. Cada conexion ESTABLISHED se clasifica como:
#   - directo:    8001, IP no loopback
#   - ghostreamy: 3138, IP no loopback
#   - interna:    8001, loopback -> es ghostreamy tirando del canal, no un
#                 stream en si; se descarta.
# La clave de cada stream es (tipo, IP, puerto de origen): dos ventanas
# desde la misma IP son dos streams.
#
# Coste por ciclo: un unico awk sobre /proc/net/tcp(6). Su texto crudo se
# compara con el del ciclo anterior y solo si es distinto se lanza python3
# para decodificarlo. La contabilidad de confirmacion y bajas, que es
# barata (solo texto y builtins de bash), se ejecuta siempre: si no, un
# stream estable nunca llegaria a confirmarse.
#
# - Alta: hay que verla 2 ciclos seguidos (~5-10s) para filtrar
#   conexiones instantaneas. Al confirmarse, se pide Streaming_list para
#   sacar el canal (ver resolver_canales()). Una conexion a ghostreamy
#   solo es un stream si Streaming_list tiene una entrada de ghostreamy
#   (loopback) que le corresponda: si no, es alguien navegando por su web
#   y NO se anuncia (se reintenta, ver ALTA_REINTENTOS).
# - Baja: se anuncia en cuanto desaparece de las conexiones vivas.
# ========================================================

# CICLO DE VIDA DE UNA CONEXION (maquina de estados). Formatos de cada variable en
# "ESTADO DE LOS STREAMS: FUNCIONES DE APOYO".
#
#   /proc/net/tcp --awk--> RAW_CONEXIONES --python--> VIVOS   conexiones de AHORA
#
#   VIVOS --(1er ciclo)-------------> PEND         n=1: vista, sin confirmar
#   PEND  --(2o ciclo, n>=2)--------> NUEVOS_CONF --resolver_canales()--+
#                                                                       |
#         canal (nombre o "-") ---------------------------------------> ESTADO
#                                     aviso "Stream iniciado"
#         "!" = ghostreamy sin stream detras (navegando por su web)
#               ---------------------------------> vuelve a PEND con su n,
#                                                   sin anunciar
#   ESTADO --(ya no esta en VIVOS)--> FINALIZADOS --> aviso "Stream terminado"
#
# Reintentos de las conexiones a ghostreamy sin stream: en cada ciclo hasta
# n = ALTA_REINTENTOS (~40 s) y despues solo cuando n es multiplo de
# ALTA_REINTENTO_LENTO (~1 min). RESERVAS: las conexiones a ghostreamy aun sin
# confirmar (n < 2) entran en la consulta solo para que reserven su entrada de
# Streaming_list antes que una conexion antigua; no se anuncian ahi.
RAW_CONEXIONES=$(awk -v p1=":$PUERTO_HEX_NATIVO" -v p2=":$PUERTO_HEX_GHOST" '
	$4 == "01" && ($2 ~ p1"$" || $2 ~ p2"$") { print substr($2, length($2) - 3), $3 }
' /proc/net/tcp /proc/net/tcp6 2>/dev/null)

# Paso caro: solo si las conexiones han cambiado desde el ciclo anterior.
if [ "$RAW_CONEXIONES" != "$RAW_PREVIO" ]; then

	if [ -z "$RAW_CONEXIONES" ]; then
		nuevos_vivos=""
		rc_decod=0
	else
		nuevos_vivos=$(decodificar_conexiones "$RAW_CONEXIONES" 2>/dev/null)
		rc_decod=$?
	fi

	if [ "$rc_decod" -eq 0 ]; then
		RAW_PREVIO="$RAW_CONEXIONES"
		fallos_decod=0
		if [ "$nuevos_vivos" != "$VIVOS" ]; then
			VIVOS="$nuevos_vivos"
			registrar "Conexiones de streaming en los puertos $STREAMPORT_NATIVO/$GHOST_PORT_INT: $([ -n "$VIVOS" ] && resumir "$VIVOS" || echo ninguna)"
		fi
	else
		# Si python falla NO se da por vacio el estado (se anunciarian como
		# terminados todos los streams): se conserva lo anterior y se
		# reintenta en el ciclo siguiente.
		fallos_decod=$((fallos_decod + 1))
		if [ "$fallos_decod" -eq 1 ] || [ $((fallos_decod % 60)) -eq 0 ]; then
			registrar "ATENCION: no se han podido decodificar las conexiones de streaming (rc=$rc_decod, fallo consecutivo $fallos_decod). Se mantiene el estado anterior"
		fi
	fi

fi

# Contabilidad barata: solo si hay algo vivo, pendiente o confirmado.
if [ -n "$VIVOS$PEND$ESTADO" ]; then

	# --- Bajas: streams confirmados que ya no estan conectados ---
	ESTADO_VIVO=""
	FINALIZADOS=""
	while IFS=$'\t' read -r e_tipo e_ip e_puerto e_canal e_inicio; do
		[ -n "$e_tipo" ] || continue
		if clave_en "$VIVOS" "$e_tipo$TAB$e_ip$TAB$e_puerto"; then
			agregar_linea ESTADO_VIVO "$e_tipo$TAB$e_ip$TAB$e_puerto$TAB$e_canal$TAB$e_inicio"
		else
			agregar_linea FINALIZADOS "$e_tipo$TAB$e_ip$TAB$e_puerto$TAB$e_canal$TAB$e_inicio"
		fi
	done <<< "$ESTADO"

	# --- Altas: claves vivas aun no confirmadas (cuentan ciclos) ---
	PEND_NUEVO=""
	NUEVOS_CONF=""
	RESERVAS=""
	while IFS=$'\t' read -r v_tipo v_ip v_puerto; do
		[ -n "$v_tipo" ] || continue
		clave="$v_tipo$TAB$v_ip$TAB$v_puerto"
		clave_en "$ESTADO_VIVO" "$clave" && continue
		n_ciclos=0
		visto=$SECONDS
		while IFS=$'\t' read -r p_tipo p_ip p_puerto p_n p_visto; do
			if [ "$p_tipo" = "$v_tipo" ] && [ "$p_ip" = "$v_ip" ] && [ "$p_puerto" = "$v_puerto" ]; then
				n_ciclos=$p_n
				visto=$p_visto
				break
			fi
		done <<< "$PEND"
		n_ciclos=$((n_ciclos + 1))
		if [ "$n_ciclos" -lt 2 ]; then
			agregar_linea PEND_NUEVO "$clave$TAB$n_ciclos$TAB$visto"
			# Una conexion a ghostreamy aun sin confirmar puede ser el stream
			# real que acaba de empezar: entra en la resolucion (no se
			# anuncia) para que, con prioridad a la mas reciente, reserve
			# la entrada de Streaming_list antes que una conexion antigua
			# (un navegador que ya estaba abierto).
			if [ "$v_tipo" = "ghostreamy" ]; then
				agregar_linea RESERVAS "$clave$TAB$visto$TAB$n_ciclos"
			fi
		elif [ "$v_tipo" != "ghostreamy" ] || [ "$n_ciclos" -le "$ALTA_REINTENTOS" ] || [ $((n_ciclos % ALTA_REINTENTO_LENTO)) -eq 0 ]; then
			# Se intenta confirmar (y resolver el canal). Una conexion a
			# ghostreamy que no resulta ser un stream vuelve a PEND con su
			# contador (ver mas abajo) y se reintenta con menos frecuencia.
			agregar_linea NUEVOS_CONF "$clave$TAB$visto$TAB$n_ciclos"
		else
			agregar_linea PEND_NUEVO "$clave$TAB$n_ciclos$TAB$visto"
		fi
	done <<< "$VIVOS"
	PEND="$PEND_NUEVO"
	ESTADO="$ESTADO_VIVO"

	# --- Aviso de bajas (antes que las altas, con lo que queda activo) ---
	if [ -n "$FINALIZADOS" ]; then
		mensaje=""
		while IFS=$'\t' read -r f_tipo f_ip f_puerto f_canal f_inicio; do
			[ -n "$f_tipo" ] || continue
			[ "$f_canal" = "-" ] && f_canal=""
			duracion_txt $((SECONDS - f_inicio))
			registrar "Stream terminado: $f_tipo $f_ip:$f_puerto canal='${f_canal}' duracion=$DUR_TXT"
			agregar_linea mensaje "Stream terminado: $f_ip${f_canal:+, $f_canal} (duró $DUR_TXT)"
		done <<< "$FINALIZADOS"

		if [ -n "$ESTADO" ]; then
			lista_activos
			mensaje="$mensaje$NL$NL$LISTA_ACTIVOS"
		fi

		telegram "$mensaje"
	fi

	# --- Aviso de altas ---
	if [ -n "$NUEVOS_CONF" ]; then

		# Una sola consulta a OpenWebIF para todos los confirmados de este ciclo.
		json_estado=$(curl -s --max-time 5 "${WEBIF_AUTH[@]}" "$WEBIF/api/statusinfo")
		resueltos=$(resolver_canales "$json_estado" "$ESTADO" "$NUEVOS_CONF${RESERVAS:+$NL$RESERVAS}" 2>/dev/null)

		if [ -z "$resueltos" ]; then
			# Sin canales (python o OpenWebIF han fallado): se anuncia igualmente.
			registrar "ATENCION: no se ha podido resolver el canal de los streams nuevos (OpenWebIF sin respuesta o python3 fallido)"
			resueltos=""
			while IFS=$'\t' read -r r_tipo r_ip r_puerto r_visto r_n; do
				[ -n "$r_tipo" ] || continue
				agregar_linea resueltos "$r_tipo$TAB$r_ip$TAB$r_puerto$TAB-$TAB$r_visto$TAB$r_n"
			done <<< "$NUEVOS_CONF"
		fi

		contar_lineas "$ESTADO"
		previos=$N_LINEAS
		nuevos_n=0
		nuevos_txt=""

		while IFS=$'\t' read -r n_tipo n_ip n_puerto n_canal n_inicio n_n; do
			[ -n "$n_tipo" ] || continue

			# Las reservas (n < 2) solo servian para repartir bien las
			# entradas: ya estan en PEND y se confirmaran en su momento.
			[ "${n_n:-2}" -ge 2 ] || continue

			# "!" = conexion a ghostreamy sin stream detras (alguien mirando
			# su web, la guia, los picons...). No se anuncia: vuelve a PEND
			# conservando su contador, por si ghostreamy tarda en pedir el
			# canal y luego si resulta ser un stream.
			if [ "$n_canal" = "!" ]; then
				[ "${n_n:-2}" -eq 2 ] && registrar "Conexion a ghostreamy sin stream detras (navegacion web?): $n_ip:$n_puerto. No se anuncia; se sigue vigilando"
				agregar_linea PEND "$n_tipo$TAB$n_ip$TAB$n_puerto$TAB${n_n:-2}$TAB$n_inicio"
				continue
			fi

			agregar_linea ESTADO "$n_tipo$TAB$n_ip$TAB$n_puerto$TAB$n_canal$TAB$n_inicio"
			canal_log=$n_canal
			[ "$canal_log" = "-" ] && canal_log="(desconocido)"
			registrar "Stream confirmado (2 ciclos): $n_tipo $n_ip:$n_puerto canal='$canal_log'"
			nuevos_n=$((nuevos_n + 1))
			agregar_linea nuevos_txt "Nuevo cliente conectado: $n_ip"
			# (al llegar a EOF, `read` vacia sus variables: se guarda el ultimo)
			ult_tipo=$n_tipo
			ult_ip=$n_ip
			ult_canal=$n_canal
		done <<< "$resueltos"

		if [ "$nuevos_n" -gt 0 ]; then

			if [ "$previos" -eq 0 ] && [ "$nuevos_n" -eq 1 ]; then
				# Un unico stream activo: el mensaje de siempre.
				[ "$ult_canal" = "-" ] && ult_canal=""
				mensaje="Stream iniciado${NL}Origen: $ult_ip${NL}vía $ult_tipo"
				[ -n "$ult_canal" ] && mensaje="$mensaje${NL}Canal: $ult_canal"
			else
				lista_activos
				if [ "$previos" -eq 0 ]; then
					mensaje="Streams iniciados$NL$NL$LISTA_ACTIVOS"
				else
					mensaje="$nuevos_txt$NL$NL$LISTA_ACTIVOS"
				fi
			fi

			telegram "$mensaje"
		fi
	fi

	contar_lineas "$ESTADO"
	N_ESTADO=$N_LINEAS

fi

# Latido cada ~30 minutos (360 ciclos de 5s): sirve para saber, leyendo
# el log, que el bot ha seguido vivo aunque no pasara nada.
ciclos=$((ciclos + 1))

if [ $((ciclos % 360)) -eq 0 ]; then
	registrar "Latido: $ciclos ciclos | offset $OFFSET | IP en cache ${myip:-(sin consultar)} | streams=$N_ESTADO | fallos de red seguidos=$fallos_red"
fi

# Pausa entre ciclos: es la resolucion temporal de todo el bot. Un comando se
# atiende en el siguiente ciclo, un stream se confirma tras 2 ciclos y el latido
# del log cuenta 360 ciclos (~30 min).
sleep 5

done
