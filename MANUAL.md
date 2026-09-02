# Slack en la terminal — WeeChat + wee-slack

Manual de uso de esta instalación. Todo lo de aquí está verificado contra el
código de **wee-slack v3.0.0** instalado en la máquina, no contra el README
oficial (que en varios puntos sigue documentando la v2 — ver
[§14](#14-diferencias-con-el-readme-oficial)).

**Índice**

1. [Qué hay instalado](#1-qué-hay-instalado)
2. [Instalar y actualizar con `install.sh`](#2-instalar-y-actualizar-con-installsh)
3. [Arrancar y conectar](#3-arrancar-y-conectar)
4. [Moverse entre canales](#4-moverse-entre-canales)
5. [Escribir](#5-escribir)
6. [Hilos](#6-hilos)
7. [Ratón y modo cursor](#7-ratón-y-modo-cursor) · [Ver imágenes y GIFs](#7-bis-ver-imágenes-y-gifs)
8. [Referencia de comandos](#8-referencia-de-comandos)
9. [Referencia de opciones](#9-referencia-de-opciones)
10. [Configuración aplicada](#10-configuración-aplicada)
11. [Controlar WeeChat desde el shell (FIFO)](#11-controlar-weechat-desde-el-shell-fifo)
12. [Mantenimiento](#12-mantenimiento)
13. [Diagnóstico](#13-diagnóstico)
14. [Diferencias con el README oficial](#14-diferencias-con-el-readme-oficial)

---

## 1. Qué hay instalado

| Componente | Versión | De dónde sale |
|---|---|---|
| WeeChat (con `websocket-client` dentro de su Python) | 4.10.0 | `nix/flake.nix`, vía devbox |
| `chafa` (imágenes como arte ANSI) | 1.18.2 | devbox |
| `git`, `curl`, `perl` (para la instalación) | fijadas | devbox |
| wee-slack | 3.0.0 (`master`) | compilado del fuente por `install.sh` |
| `go.py` (saltar a buffer por nombre) | 3.1.1 | descargado por `install.sh` |
| `url_hint.py` (numera las URLs) | 0.8 | descargado por `install.sh` |
| `bin/slack-img`, `bin/slack-open`, `bin/weeslack` | — | este repositorio |

Las **dependencias** están fijadas por Nix (`devbox.lock` y `nix/flake.lock`) y
viven en `/nix/store`: no se instala nada en el sistema salvo el propio devbox.
Los **scripts de WeeChat** (`slack.py`, `go.py`, `url_hint.py`) sí van al
directorio de datos del usuario, porque WeeChat los carga desde ahí y así se
actualizan sin recalcular hashes.

Los tres scripts tienen symlink en `~/.local/share/weechat/python/autoload/`,
así que se cargan solos al arrancar WeeChat.

Directorios (WeeChat usa XDG porque no existe un `~/.weechat` heredado):

| Qué | Dónde |
|---|---|
| Configuración | `~/.config/weechat/` (`slack.conf`, `weechat.conf`, …) |
| Datos y scripts | `~/.local/share/weechat/` |
| Log del núcleo | `~/.local/state/weechat/weechat.log` |
| FIFO de control | `~/.cache/weechat/weechat_fifo_<pid>` |

### Qué hay en este repositorio

```
devbox.json / devbox.lock       las dependencias y sus versiones fijadas
nix/flake.nix / nix/flake.lock  el WeeChat con websocket-client en su Python
install.sh                      instalación y configuración, idempotente
weechat/settings.conf           la configuración de WeeChat, versionada
weechat/default-channel.conf    el trigger del canal por defecto
bin/weeslack                    lanzador: arranca el WeeChat del entorno devbox
bin/slack-img                   descarga una imagen y la renderiza como arte ANSI
bin/slack-open                  abre una URL en una pestaña de Orca (o en el visor del sistema)
MANUAL.md                       este documento
```

La configuración **no está incrustada en el script**: vive en `weechat/*.conf`,
un comando de WeeChat por línea, para poder revisarla en un diff como cualquier
otro código. `install.sh` sustituye los marcadores `@REPO@`, `@WORKSPACE@` y
`@CHANNEL@` y manda el resultado a WeeChat. Para cambiar un ajuste de forma
permanente, edita ese fichero y vuelve a lanzar `./install.sh --no-token`; si lo
cambias solo con `/set` desde WeeChat, se perderá en la próxima máquina.

> **Por qué hace falta Nix para esto.** El plugin `python.so` de WeeChat embebe
> un intérprete concreto, y `websocket-client` tiene que ser importable *desde
> ese* intérprete. Con un gestor de paquetes del sistema hay que averiguar
> contra cuál se enlazó (`otool -L`), instalarle el paquete y saltarse PEP 668
> con `--break-system-packages`. En Nix se declara y ya está:
>
> ```nix
> weechat.override {
>   configure = { availablePlugins, ... }: {
>     plugins = with availablePlugins; [
>       (python.withPackages (ps: with ps; [ websocket-client ]))
>     ];
>   };
> }
> ```
>
> Eso es lo que hay en `nix/flake.nix`, y es la razón de que haya un flake y no
> solo un `devbox.json`: devbox no sabe expresar un override de un paquete.

## 2. Instalar y actualizar con `install.sh`

En una máquina nueva basta con clonar el repositorio y ejecutar:

```bash
./install.sh
```

Si no hay devbox, lo instala (y devbox instala Nix si hace falta). A partir de
ahí todas las dependencias salen del entorno del proyecto. El script es
idempotente: se puede volver a ejecutar cuantas veces haga falta.

```bash
./install.sh --update         # actualiza wee-slack y los scripts, y los recarga
./install.sh --no-config      # instala sin tocar la configuración de WeeChat
./install.sh --no-token       # no pregunta por el token
./install.sh --default-channel '#otro'   # canal al que saltar al arrancar
./install.sh --no-default-channel
./install.sh --workspace otro
./install.sh --help
```

Totalmente desatendido:

```bash
SLACK_WORKSPACE=miequipo SLACK_TOKEN=xoxc-... SLACK_COOKIE='d=xoxd-...' ./install.sh
```

Qué hace, en orden:

1. Instala devbox si falta.
2. `devbox install`: WeeChat (del flake, con `websocket-client` dentro de su
   Python), `chafa`, `git`, `curl` y `perl`, todo en las versiones de los
   lockfiles.
3. Clona wee-slack y ejecuta su `build.sh` — `master` **no** publica un
   `slack.py` compilado, hay que generarlo del paquete `slack/` + `main.py`.
   Copia el resultado y `weemoji.json`, y crea los symlinks de `autoload/`.
4. Descarga `go.py` y `url_hint.py`.
5. Deja el lanzador en `~/.local/bin/weeslack`.
6. Aplica `weechat/settings.conf`, el trigger del canal por defecto y registra
   el workspace con el token.

Para aplicar la configuración habla con WeeChat por su FIFO si lo detecta
corriendo (así no pierdes la sesión); si no, lo arranca en efímero, aplica,
guarda y sale.

### Arrancar

```bash
weeslack
```

Es un lanzador que hace `devbox run -c <repo> -- weechat`. También valen
`devbox run -c <repo> start` o entrar al entorno con `devbox shell` y escribir
`weechat`.

> Escribir `weechat` a secas fuera del entorno **no** arranca este WeeChat, sino
> cualquier otro que tengas en el PATH — y ese no llevará `websocket-client` en
> su Python, así que wee-slack no cargará.

### Trabajar dentro del entorno

```bash
devbox shell         # entra al entorno del proyecto
devbox run -l        # lista los scripts definidos en devbox.json
devbox update        # actualiza los lockfiles
```

Ojo con `devbox run`: resuelve primero los **scripts** de `devbox.json` y solo
después los binarios, así que el script que arranca WeeChat se llama `start` y
no `weechat`, para no secuestrar al binario. Y `devbox run` ejecuta siempre en
el directorio del proyecto, no en el directorio actual.

## 3. Arrancar y conectar

```bash
weeslack
```

El workspace `miequipo` tiene `autoconnect on`, así que conecta solo. A mano:

```
/slack connect miequipo
/slack connect -all
/slack disconnect miequipo
/slack workspace list
/slack workspace listfull
```

Al conectar, wee-slack abre un buffer por **cada canal del que eres miembro**,
más los DMs y grupos que tengas abiertos o con mensajes sin leer. Si estás en
150 canales, tendrás 150 buffers: por eso importa [§4](#4-moverse-entre-canales).

### Token

Vive en `~/.config/weechat/slack.conf`, sección `[workspace]`:

```
/slack workspace add miequipo
/set slack.workspace.miequipo.api_token xoxc-...
/set slack.workspace.miequipo.api_cookies d=xoxd-...
/set slack.workspace.miequipo.autoconnect on
/save
```

También en una sola línea, porque `workspace add` acepta las opciones del
workspace como parámetros:

```
/slack workspace add miequipo -api_token=xoxc-... -api_cookies=d=xoxd-... -autoconnect=on
```

Es un **token de sesión** sacado del navegador:

1. https://my.slack.com/customize (comprueba que es el workspace correcto)
2. Consola (`Cmd`+`Opt`+`J`) → `window.prompt("Session token:", TS.boot_data.api_token)`
3. Application/Storage → Cookies → valor de la cookie `d`

Si cierras o abres sesión en el navegador, la cookie `d` se invalida y hay que
renovarla. En algunos casos hace falta añadir también la cookie `d-s`,
separándolas con `;`.

Un token OAuth `xoxp-` también sirve si lo consigues por otra vía: el código
detecta el tipo y usa otra ruta de inicialización. Con OAuth, los hilos solo se
marcan como leídos en local.

### Cifrar el token

Ambas opciones se evalúan (`/help eval`), así que pueden apuntar al almacén
seguro de WeeChat:

```
/secure passphrase <passphrase>
/secure set slack_miequipo xoxc-...
/secure set slack_miequipo_cookie d=xoxd-...
/set slack.workspace.miequipo.api_token "${sec.data.slack_miequipo}"
/set slack.workspace.miequipo.api_cookies "${sec.data.slack_miequipo_cookie}"
```

### Quitar un workspace

```
/slack workspace del miequipo
/slack workspace rename miequipo trabajo
```

## 4. Moverse entre canales

### Saltar por nombre (lo que querrás el 90% del tiempo)

`go.py` da un buscador incremental de buffers, asociado a **`Ctrl`+`g`** y a
**`Alt`+`g`**: escribes parte del nombre, `Tab`/flechas entre coincidencias,
`Enter` para saltar.

> **Si `Alt`+`g` no hace nada**, no es go.py: es la tecla Option de macOS. Muchos
> terminales no la mandan como Meta, así que `Alt`+`<letra>` no llega nunca a
> WeeChat (en su lugar produce el carácter compuesto: `©`, `ø`, `¡`…). Hay tres
> salidas, y las tres funcionan:
>
> 1. **`Ctrl`+`g`**, que está asignado a lo mismo.
> 2. **Pulsar `Esc` y luego `g`**. En WeeChat, `Esc`+tecla *es* `Alt`+tecla, así
>    que esto vale para todos los atajos con Alt: `Esc` `a`, `Esc` `i`, `Esc` `<`…
> 3. Activar "Option como Meta" en los ajustes del terminal. Orca usa xterm.js y
>    tiene la opción `macOptionIsMeta`; búscala en sus ajustes de terminal.
>
> Para distinguir un problema del otro: si `Esc` `g` abre el buscador, go.py está
> bien y el problema es la tecla Option.

Si alguna vez se pierden los atajos: `/key bind meta-g /go` y `/key bind ctrl-g /go`.

go.py enseña las coincidencias **en horizontal**, en la línea de entrada, y no
tiene modo vertical. Está configurado para que eso no moleste:

```
/set plugins.var.python.go.short_name on      #equipo-privado, no python.slack.miequipo.#equipo-privado
/set plugins.var.python.go.buffer_number off  sin el número delante
/set plugins.var.python.go.fuzzy_search on    coincidencia aproximada
/set plugins.var.python.go.min_chars 2        no lista nada hasta el segundo carácter
```

### Lista vertical de verdad: la barra de completado

Para una lista de una opción por línea está la barra `complist`, que usa el item
`completion` de WeeChat:

```
/buffer tech<Tab>
```

Aparece debajo una lista vertical con los buffers que encajan; `Tab` va
recorriéndolos y `Enter` salta. La barra solo se ve mientras completas (`size 0`
se ajusta al contenido, así que mide cero cuando no hay nada) y sirve para todo:
nicks, emoji, comandos, nombres de canal.

```
/bar add complist window bottom 0 0 completion
/bar set complist filling_top_bottom vertical
/bar set complist size_max 12
```

### Teclas por defecto de WeeChat

| Tecla | Acción |
|---|---|
| `Ctrl`+`g` o `Alt`+`g` | saltar a un buffer por nombre (`go.py`) |
| `Alt`+`↑` / `Alt`+`↓` | buffer anterior / siguiente |
| `Alt`+`←` / `Alt`+`→` | ídem |
| `F5` / `F6` | ídem |
| `Alt`+`a` | siguiente buffer con actividad (*smart jump*) |
| `Alt`+`1`…`Alt`+`9`, `Alt`+`0` | ir al buffer 1–10 |
| `Alt`+`j` + dos dígitos | ir al buffer NN |
| `Ctrl`+`v` o `Alt`+`<` | buffer **visitado** anteriormente (así se vuelve de un hilo) |
| `Alt`+`>` | siguiente visitado |
| `Alt`+`/` | último buffer mostrado |
| `Alt`+`Shift`+`n` | mostrar/ocultar la lista de nicks |
| `Ctrl`+`s` | buscar texto en el buffer actual |
| `Ctrl`+`r` | buscar en el historial de lo que has escrito |
| `Alt`+`h`,`Alt`+`c` | limpiar la *hotlist* |
| `Alt`+`u` | ir a la primera línea sin leer |
| `PgUp` / `PgDn` | desplazar el buffer |
| `Alt`+`m` | activar/desactivar el ratón |
| `F1` / `F2` | desplazar la lista de canales |

También sirve `/buffer <nombre-parcial>` con `Tab`.

### Abrir algo que no está abierto

```
/join #nombre-canal          unirse a un canal público
/query nombre.persona        abrir un DM (admite varios nicks para un grupo)
/part                        salir del canal actual
```

Para buscar canales o personas cuyo nombre no recuerdas, wee-slack abre un
buffer de búsqueda interactivo:

```
/slack search channels infra
/slack search users maria
```

Dentro te mueves con las flechas y abres con `Enter`.

### Ajustar la anchura de la lista de canales

La `buflist` es una *bar* de WeeChat; por defecto `size 0` (automático: se
ajusta al nombre más largo), con un tope de 25 puesto por la configuración.

```
/bar set buflist size 25        ancho fijo de 25 columnas
/bar set buflist size 0         automático
/bar set buflist size_max 30    automático, pero sin pasar de 30
/bar set buflist position top   arriba en vez de a la izquierda
/bar toggle buflist             ocultar / mostrar
```

### Canal por defecto al arrancar

Al arrancar, WeeChat salta solo a **`&equipo-privado`**. Lo hace un trigger
que reacciona a la apertura de ese buffer:

```
/trigger listfull slack_default_buffer
```

No sirve un comando de arranque normal (`weechat.startup.command_after_plugins`)
porque los buffers de Slack no existen hasta que termina de conectar, que es
asíncrono.

Para cambiar de canal hay que tocar el nombre completo del buffer en las dos
partes del trigger. El prefijo importa: `#` canal público, `&` canal privado,
`@` grupo, nada para los DMs.

```
/trigger set slack_default_buffer conditions "${buffer[${tg_signal_data}].full_name} == python.slack.miequipo.#otro-canal"
/trigger set slack_default_buffer command "/buffer python.slack.miequipo.#otro-canal"
/save
```

O más cómodo, con el script: `./install.sh --default-channel '#otro-canal'`.

Para desactivarlo: `/trigger del slack_default_buffer`.

### La lista de integrantes del canal

Está **oculta**. Ocupaba ancho y en los canales grandes de Slack es enorme.

```
/bar toggle nicklist              mostrarla puntualmente
/set weechat.bar.nicklist.hidden off   volver a mostrarla siempre
```

También con `Alt`+`Shift`+`n`.

Los cambios se aplican al instante; `/save` para que persistan.

## 5. Escribir

Escribes en la línea inferior y `Enter` envía.

- **Autocompletar**: `@nom` + `Tab` (nicks), `#can` + `Tab` (canales),
  `:tac` + `Tab` (emoji, gracias a `weemoji.json`).
- **Menciones**: `@usuario`, `#canal` y los grupos se convierten en menciones
  reales de Slack.
- **Multilínea**: `Alt`+`Enter` inserta un salto de línea sin enviar.
- **Acción**: `/me está compilando`.

Completados que aporta wee-slack: `%(slack_workspaces)`, `%(slack_channels)`,
`%(slack_commands)`, `%(slack_emojis)`, `%(threads)`, `%(nicks)`.

### Sintaxis especial de la línea de entrada

Los mensajes se referencian por **índice** (`1` = el más reciente, hacia atrás)
o por **hash** (`$a1b`, visible junto a cada mensaje).

| Escribes | Hace |
|---|---|
| `+:smile:` | reacciona al último mensaje |
| `3+:smile:` | reacciona al 3º mensaje más reciente |
| `$a1b+:eyes:` | reacciona al mensaje con hash `$a1b` |
| `-:smile:` | quita tu reacción del último mensaje |
| `+😄` | también acepta el carácter emoji directamente |
| `s/viejo/nuevo/` | edita tu último mensaje |
| `2s/viejo/nuevo/` | edita tu 2º mensaje más reciente |
| `s/viejo/nuevo/gi` | flags: `g` todas, `i` ignora mayúsculas, `m` multilínea, `s` `.` incluye salto |
| `s///` | borra tu último mensaje |

Las barras dentro del patrón se escapan con `\/`. Las ediciones y borrados solo
aplican a mensajes tuyos; las reacciones, a cualquiera.

Para enviar literalmente algo que empieza por `/` o que parece una de estas
órdenes, prefíjalo con otra barra o con un espacio: `//slack`, ` s/a/b/`.

### Ajustar el alto de la línea de escritura

```
/bar set input size 3        siempre 3 líneas de alto
/bar set input size 0        automático (por defecto): 1 línea, crece al escribir multilínea
/bar set input size_max 10   límite al crecimiento automático
```

## 6. Hilos

```
/reply 2 texto                 responde en hilo al 2º mensaje más reciente
/reply $a1b texto              responde al mensaje con ese hash
/reply -alsochannel 2 texto    además lo publica en el canal
/reply -memessage 2 texto      lo envía como /me
/thread $a1b                   abre el hilo como un buffer propio
/thread                        abre el último hilo del canal
```

Un hilo abierto es un buffer normal: lo que escribas en él va al hilo.

### Recorrer los hilos de un canal

Un mensaje que tiene respuestas muestra su hash entre corchetes, `[$a1b]`. Desde
el canal:

- **`/thread` + `Tab`** — completa con los hashes de **todos** los hilos del
  canal, del más reciente al más antiguo. Es la forma de ver qué hilos hay y
  saltar a uno sin buscarlo a ojo. Completa tanto `$a1b` como `a1b`.
- **`/thread`** sin argumento abre el último hilo del canal.
- **`/cursor`** y `T` con el puntero sobre el mensaje padre.
- Con el ratón, clic derecho sobre el mensaje pega su id; luego `/thread <id>`.

Cada hilo abierto es un buffer independiente, llamado ` $a1b` en la lista de
canales. **Se crea al final de la lista, no junto a su canal** (wee-slack no le
asigna número y `weechat.look.buffer_position` es `end`), así que `Alt`+`↑`/`↓`
no te lleva de vuelta al canal.

Para **volver atrás desde un hilo**:

| Tecla | Qué hace |
|---|---|
| **`Ctrl`+`v`** | **volver**: al buffer visitado anteriormente, es decir, al canal |
| `Alt`+`<` (`Esc` `<`) | lo mismo; es el atajo de serie de WeeChat |
| `Alt`+`>` (`Esc` `>`) | rehace el salto hacia delante |
| `Alt`+`/` (`Esc` `/`) | alterna entre los dos últimos buffers mostrados |
| `Ctrl`+`g` | saltar al canal por su nombre |
| `/close` | cerrar el hilo (no te desuscribe en Slack) |

`Ctrl`+`v` está puesto porque `Alt`+`<` no llega en macOS si el terminal no manda
Option como Meta (ver §4); hace exactamente lo mismo.

`Alt`+`a` sigue funcionando para ir al siguiente hilo o canal con mensajes
nuevos.

Si prefieres ver los hilos agrupados bajo su canal en la lista lateral,
`/set buflist.look.sort name` los ordena alfabéticamente y el nombre completo de
un hilo empieza por el de su canal. La contrapartida es que el orden visual deja
de coincidir con los números de buffer de `Alt`+`1`…`Alt`+`9`.

Se cierran con `/close` (cerrar el buffer de un hilo no te desuscribe del hilo en
Slack; cerrar el de un canal sí te saca del canal, ver
`slack.look.leave_channel_on_buffer_close`).

Para que los hilos con mensajes nuevos aparezcan solos como buffers y así
recorrerlos con `Alt`+`a`:

```
/set slack.workspace.miequipo.auto_open_threads on
```

Con los tres límites por defecto activos (`only_subscribed`, `only_unread`,
`only_if_replies_not_in_channel`) solo se abren los hilos a los que estás
suscrito y que tienes sin leer, que es lo razonable. En v3 no hay comando para
suscribirte a un hilo: te suscribe Slack cuando respondes, o lo haces desde otro
cliente.

Apertura automática de hilos, por workspace:

```
/set slack.workspace.miequipo.auto_open_threads on
/set slack.workspace.miequipo.auto_open_threads_only_subscribed on
/set slack.workspace.miequipo.auto_open_threads_only_unread on
/set slack.workspace.miequipo.auto_open_threads_only_if_replies_not_in_channel on
```

Y para ver las respuestas de hilo dentro del canal padre, como en el cliente
web: `/set slack.look.display_thread_replies_in_channel on` (los mensajes así
mostrados llevan el prefijo `+`, configurable con `thread_broadcast_prefix`).

## 7. Ratón y modo cursor

El ratón está activado. Con **botón derecho** sobre un mensaje se pega su id en
la línea de entrada, listo para `/reply`, `s/…/…/`, `+:emoji:` o
`/slack linkarchive`. `Alt`+`m` lo desactiva (útil para seleccionar texto con el
ratón del terminal).

Con `/cursor` (modo cursor), colocando el puntero sobre un mensaje:

| Tecla | Acción |
|---|---|
| `M` | copiar el id del mensaje a la entrada |
| `R` | preparar un `/reply` a ese mensaje |
| `T` | abrir su hilo |
| `D` | borrarlo (si es tuyo) |
| `L` | pegar su enlace permanente |

wee-slack solo define estas teclas si no estaban ya asignadas.

### Abrir un hilo con el ratón

Sin escribir nada: **`Ctrl`+clic** (o **`Alt`+clic**) sobre cualquier mensaje
abre su hilo. Están las dos porque según el terminal una u otra puede quedar
interceptada antes de llegar a WeeChat.

```
/key bindctxt mouse @chat(python.*):ctrl-button1 hsignal:slack_focus_thread
/key bindctxt mouse @chat(python.*):alt-button1  hsignal:slack_focus_thread
```

El clic normal se deja libre a propósito (WeeChat lo usa para cambiar de ventana
y para los gestos), y el clic derecho lo reserva wee-slack para pegar el id del
mensaje.

## 7 bis. Ver imágenes y GIFs

WeeChat es una aplicación ncurses: **no puede pintar imágenes de verdad dentro
de sus buffers**, y ningún script lo arregla — WeeChat redibuja la pantalla por
encima de cualquier gráfico que se cuele, así que los protocolos de imagen de
kitty/iTerm2/Sixel no sobreviven. Lo que sí hay son dos caminos, ambos montados:

| Tecla | Comando | Qué hace |
|---|---|---|
| `Alt`+`i` | `/img <n>` | renderiza la imagen como **arte ANSI en un buffer de WeeChat** |
| `Alt`+`o` | `/gif <n>` | abre la URL en una **pestaña del navegador de Orca** (GIF animado de verdad) |

### Cómo se eligen las URLs

`url_hint.py` numera las URLs del buffer con dígitos en superíndice: `¹` es la
más reciente, `²` la anterior, etc. Ese número es el argumento:

```
/img 1     la última URL, como arte ANSI
/gif 2     la penúltima, en el visor del sistema
```

Las teclas `Alt`+`i` y `Alt`+`o` son atajos de `/img 1` y `/gif 1`.

Con una URL concreta, sin pasar por los hints:

```
/imgurl https://ejemplo.com/foto.png
/imgurl https://ejemplo.com/foto.png 100 40     ancho y alto en celdas
/imgurl /ruta/local/imagen.jpg
```

### Cómo funciona `/img`

El alias es:

```
/exec -nf -cl -noln -color weechat -name img <repo>/bin/slack-img $*
```

- `-nf` buffer nuevo de contenido libre (sin ajuste de línea, que destrozaría el
  dibujo), `-cl` lo limpia en cada imagen, `-noln` quita los números de línea.
- `-color weechat` convierte los códigos ANSI a colores de WeeChat.
  Cuidado: `-color ansi` significa lo contrario, "dejarlos tal cual", y se ve mal.
- **Nunca uses `-o`**: esa opción envía la salida del comando *como si la
  hubieras escrito*, es decir, publicaría el dibujo en el canal de Slack.

`bin/slack-img` descarga la imagen y la pasa por `chafa` (bloques Unicode, 256
colores). Los ficheros alojados en Slack necesitan autenticación, así que el
script saca el token y la cookie de `slack.conf` y los manda en las cabeceras;
para URLs públicas (Giphy, Tenor…) no hace falta. Si el servidor devuelve HTML
en vez de una imagen, avisa: suele ser el token caducado.

De un GIF solo se ve el **primer fotograma** — es texto, no hay animación
posible. Para verlo animado, `Alt`+`o`.

El buffer de la imagen se cierra con `/close`.

### Cómo funciona `/gif`

`bin/slack-open` usa la CLI de Orca, que tiene navegador propio:

```
orca tab create --worktree path:<repo> --url <url>
```

Se pasa el worktree explícitamente porque `current` se resuelve por el
directorio de trabajo, y WeeChat no se ejecuta necesariamente desde el
repositorio. Se puede fijar otro con la variable `ORCA_WORKTREE`. Si Orca no
está disponible o falla, el script cae al visor por defecto de macOS (`open`).

Otros comandos útiles de esa CLI: `orca tab list`, `orca tab close --index 0`,
`orca tab switch --index 1`.

## 8. Referencia de comandos

Los 22 comandos que registra wee-slack v3:

| Comando | Argumentos | Qué hace |
|---|---|---|
| `/slack` | — | nada útil (`print` de depuración del upstream) |
| `/slack connect` | `<workspace>` \| `-all` | conectar |
| `/slack disconnect` | `<workspace>` \| `-all` | desconectar |
| `/slack rehistory` | — | recargar el historial del buffer actual |
| `/slack workspace list` | — | listar workspaces |
| `/slack workspace listfull` | — | listarlos con detalle |
| `/slack workspace add` | `<nombre> [-opción=valor …]` | añadir uno |
| `/slack workspace rename` | `<viejo> <nuevo>` | renombrar |
| `/slack workspace del` | `<nombre>` | eliminar |
| `/slack query` (`/query`) | `<nick> [<nick>…]` | abrir DM o grupo |
| `/slack join` (`/join`) | `<#canal>` | unirse |
| `/slack part` (`/part`) | — | salir del canal |
| `/slack thread` (`/thread`) | `[<id>]` | abrir hilo |
| `/slack reply` (`/reply`) | `[-alsochannel] [-memessage] <id> <texto>` | responder en hilo |
| `/slack memessage` (`/me`) | `<texto>` | mensaje de acción |
| `/slack presence` | `away` \| `active` | cambiar presencia |
| `/slack mute` | `[list]` | silenciar el canal (alterna) o listar silenciados |
| `/slack search` | `channels` \| `users` `[texto]` | buffer de búsqueda |
| `/slack status` | `<texto>` \| `-clear` | estado de Slack |
| `/slack linkarchive` | `[<id>]` | enlace permanente al canal o mensaje |
| `/slack debug` | `tasks` \| `buffer` \| `open_buffer` \| `replay_events` \| `errors` \| `error` | depuración |

Solo `query`, `join`, `part`, `thread`, `reply` y `me` tienen alias de primer
nivel; **todo lo demás va bajo `/slack <sub>`**.

Además funcionan los comandos normales de WeeChat: `/buffer`, `/window`,
`/away`, `/topic`, `/filter`, `/key`, `/bar`, `/set`, `/fset`, `/save`…

Ayuda generada del código: `/help slack`, `/help reply`, `/help thread`…

## 9. Referencia de opciones

Navegador interactivo: **`/fset slack`** (`/fset weechat.look.*` para las de
WeeChat). Listado plano: `/set slack`. La mayoría de cambios en `slack.look.*`
necesitan `/python reload slack`.

### `slack.look.*`

| Opción | Por defecto | Qué hace |
|---|---|---|
| `bot_user_suffix` | `" :]"` | sufijo en el nick para indicar que es un bot |
| `thread_broadcast_prefix` | `"+"` | prefijo de las respuestas de hilo mostradas en el canal |
| `color_nicks_in_nicklist` | `off` | colorear nicks en la lista de nicks |
| `color_message_attachments` | `prefix` | `prefix`, `all` o `none` |
| `display_link_previews` | `always` | `always`, `only_internal`, `never` |
| `display_reaction_nicks` | `on` (cambiado) | mostrar quién ha reaccionado |
| `display_thread_replies_in_channel` | `off` | respuestas de hilo también en el canal padre |
| `external_user_suffix` | `"*"` | sufijo para usuarios externos |
| `leave_channel_on_buffer_close` | `on` | cerrar el buffer = salir del canal |
| `part_closes_buffer` | `off` | `/slack part` además cierra el buffer |
| `muted_conversations_notify` | `personal_highlights` | `none`, `personal_highlights`, `all_highlights`, `all` |
| `notify_subscribed_threads` | `auto` | `auto`, `unless_thread_buffer`, `always`, `never` |
| `render_emoji_as` | `emoji` | `emoji`, `name`, `both` |
| `render_url_as` | *(expresión)* | formato de los enlaces (se evalúa, `${url}` y `${text}`) |
| `replace_space_in_nicks_with` | `""` | sustituir espacios en los nicks |
| `typing_status_nicks` | `on` | ver quién está escribiendo |
| `typing_status_self` | `on` | que vean que escribes (requiere `typing.look.enabled_self`) |
| `workspace_buffer` | `merge_with_core` | dónde va el buffer del workspace |

Varias admiten excepción por buffer con `/buffer setvar <opción> <valor>`:
`display_reaction_nicks`, `display_thread_replies_in_channel`,
`auto_open_threads` y sus variantes.

### `slack.workspace.<nombre>.*` (y `slack.workspace_default.*`)

| Opción | Por defecto | Qué hace |
|---|---|---|
| `api_token` | `""` | el token (se evalúa; `${workspace}` = nombre del workspace) |
| `api_cookies` | `""` | las cookies (se evalúa igual) |
| `autoconnect` | `off` | conectar al arrancar WeeChat |
| `auto_open_threads` | `off` | abrir buffers de hilo automáticamente |
| `auto_open_threads_only_subscribed` | `on` | …solo los hilos suscritos |
| `auto_open_threads_only_unread` | `on` | …solo los no leídos |
| `auto_open_threads_only_if_replies_not_in_channel` | `on` | …solo si no se muestran en el canal |
| `keep_active` | `on_activity` | `on_activity` (activo al interactuar; Slack te pone ausente a los 30 min) o `always` |
| `network_timeout` | `30` | segundos de espera en las peticiones |
| `nick_source` | `display_name` | `display_name`, `real_name` o `username` |

Lo puesto en `workspace_default` sirve de valor base para todos los workspaces.

### `slack.color.*`

`buflist_muted_conversation` (darkgray), `channel_mention` (blue),
`deleted_message` (red), `disconnected` (red), `edited_message_suffix` (095),
`loading` (yellow), `message_join` (green), `message_quit` (red),
`reaction_suffix` (darkgray), `reaction_self_suffix` (blue), `render_error`
(red), `search_line_marked_bg` (17), `search_line_selected_bg` (24),
`search_marked` (brown), `search_marked_selected` (yellow), `user_mention`
(blue), `user_mention_nick_color` (off), `usergroup_mention` (blue).

## 10. Configuración aplicada

Estos son los cambios sobre los valores por defecto que aplica `install.sh` (y
que ya están puestos). Todos salen de `weechat/settings.conf` y
`weechat/default-channel.conf`, que es donde hay que editarlos:

| Ajuste | Valor | Por qué |
|---|---|---|
| `/key bind meta-g /go` | — | `Alt`+`g` abre el saltador de buffers; `go.py` no se asigna tecla solo |
| `weechat.look.mouse` | `on` | clic derecho sobre un mensaje pega su id |
| `weechat.bar.buflist.size_max` | `25` | los nombres largos de Slack no se comen la pantalla |
| `weechat.look.prefix_align_max` | `15` | igual, para los nicks largos |
| `weechat.bar.nicklist.hidden` | `on` | oculta la lista de integrantes del canal |
| `logger.file.auto_log` | `off` | no dejar las conversaciones en texto plano en el disco |
| barra `complist` | vertical, `size_max 12` | lista de completado, una opción por línea |
| `plugins.var.python.go.*` | ver §4 | nombres cortos, difuso, sin listar hasta el 2º carácter |
| `/key bind ctrl-g /go` | — | alternativa a `Alt`+`g` cuando Option no llega como Meta |
| `/key bind ctrl-v /buffer jump prev_visited` | — | volver atrás (salir de un hilo) sin depender de Alt |
| `slack.look.display_reaction_nicks` | `on` | ver quién ha reaccionado, como en Slack |
| trigger `slack_default_buffer` | `&equipo-privado` | salta a ese canal al arrancar |
| alias `/img`, `/gif`, `/imgurl` | — | ver imágenes y GIFs (ver §7 bis) |
| `Alt`+`i` / `Alt`+`o` | — | atajos de `/img 1` y `/gif 1` |
| `Ctrl`+clic / `Alt`+clic | — | abrir el hilo de un mensaje (ver §7) |

Revertir cualquiera de ellos: `/unset <opción>` (vuelve al valor por defecto),
`/key unbind meta-g` o `/trigger del slack_default_buffer`. Después, `/save`.

### Notificaciones del sistema (macOS)

No están instaladas por defecto. Con `./install.sh --notifications`, o a mano:

```
/script install notification_center.py
```

Requiere `pync` en el Python de WeeChat (el script lo instala).

## 11. Controlar WeeChat desde el shell (FIFO)

WeeChat expone un FIFO en `~/.cache/weechat/weechat_fifo_<pid>` con el que se le
pueden mandar comandos sin tocar el terminal donde corre. Es lo que usa
`install.sh` para configurarlo en caliente:

```bash
FIFO=~/.cache/weechat/weechat_fifo_$(pgrep -x weechat)
echo 'core.weechat */set slack.look.render_emoji_as both' > "$FIFO"
echo 'core.weechat */save' > "$FIFO"
```

El formato es `plugin.buffer *comando`. Sirve también para automatizar cosas
desde scripts o desde `cron`. Se desactiva con `/set fifo.file.enabled off`.

## 12. Mantenimiento

### Renovar el token o la cookie

Cuando dejen de funcionar (lo normal: cerraste sesión en el navegador):

1. https://my.slack.com/customize → consola →
   `window.prompt("Session token:", TS.boot_data.api_token)`
2. Application → Cookies → valor de `d`
3. `/set slack.workspace.miequipo.api_token …` y `…api_cookies d=…`
4. `/python reload slack`

### Actualizar wee-slack y los scripts

```bash
./install.sh --update
```

Recompila `slack.py` del último `master`, vuelve a bajar `go.py` y `url_hint.py`
y los recarga en la sesión viva.

### Actualizar WeeChat, chafa y demás

Las versiones están fijadas en `devbox.lock` y `nix/flake.lock`. Para moverlas:

```bash
devbox update                       # actualiza los paquetes de devbox.json
nix flake update --flake ./nix      # actualiza el nixpkgs del flake (WeeChat)
./install.sh                        # reaplica todo
```

Al ir fijadas, dos máquinas con el mismo commit del repositorio tienen
exactamente las mismas versiones. Nada de esto toca el sistema.

### Logs de conversaciones

WeeChat registra por defecto todas las conversaciones en texto plano, un fichero
por canal, en `~/.local/share/weechat/logs/`. Es contenido de la empresa sin
cifrar en el disco, así que **está desactivado** desde `weechat/settings.conf`:

```
/set logger.file.auto_log off
```

Los ficheros escritos antes de desactivarlo siguen ahí y hay que borrarlos a
mano:

```bash
rm -rf ~/.local/share/weechat/logs/
```

Si algún día quieres volver a registrar, pero solo algunos buffers:

```
/set logger.file.auto_log on
/set logger.level.python.slack 0     ...pero nada de Slack
/logger set 9                        ...salvo el buffer actual
```

### Desinstalar

```bash
# scripts y datos de WeeChat
rm -f ~/.local/share/weechat/python/{slack.py,go.py,url_hint.py} \
      ~/.local/share/weechat/python/autoload/{slack.py,go.py,url_hint.py} \
      ~/.local/share/weechat/weemoji.json
rm -f ~/.local/bin/weeslack

# configuración (¡lleva el token!)
rm -rf ~/.config/weechat ~/.local/share/weechat ~/.local/state/weechat ~/.cache/weechat

# el entorno del proyecto
rm -rf .devbox
nix store gc          # opcional: libera lo que ya no referencie nada
```

Nada de esto deja rastro en `/usr/local` ni en Homebrew, porque la instalación
no pasa por ahí.

## 13. Diagnóstico

- **El script no carga**: `/python list` debe mostrar `slack`. Los errores de
  carga salen en el buffer `core.weechat` y en
  `~/.local/state/weechat/weechat.log`.
- **`ModuleNotFoundError: websocket`**: la dependencia está en otro intérprete.
  Ver [Actualizar WeeChat](#actualizar-weechat).
- **No conecta**: `/slack debug errors` lista los errores capturados;
  `/slack debug error <id>` da el detalle y `-data` añade el JSON de la API.
  Lo más habitual es la cookie caducada.
- **`/slack debug open_buffer`**: buffer con el tráfico interno.
- **`/slack debug tasks`**: tareas y futures activos (si algo se queda colgado).
- **`ran slack`**: no es un error. `/slack` a secas ejecuta un `print` de
  depuración que quedó en el upstream (`slack/commands.py:195`).
- **Faltan mensajes antiguos en un canal**: `/slack rehistory`.
- **Un atajo con `Alt` no responde**: es la tecla Option de macOS, no WeeChat.
  Prueba `Esc` y luego la letra; ver §4.
- **`weechat` a secas no carga wee-slack**: estás arrancando otro WeeChat del
  PATH, sin `websocket-client` en su Python. Usa `weeslack`.
- **`devbox run -- weechat` hace algo raro**: `devbox run` resuelve antes los
  scripts de `devbox.json` que los binarios. Por eso el script se llama `start`.

## 14. Diferencias con el README oficial

El README de `master` documenta cosas de la v2 que **no existen** en la v3
instalada:

- `/slack register` y el flujo OAuth con la página de GitHub Pages — no hay
  comando `register`; los tokens se ponen con `/set slack.workspace.<n>.api_token`
  o con `/slack workspace add <n> -api_token=…`.
- `/label`, para renombrar buffers de hilo.
- `/slack help` — usa `/help slack`.
- `docs/Commands.md` y `docs/Options.md` — no están en el repo.
- Las opciones de depuración `plugins.var.python.slack.debug_mode`,
  `debug_level`, `record_events` y `background_load_all_history` — sustituidas
  por `/slack debug`.
- Descargar `wee_slack.py` de `master` — ese fichero ya no existe; hay que
  compilar con `build.sh`.
- Las instrucciones de dependencias por distribución (`apt install
  python3-websocket`, `python3 -m pip install websocket-client`…): aquí eso lo
  resuelve el flake, que mete el paquete en el propio Python del plugin.
