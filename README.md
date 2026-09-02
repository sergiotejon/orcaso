# orcaso

**No salir de Orca para nada.**

[Orca](https://onorca.dev) ya te da, en pestañas, los terminales, los CLIs de
IA y un navegador. Lo que faltaba era Slack: seguir hablando con la gente sin
cambiar de aplicación, sin notificaciones de escritorio robándote el foco y sin
perder el sitio.

Este repositorio pone Slack en una pestaña más — **WeeChat + wee-slack** — y
deja el proyecto montado con las pestañas básicas: el CLI de IA que uses y
Slack, cada uno en la suya.

Todas las dependencias van fijadas con **devbox/Nix** y la configuración está
versionada aquí. No se instala nada en el sistema salvo el propio devbox, y dos
máquinas con el mismo commit acaban idénticas.

| Lo que antes hacías fuera | Dónde queda ahora |
|---|---|
| Slack en su app | una pestaña de terminal |
| El CLI de IA | otra pestaña, montada sola |
| Abrir un enlace de un mensaje | pestaña del navegador de Orca, con una tecla |
| Ver un GIF que te han mandado | dentro del buffer, o en el navegador de Orca |
| Buscar un canal entre cien | `Ctrl`+`g` y tres letras |

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

## El proyecto en Orca

`install.sh` deja las pestañas montadas al terminar. También se puede lanzar
suelto:

```bash
./bin/orcaso-project            # crea las pestañas que falten
./bin/orcaso-project --focus    # y deja el foco en la última
./bin/orcaso-project --web https://ejemplo.com   # abre además el navegador
./bin/orcaso-project --cli codex                 # fuerza otro CLI de IA
```

Crea una pestaña por cada cosa:

- **el CLI de IA**, detectado en este orden: `--cli` o `ORCASO_AI_CLI` → el
  agente que Orca ya tenga en marcha (lo dice `orca terminal list --json`) → la
  cuenta gestionada en `orca account list` → el primero instalado de `claude`,
  `codex`, `opencode`, `cursor-agent`, `aider`;
- **Slack**, en terminal o en el navegador (ver abajo).

Es idempotente: si la pestaña ya existe, no crea otra. Y si ya hay un WeeChat
corriendo no abre un segundo, porque se pelearían por el mismo directorio de
configuración.

Para saltárselo durante la instalación: `./install.sh --no-project`.

## Si no te convence WeeChat: Slack web en una pestaña

El objetivo es no salir de Orca, y eso se cumple igual con el Slack de siempre
dentro del navegador de Orca. No hace falta desinstalar nada:

```bash
./bin/orcaso-project --slack web
```

Para que sea el modo por defecto, en `weechat/local.env`:

```bash
: "${ORCASO_SLACK:=web}"
: "${ORCASO_SLACK_URL:=https://miequipo.slack.com}"
```

**Pon la URL de tu workspace.** La genérica `https://app.slack.com/client`
redirige a la pantalla de "encuentra tu espacio de trabajo".

**La primera vez hay que iniciar sesión en esa pestaña.** El perfil de navegador
de Orca importa cookies de Chrome, pero la sesión de Slack no viaja: sale la
pantalla de conexión (con tu SSO, si lo usáis). Después el perfil la conserva.

### Cuál usar

| | WeeChat (`--slack terminal`) | Web (`--slack web`) |
|---|---|---|
| Arranque y consumo | instantáneo, unos MB | otro Electron cargado |
| Manejo | todo con el teclado | ratón, como siempre |
| Hilos, reacciones, edición, búsqueda | sí | sí |
| Huddles, canvas, listas, workflows, apps | no | sí |
| Imágenes y GIFs | arte ANSI, o al navegador con una tecla | nativo |
| Mantenimiento | hay que renovar el token cuando caduca | ninguno |

Los dos modos conviven: puedes tener WeeChat para el día a día y abrir la
pestaña web solo cuando necesites un huddle. `--slack none` no monta ninguna.

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
bin/orcaso-project              monta las pestañas del proyecto en Orca
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
