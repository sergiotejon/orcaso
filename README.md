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

Los valores por defecto (`miequipo`, `&equipo-privado`) están para no tener que
escribirlos cada vez; cámbialos con esas variables o con `--workspace` y
`--default-channel`.

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
bin/weeslack                    lanzador
bin/slack-img                   imagen o GIF -> arte ANSI dentro de un buffer
bin/slack-open                  URL -> pestaña del navegador de Orca
MANUAL.md
```
