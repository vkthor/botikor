# Guía de instalación de BOTikor

[English](INSTALL.md) | **Español**

Esta guía te lleva de cero a tener el bot funcionando. Calcula una media hora. No hace falta saber programar, pero sí escribir algún comando en el deco; aquí te decimos exactamente cuáles.

**Resumen:** preparas ghostreamy (y, si quieres, OSCam), creas un bot en Telegram, entras en el deco, lanzas un comando, eliges el idioma y contestas cinco preguntas. Lo demás lo hace el propio BOTikor.

## Qué necesitas

- Un decodificador con **Enigma2** (OpenSPA, OpenATV, OpenPLi…) con **ghostreamy** instalado y funcionando.
- **Telegram** en el móvil.
- Un ordenador en la misma red que el deco, para entrar en él por SSH. En Windows 10/11 ya viene incluido; en Mac y Linux también.
- La **IP del deco** en tu casa (por ejemplo `192.168.1.50`). La ves en el propio deco, en Menú → Información → Red, o en la web de tu router.

## 1. Prepara ghostreamy

Abre la web de ghostreamy desde el navegador: `http://IP-DEL-DECO:3138`. El puerto puede ser otro si lo cambiaste.

1. **Un solo usuario.** BOTikor trabaja con un único usuario de ghostreamy. Si tienes varios, decide cuál usará el bot y ponle una contraseña larga.
2. **Activa «Forzar zap antes de reproducir un canal»** en ese usuario (menú **Usuarios** → editar el usuario). Sin esto, `/zap` abre el canal pero la tele de casa no cambia.
3. **Ten hecha una lista de canales** para ese usuario (menú **Bouquets** y **Listas**). Es la que verás con `/lista`. Si no cabe en un mensaje de Telegram, el bot la manda en varios.
4. **Copia su dirección.** En **Listas**, junto a la lista que quieras usar, pulsa el botón **«m3u URL»**. La dirección se copia al portapapeles; pégala en un bloc de notas, porque la usarás en el paso 6.
   - Aparece una vez por cada red del deco; da igual cuál copies.
   - **Esa dirección lleva el código de tu usuario de ghostreamy: no la compartas.**

> La versión gratuita de ghostreamy sólo admite **un cliente a la vez**. BOTikor lo tiene en cuenta para saber qué canal está viendo cada conexión.

## 2. Prepara OpenWebIF

OpenWebIF es la web del propio deco (`http://IP-DEL-DECO`). El bot la usa para encender, apagar y saber qué canal se ve.

- Activa la casilla **«Saltar antes del Stream»** (en inglés, *Zap before streaming*). Está en el menú de la izquierda, **Extras → Configuración**, que se abre directamente en **«Configuración OpenWebif»**. Es el otro requisito para que `/zap` cambie el canal de la tele.
- Si tu OpenWebIF pide usuario y contraseña, tenlos a mano: el bot te los preguntará.

## 3. OSCam (opcional)

Si usas OSCam, `/estado` puede decirte si se está descifrando bien: por ejemplo, si el servidor de claves se ha caído. Para eso lee el log de OSCam, que tiene que estar activado. En el fichero `oscam.conf`, sección `[global]`, debe haber una línea como esta:

```
logfile = /tmp/oscam.log
```

Casi todas las instalaciones ya la tienen. Si tu log está en otra ruta, cámbiala después en `botikor.conf` (línea `OSCAM_LOG=`).

## 4. Crea tu bot de Telegram

