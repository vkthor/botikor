# Seguridad

[English](SECURITY.md) | **Español**

BOTikor corre como **root** dentro del deco y lo controla por Telegram. Conviene saber qué protege y qué no.

## Cómo informar de un problema de seguridad

Si encuentras una vulnerabilidad, **no abras una incidencia pública**. Usa el botón **«Report a vulnerability»** de la pestaña *Security* de este repositorio (aviso privado de GitHub). Explica qué has encontrado y cómo reproducirlo. Contestaremos en cuanto podamos; es un proyecto personal y sin plazos garantizados.

## Qué hace el bot para protegerte

- **Un solo chat autorizado.** Sólo obedece al chat configurado en `ID`. Los mensajes de cualquier otro chat se ignoran y se anotan en el log.
- **Actualizaciones verificadas.** `/actualizar_botikor` y `/downgrade` descargan sólo de las releases de este repositorio y sólo por HTTPS; ni siquiera una redirección puede bajar a HTTP. Antes de instalar, el bot comprueba tres cosas:
  - la huella SHA-256 publicada junto al script;
  - que no tiene errores de sintaxis;
  - la versión.

  Si algo no cuadra, no instala nada.
- **Los secretos no van al log.** El token del bot y la contraseña de OpenWebIF nunca se escriben en el log, que es lo que envía `/log`. De las direcciones web (la de la lista de ghostreamy y los enlaces de `/canal`, que llevan el código del usuario) sólo se anota el servidor y el puerto. El log sí lleva tu IP pública: tenlo en cuenta si lo compartes para pedir ayuda.
- **La configuración, aparte y protegida.** Va en `botikor.conf` con permisos 600 (sólo root) y el bot nunca la ejecuta: sólo lee las claves que conoce. El script publicado no lleva datos de nadie.
- **Sólo conexiones de salida.** El bot pregunta a Telegram cada pocos segundos; no abre ningún puerto en el deco ni en el router.

## Lo que NO protege (y qué hacer)

- **Quien tenga tu token controla el bot.** Si crees que alguien lo ha visto, revócalo en @BotFather (`/revoke`) y configura el nuevo.
- **Quien entre en tu Telegram** puede apagar el deco o pedir enlaces. Activa la verificación en dos pasos de Telegram.
- **Las actualizaciones se fían de este repositorio.** La huella detecta descargas corruptas o alteradas por el camino, pero no protege si alguien se hace con la cuenta que publica las versiones. Si prefieres no depender de eso, no uses `/actualizar_botikor` y actualiza a mano, revisando el código.
- **El puerto de ghostreamy abierto a Internet** (para `/canal`) recibe visitas de programas que buscan puertos abiertos desde el primer día. Usa una contraseña larga en el usuario de ghostreamy y no compartas la «m3u URL» ni la lista descargada: llevan el código de acceso del usuario.
- **El enlace de `/canal` lleva la IP pública de tu casa.** Compártelo sólo con quien quieras que la sepa.
- **`/parar_stream` corta conexiones fabricando paquetes TCP** (sockets *raw*). Necesita root y sólo actúa sobre los puertos de streaming del propio deco.

## Versiones con soporte

Sólo la última versión publicada. Actualiza con `/actualizar_botikor`.
