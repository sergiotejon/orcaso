# orcaso

Slack en la terminal: **WeeChat + wee-slack**, con todas las dependencias
fijadas por **devbox/Nix** y la configuración versionada en el propio
repositorio.

No instala nada en el sistema salvo el propio devbox. Dos máquinas con el mismo
commit acaban con exactamente las mismas versiones.

## Instalación

```bash
git clone git@github.com:sergiotejon/orcaso.git
cd orcaso
./install.sh
```

Si no hay devbox, lo instala (y devbox instala Nix si hace falta). El script es
idempotente. Te pedirá el token de sesión de Slack; también se puede pasar por
entorno:

```bash
SLACK_WORKSPACE=miequipo \
SLACK_DEFAULT_CHANNEL='#general' \
SLACK_TOKEN=xoxc-... \
SLACK_COOKIE='d=xoxd-...' \
./install.sh
```

O de forma permanente, en un fichero que git ignora:

```bash
cp weechat/local.env.example weechat/local.env
$EDITOR weechat/local.env
```

```bash
: "${SLACK_WORKSPACE:=miequipo}"
: "${SLACK_DEFAULT_CHANNEL:=&equipo-privado}"
```

El prefijo del canal importa: `#` público, `&` privado, `@` grupo. La
precedencia es opciones de la línea de comandos > entorno > `local.env` >
valores por defecto.

## Conseguir el token de Slack

Hace falta un **token de sesión**, que son dos piezas: el token en sí y una
cookie. Los dos se sacan del navegador, con la sesión de Slack ya iniciada.

1. Abre <https://my.slack.com/customize> y comprueba arriba a la derecha que es
   el workspace que quieres.

2. Abre la consola del navegador — `Cmd`+`Opt`+`J` en Chrome, `Cmd`+`Opt`+`K`
   en Firefox — y ejecuta:

   ```js
   window.prompt("Session token:", TS.boot_data.api_token)
   ```

   Sale un cuadro con el token, que empieza por `xoxc-`. Cópialo.

3. En la misma consola, ve a **Application** (Chrome) o **Storage** (Firefox),
   despliega **Cookies**, entra en el dominio de Slack y copia el valor de la
   cookie llamada **`d`**. Empieza por `xoxd-`.

4. Dáselos a `install.sh` cuando los pida, o pásalos por entorno:

   ```bash
   SLACK_TOKEN=xoxc-... SLACK_COOKIE='d=xoxd-...' ./install.sh
   ```

En algunos workspaces hace falta mandar además la cookie `d-s`, separándolas con
`;`:

```bash
SLACK_COOKIE='d=xoxd-...; d-s=1699...'
```

### Lo que conviene saber

- **La cookie caduca al iniciar o cerrar sesión en el navegador.** Cuando
  wee-slack deje de conectar, casi siempre es eso: repite los pasos y relanza
  `install.sh`, o cambia las opciones a mano y `/python reload slack`.
- **Un token de sesión no se puede revocar**, así que trátalo como una
  contraseña. Se guarda en texto plano en `~/.config/weechat/slack.conf`;
  conviene cifrarlo con el almacén de WeeChat — ver
  [MANUAL.md §3](MANUAL.md#cifrar-el-token).
- **No es una vía oficial de Slack** y puede dejar de funcionar en cualquier
  momento. Un token OAuth `xoxp-` también sirve si lo consigues por otro medio
  (wee-slack detecta el tipo), pero la v3 ya no trae el flujo para obtenerlo, y
  con OAuth los hilos solo se marcan como leídos en local.

## Arrancar

```bash
weeslack
```

Es un lanzador que hace `devbox run -c <repo> -- weechat`. Escribir `weechat` a
secas arranca cualquier otro WeeChat del PATH, y ese no llevará
`websocket-client` en su Python, así que wee-slack no cargará.

## Lo que monta

- **WeeChat** con `websocket-client` dentro del Python que embebe su plugin.
  Esa es la razón de que haya un flake y no solo un `devbox.json`: es un
  override de la derivación, y devbox no sabe expresarlo.
- **wee-slack v3** compilado del fuente — `master` no publica un `slack.py`
  listo para usar.
- **go.py** (saltar a un buffer por nombre) y **url_hint.py** (numera las URLs).
- **chafa** y dos scripts propios para ver imágenes y GIFs desde WeeChat.
- La configuración de `weechat/*.conf`: teclas, ratón, apariencia, canal por
  defecto, y los logs de conversaciones desactivados.

## Atajos imprescindibles

| Tecla | Qué hace |
|---|---|
| `Ctrl`+`g` | saltar a un canal por nombre |
| `Ctrl`+`v` | volver al buffer anterior (así se sale de un hilo) |
| `Tab` | completar; la lista sale en vertical debajo |
| `Ctrl`/`Alt` + clic | abrir el hilo de un mensaje |
| `Alt`+`i` / `Alt`+`o` | ver una imagen en el buffer / abrir el GIF en el navegador |

En macOS, si un atajo con `Alt` no responde es la tecla Option, que el terminal
no manda como Meta: pulsa `Esc` y luego la letra.

## Documentación

**[MANUAL.md](MANUAL.md)** — manual completo: comandos, opciones, hilos,
imágenes, mantenimiento y diagnóstico. Está verificado contra el código de
wee-slack v3.0.0, no contra su README, que en varios puntos sigue documentando
la v2.

## Estructura

```
devbox.json / devbox.lock       las dependencias y sus versiones fijadas
nix/flake.nix / nix/flake.lock  el WeeChat con websocket-client en su Python
install.sh                      instalación y configuración, idempotente
weechat/settings.conf           la configuración de WeeChat, versionada
weechat/default-channel.conf    el trigger del canal por defecto
weechat/local.env.example       plantilla de los ajustes de cada máquina
bin/weeslack                    lanzador
bin/slack-img                   imagen o GIF -> arte ANSI dentro de un buffer
bin/slack-open                  URL -> pestaña del navegador de Orca
MANUAL.md
```

## Licencia

[MIT](LICENSE).

Este repositorio solo contiene el instalador, la configuración y unos scripts
propios. [WeeChat](https://weechat.org/) (GPL-3.0),
[wee-slack](https://github.com/wee-slack/wee-slack) (MIT),
[go.py](https://weechat.org/scripts/source/go.py.html),
[url_hint.py](https://weechat.org/scripts/source/url_hint.py.html) y
[chafa](https://hpjansson.org/chafa/) los instala `install.sh` y cada uno
conserva la suya.