1. En Telegram, abre [@BotFather](https://t.me/BotFather) y envíale `/newbot`.
2. Te pide un **nombre** (el que verás en el chat, por ejemplo «Mi deco») y un **nombre de usuario**, que tiene que acabar en `bot` (por ejemplo `mideco_casa_bot`).
3. Te contesta con un **token**, una línea del estilo `123456789:ABCdefGhIJKlmNoPQRstuVWXyz`. Cópialo. **Es la llave de tu bot: no se lo des a nadie.**

## 5. Entra en el deco

Desde el ordenador, abre una terminal (en Windows: botón Inicio → escribe `PowerShell`) y escribe, cambiando la IP por la de tu deco:

```bash
ssh root@192.168.1.50
```

La primera vez te pregunta si confías en el equipo: escribe `yes`. Después te pide la contraseña de root del deco (en muchas imágenes no tiene; si no la sabes, mira en el menú del deco, en la configuración de red o de contraseña).

## 6. Descarga y lanza BOTikor

Ya dentro del deco, copia y pega este comando:

```bash
curl -fsSLo /tmp/botikor.sh https://github.com/vkthor/botikor/releases/latest/download/botikor.sh && bash /tmp/botikor.sh
```

Descarga la última versión y la arranca. Lo primero que te pregunta es el **idioma**: `1` (o Intro) para español, `2` para inglés. Todo lo que diga el bot a partir de ahí (en la terminal, por Telegram y en su log) saldrá en ese idioma. Después te hace cinco preguntas. En las que muestran un valor entre corchetes, basta con pulsar Intro para aceptarlo.

1. **Token del bot**: pega el del paso 4. El bot comprueba con Telegram que es válido y te dice su nombre.
2. **Tu chat**: abre Telegram y escribe cualquier cosa a tu bot (por ejemplo, `hola`). El script lo detecta, te enseña tu nombre y te pregunta si eres tú. A partir de ahí el bot sólo obedecerá a ese chat.
3. **OpenWebIF**: normalmente basta con pulsar Intro. Si pide contraseña, te pregunta el usuario y la contraseña.
4. **Lista de canales**: pega la dirección «m3u URL» del paso 1. El script descarga la lista y te dice cuántos canales tiene.
5. **Puertos de ghostreamy**:
   - el **interno** se detecta solo (pulsa Intro);
   - el **externo** es el que abras en el router para ver los canales fuera de casa (ver el paso 8). Si no lo vas a abrir, o es el mismo, pulsa Intro.

Al final te pregunta **«¿Instalo?»**. Contesta `s` (o pulsa Intro):

- se copia a `/usr/script/botikor.sh`;
- se configura para arrancar solo cada vez que se encienda el deco;
- se pone en marcha.

Ya puedes cerrar la terminal.

> Toda tu configuración queda en `/home/root/botikor/botikor.conf`, que sólo puede leer root. Lleva tu token y la dirección de tu lista: no lo compartas.

## 7. Comprueba que funciona

En Telegram, tu bot te habrá escrito «BOTikor v… iniciado». Prueba:

- `/estado`: te dice si todo responde (OpenWebIF, ghostreamy, OSCam, canales…).
- `/lista`: tus canales numerados.
- `/zap 1`: la tele de casa debería cambiar al canal 1.

Si algo no va, mira las [preguntas frecuentes](FAQ.es.md).

## 8. Ver los canales fuera de casa (opcional)

`/canal X` te da un enlace para ver el canal X en el móvil o en otro sitio. Para que funcione fuera de tu red, el router tiene que dejar pasar las conexiones a ghostreamy:

1. En la web de tu router, busca **«Redirección de puertos»**, *Port forwarding* o *NAT*.
2. Crea una regla:
   - **puerto externo:** el que quieras, por ejemplo `3838`;
   - **IP de destino:** la del deco;
   - **puerto interno:** el de ghostreamy, normalmente `3939`.
3. El puerto externo que hayas elegido es el que tiene que tener BOTikor en `GHOST_PORT_EXT` (pregunta 5 del paso 6).

Ten en cuenta:

- Internet está lleno de programas que prueban puertos abiertos: en cuanto abras uno, verás intentos de entrar en el log de ghostreamy. Por eso la **contraseña del usuario de ghostreamy tiene que ser buena**.
- Si tu operador te da una conexión con **CG-NAT** (frecuente en fibra compartida y en 4G/5G), abrir puertos no funciona. Tendrás que usar tailscale u otras opciones.
- El enlace de `/canal` lleva la IP pública de tu casa en ese momento, que puede cambiar. Pídelo de nuevo cuando lo necesites.

## Actualizar

Envía `/actualizar_botikor` al bot. Si hay una versión más nueva:

1. la descarga de este repositorio;
2. comprueba que no está alterada;
3. la instala;
4. se reinicia.

Tu configuración no se toca. Los cambios de cada versión están en el [CHANGELOG](../CHANGELOG.md).

## Manejarlo desde el deco

| Para… | Comando |
|---|---|
| Parar el bot | `/etc/init.d/botikor stop` |
| Arrancarlo | `/etc/init.d/botikor start` |
| Ver si está en marcha | `/etc/init.d/botikor status` |
| Cambiar la configuración o el idioma (con el bot parado) | `/usr/script/botikor.sh --configurar` |
| Volver a instalar el arranque automático | `/usr/script/botikor.sh --instalar` |
| Ver el log | `tail -50 /home/root/botikor/botikor.log` |

## Desinstalar

Ejecuta estos comandos en el deco, uno detrás de otro:

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

El último borra también tu configuración y el log. Después, si quieres, borra el bot en Telegram con @BotFather (`/deletebot`).
