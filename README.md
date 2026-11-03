# BOTikor

Bot de Telegram para manejar un decodificador **Enigma2** con el plugin **ghostreamy** desde el móvil, estés donde estés.

Le escribes al bot y él te da los enlaces para ver tus canales fuera de casa, cambia de canal, enciende o apaga el deco y te avisa cuando empieza una grabación o cuando alguien se conecta por streaming.

> **Estado: beta.** Funciona a diario con OpenSPA 8.3 y ghostreamy 3.1.5. En otros decos e imágenes debería funcionar si cumplen los requisitos, pero no se ha probado.

## Qué hace

- **Lista de canales** (`/lista`) y **enlace para verlos fuera de casa** (`/canal 5`), en VLC o cualquier reproductor similar.
- **Cambia el canal** de la tele de casa (`/zap 5`).
- **Enciende, suspende, apaga o reinicia** el deco.
- **Avisa** cuando empieza una grabación y cuando alguien empieza o deja de ver un stream (con su IP y el canal).
- **Corta los streams** que estén en curso (`/parar_stream`).
- **`/estado`**: de un vistazo, si todo funciona (OpenWebIF, ghostreamy, OSCam, canales, grabaciones…).
- **Se actualiza solo** desde este repositorio cuando se lo pides.

Sólo obedece a **tu** chat de Telegram; los mensajes de cualquier otra persona se ignoran.

## Requisitos

- Un deco con **Enigma2** y acceso de root (SSH o telnet), con `bash`, `curl` y `python3` (las imágenes actuales los traen).
- **ghostreamy** instalado, con **un solo usuario**, y con estos dos ajustes activados (sin ellos `/zap` podría no cambiar el canal):
  - en el usuario de ghostreamy: **«Forzar zap antes de reproducir un canal»**;
  - en OpenWebIF: **«Saltar antes del Stream»** (en inglés, *Zap before streaming*).
- Un **bot de Telegram** propio, creado con [@BotFather](https://t.me/BotFather).
- Opcional: **OSCam** con su log activado, para que `/estado` diga si se está descifrando bien.
- Opcional: abrir en el router el puerto de ghostreamy, para ver los canales fuera de casa con `/canal`.

## Instalación rápida

Entra en el deco por SSH y ejecuta:

```bash
curl -fsSLo /tmp/botikor.sh https://github.com/vkthor/botikor/releases/latest/download/botikor.sh && bash /tmp/botikor.sh
```

El propio script te hace cinco preguntas (token del bot, tu chat, OpenWebIF, lista de canales y puertos), se instala y se pone en marcha. Al acabar, te escribe por Telegram.

Instalación paso a paso: **[guía de instalación](docs/INSTALACION.md)**.

## Comandos

Se pueden escribir con o sin `/`, en mayúsculas o minúsculas. Si le escribes cualquier otra cosa, el bot te contesta con la lista de comandos.

| Comando | Qué hace |
|---|---|
| `/lista` | Lista de canales numerada. |
| `/canal X` | Enlace para ver el canal X fuera de casa (y el transcodificado, si lo hay). |
| `/zap X` | Pone el canal X en el deco. |
| `/actualizar_canales` | Vuelve a descargar la lista de canales de ghostreamy. |
| `/estado` | Resumen de si todo funciona. |
| `/log` | Te envía el registro del bot (para buscar fallos). |
| `/encender` | Saca el deco de standby. |
| `/suspender` | Pone el deco en standby (el bot sigue funcionando). |
| `/apagar` | Apagado completo: el bot deja de funcionar hasta que enciendas el deco. |
| `/parar_stream` | Corta los streams que haya en curso. |
| `/reiniciar_deco` | Reinicia el deco. |
| `/reiniciar_bot` | Reinicia solo el bot. |
| `/actualizar_botikor` | Instala la última versión publicada, si hay una más nueva. |
| `/downgrade X` | Instala una versión concreta (sin X, te dice cuáles hay). |
| `/exit` | Cierra el bot. |

## Configuración

Todo lo de tu instalación está en `/home/root/botikor/botikor.conf`, que sólo puede leer root. Para cambiarlo:

```bash
/etc/init.d/botikor stop
```

```bash
/usr/script/botikor.sh --configurar
```

También puedes editar el fichero a mano y reiniciar el bot. Qué significa cada línea: [`botikor.conf.ejemplo`](botikor.conf.ejemplo).

## Más información

- [Guía de instalación](docs/INSTALACION.md)
- [Preguntas frecuentes y problemas](docs/FAQ.md)
- [Seguridad](SECURITY.md)
- [Cómo está hecho por dentro](ARQUITECTURA.md), para quien quiera tocar el código

## Licencia

BOTikor es software libre bajo la [Licencia Pública General GNU, versión 3 o posterior](LICENSE). Puedes usarlo, estudiarlo, modificarlo y compartirlo; si distribuyes una versión modificada, tiene que seguir siendo libre con la misma licencia. Se ofrece **sin ninguna garantía**.

ghostreamy, OSCam, Enigma2 y OpenWebIF son proyectos de terceros, independientes de este.
