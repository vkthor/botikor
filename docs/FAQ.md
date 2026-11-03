# Preguntas frecuentes y problemas

Antes que nada: envía **`/estado`** al bot. En un mensaje te dice qué responde y qué no, y suele señalar directamente el problema. Si el bot no contesta ni a eso, mira el primer apartado.

## El bot no contesta

1. **¿Está en marcha?** Entra en el deco por SSH y ejecuta:

   ```bash
   /etc/init.d/botikor status
   ```

   Si dice que no está en marcha, arráncalo con `/etc/init.d/botikor start`.
2. **Mira el final del log:**

   ```bash
   tail -30 /home/root/botikor/botikor.log
   ```

   - **`ERROR: no existe .../botikor.conf`:** el bot no está configurado. Lánzalo a mano una vez, desde una terminal: `/usr/script/botikor.sh`.
   - **`getUpdates sin respuesta valida`:** el deco no tiene Internet, o el token ya no vale (por ejemplo, porque lo regeneraste en @BotFather). Para cambiar el token, sigue estos pasos:
     1. para el bot con `/etc/init.d/botikor stop`;
     2. lanza `/usr/script/botikor.sh --configurar`.
3. **¿Le escribes desde el chat correcto?** El bot solo obedece al chat que se configuró y no contesta a nadie más. Si cambiaste de cuenta de Telegram, vuelve a configurarlo.
4. **¿Hay dos bots usando el mismo token?** Por ejemplo, otra copia del script en otro deco. Telegram reparte los mensajes entre los dos y cada uno ve solo una parte. Usa un bot distinto para cada deco.

## `/zap` contesta, pero la tele no cambia de canal

Faltan los dos ajustes de «zap» (ver la [guía de instalación](INSTALACION.md), pasos 1 y 2):

- en el **usuario de ghostreamy**: «Forzar zap antes de reproducir un canal»;
- en **OpenWebIF**: «Saltar antes del Stream» (*Zap before streaming*).

Hacen falta **los dos**. El bot no puede comprobar si la tele ha cambiado: solo pide el canal a ghostreamy.

## `/lista` dice que no hay canales, o `/actualizar_canales` falla

- `/estado` te dice si **ghostreamy responde** y de dónde sale la lista.
- **«no se ha podido descargar (… 401)»:** la «m3u URL» ya no vale. Pasa si cambiaste la contraseña o borraste la lista en ghostreamy. Cópiala otra vez de ghostreamy → Listas y vuelve a configurar el bot.
- **«no se ha podido descargar (… Couldn't connect)»:** ghostreamy no está en marcha, o escucha en otro puerto.
- **«lo descargado no es una lista m3u con canales»:** la dirección no es la del botón «m3u URL», o la lista está vacía.

Si `/actualizar_canales` falla, el bot sigue usando la lista anterior.

## El enlace de `/canal` no funciona fuera de casa

- **¿Está abierto el puerto en el router?** Hace falta una redirección del puerto externo (`GHOST_PORT_EXT`) al puerto de ghostreamy en el deco. Ver la [guía](INSTALACION.md), paso 8.
- **¿Tienes CG-NAT?** Si tu operador no te da una IP pública propia, no se puede entrar desde fuera.
- **¿Ha cambiado tu IP?** El enlace lleva la IP pública del momento en que lo pediste. Pídelo otra vez.
- **¿Alguien más está viendo algo?** La versión gratuita de ghostreamy solo admite un cliente a la vez.

## `/estado` dice que OSCam tiene PROBLEMAS

Significa que en los últimos 5 minutos muchos descifrados han fallado («timeout», «not found»…) o que un lector no consigue conectar con su servidor. Normalmente es un problema de tu servidor de claves, no del deco ni del bot. Mira en la web de OSCam el estado de tus lectores.

Si dice que **no encuentra el log de OSCam**, actívalo (`logfile` en `oscam.conf`) o pon su ruta en `OSCAM_LOG=` dentro de `botikor.conf`. Si no usas OSCam, deja `OSCAM_LOG=` vacío.

## No me avisa de las grabaciones

El bot mira la carpeta `GRABACIONES` de `botikor.conf`, que por defecto es `/hdd/movie`. Si tu deco graba en otro sitio (un USB, un disco de red…), cambia esa línea y reinicia el bot. `/estado` te dice si la carpeta existe.

## ¿Cómo cambio la configuración?

Con el bot parado:

```bash
/etc/init.d/botikor stop
```

```bash
/usr/script/botikor.sh --configurar
```

Te vuelve a hacer las preguntas, con tus valores actuales por defecto. También puedes editar `/home/root/botikor/botikor.conf` a mano y reiniciar el bot. El formato y el significado de cada línea están en [`botikor.conf.ejemplo`](../botikor.conf.ejemplo).

## ¿Puedo usar el bot desde varios chats o con varias personas?

No: obedece a un único chat, el tuyo. Los mensajes de cualquier otro chat se ignoran (y quedan anotados en el log).

## ¿Puedo volver a una versión anterior?

Sí: `/downgrade` te dice qué versiones hay publicadas, y `/downgrade 1.0.0` instala esa. Además, cada actualización deja la versión anterior en `/usr/script/botikor.sh.anterior`.

## ¿Qué pasa si se va la luz o reinicio el deco?

El bot arranca solo con el deco. Recuerda por dónde iba leyendo los mensajes, así que no repite órdenes viejas (por ejemplo, un «apagar» que ya cumplió).
