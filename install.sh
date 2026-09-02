#!/usr/bin/env bash
#
# Instala y configura WeeChat + wee-slack. Todas las dependencias vienen de
# devbox/Nix, fijadas en devbox.lock y nix/flake.lock: nada se instala en el
# sistema salvo el propio devbox.
#
#   ./install.sh                  instala todo y aplica la configuración
#   ./install.sh --update         actualiza wee-slack y los scripts, y recarga
#   ./install.sh --no-config      instala sin tocar la configuración de WeeChat
#   ./install.sh --no-token       no pregunta por el token de Slack
#   ./install.sh --no-project     no monta las pestañas del proyecto en Orca
#   ./install.sh --default-channel '#otro'   canal al que saltar al arrancar
#   ./install.sh --no-default-channel
#   ./install.sh --workspace otro
#
# Totalmente desatendido:
#   SLACK_WORKSPACE=miequipo SLACK_TOKEN=xoxc-... SLACK_COOKIE='d=xoxd-...' ./install.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ajustes de esta máquina, fuera del control de versiones. Usa la forma
# ': "${VAR:=valor}"', así que lo que ya venga del entorno manda sobre el
# fichero, y las opciones de la línea de comandos mandan sobre ambos.
# Ver weechat/local.env.example.
if [ -f "$REPO_DIR/weechat/local.env" ]; then
  # shellcheck source=/dev/null
  . "$REPO_DIR/weechat/local.env"
fi

WORKSPACE="${SLACK_WORKSPACE:-miequipo}"
# Canal al que saltar al arrancar. Prefijo: '#' público, '&' privado, '@' grupo.
DEFAULT_CHANNEL="${SLACK_DEFAULT_CHANNEL:-&equipo-privado}"
DO_CONFIG=1
DO_TOKEN=1
DO_PROJECT=1
UPDATE_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --update)             UPDATE_ONLY=1 ;;
    --no-config)          DO_CONFIG=0 ;;
    --no-token)           DO_TOKEN=0 ;;
    --no-project)         DO_PROJECT=0 ;;
    --workspace)          WORKSPACE="$2"; shift ;;
    --default-channel)    DEFAULT_CHANNEL="$2"; shift ;;
    --no-default-channel) DEFAULT_CHANNEL="" ;;
    -h|--help)            sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)                    echo "Opción desconocida: $1" >&2; exit 1 ;;
  esac
  shift
done

WEE_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/weechat"
WEE_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/weechat"
PY_DIR="$WEE_DATA/python"
SRC_DIR="${TMPDIR:-/tmp}/wee-slack-src"
LAUNCHER_DIR="$HOME/.local/bin"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$1" >&2; exit 1; }

# Todo lo que necesite herramientas (weechat, chafa, git, curl, perl) pasa por
# aquí, para que salgan del entorno de devbox y no del sistema.
dbx() { devbox run -q -c "$REPO_DIR" -- "$@"; }

# ----------------------------------------------------------------- 1. devbox
install_devbox() {
  if command -v devbox >/dev/null 2>&1; then
    log "devbox ya instalado ($(devbox version 2>/dev/null | tail -1))"
    return
  fi
  log "Instalando devbox (instalará Nix si hace falta)…"
  curl -fsSL https://get.jetify.com/devbox | bash
  command -v devbox >/dev/null 2>&1 || {
    export PATH="/usr/local/bin:$PATH"
    command -v devbox >/dev/null 2>&1 || die "devbox no quedó en el PATH; abre una terminal nueva y reintenta"
  }
}

# ------------------------------------------- 2. dependencias fijadas por Nix
#    weechat viene de nix/flake.nix con websocket-client dentro del Python que
#    embebe su plugin: es la dependencia que un gestor del sistema obliga a
#    resolver a mano adivinando el intérprete.
install_deps() {
  log "Resolviendo dependencias con devbox…"
  (cd "$REPO_DIR" && devbox install)
  log "WeeChat $(dbx weechat --version) · chafa $(dbx chafa --version | head -1 | awk '{print $3}')"
}

# ------------------------------------------------------- 3. wee-slack (build)
#    master no publica un slack.py compilado: se genera con su build.sh.
install_weeslack() {
  log "Obteniendo wee-slack…"
  if [ -d "$SRC_DIR/.git" ]; then
    dbx git -C "$SRC_DIR" fetch --depth 1 origin master -q
    dbx git -C "$SRC_DIR" reset --hard origin/master -q
  else
    rm -rf "$SRC_DIR"
    dbx git clone --depth 1 -q https://github.com/wee-slack/wee-slack.git "$SRC_DIR"
  fi

  log "Compilando slack.py ($(dbx git -C "$SRC_DIR" rev-parse --short HEAD))…"
  dbx bash -c "cd '$SRC_DIR' && bash build.sh"
  [ -f "$SRC_DIR/build/slack.py" ] || die "build.sh no generó build/slack.py"

  mkdir -p "$PY_DIR/autoload"
  install -m 644 "$SRC_DIR/build/slack.py" "$PY_DIR/slack.py"
  install -m 644 "$SRC_DIR/weemoji.json"   "$WEE_DATA/weemoji.json"
  ln -sf ../slack.py "$PY_DIR/autoload/slack.py"
  log "wee-slack instalado en $PY_DIR/slack.py"
}

# --------------------------------------------- 4. scripts auxiliares de WeeChat
#    go.py      : saltar a un buffer por nombre (Ctrl+g)
#    url_hint.py: numera las URLs del buffer (¹²³) para abrirlas por teclado
install_scripts() {
  log "Instalando go.py y url_hint.py…"
  mkdir -p "$PY_DIR/autoload"
  for script in go.py url_hint.py; do
    dbx curl -fsSL -o "$PY_DIR/$script" "https://weechat.org/files/scripts/$script"
    ln -sf "../$script" "$PY_DIR/autoload/$script"
  done
}

# ---------------------------------------------------------------- 5. lanzador
#    Para no tener que acordarse de 'devbox run -c <repo> weechat'.
install_launcher() {
  mkdir -p "$LAUNCHER_DIR"
  ln -sf "$REPO_DIR/bin/weeslack" "$LAUNCHER_DIR/weeslack"
  case ":$PATH:" in
    *":$LAUNCHER_DIR:"*) log "Lanzador: weeslack" ;;
    *) warn "Añade $LAUNCHER_DIR al PATH para poder escribir solo 'weeslack'" ;;
  esac
}

# ------------------------------------------------------------ 6. configuración
#    Si WeeChat está corriendo se le habla por su FIFO (no pierdes la sesión);
#    si no, se arranca en modo efímero para aplicar los comandos y salir.
wee_run() {
  local pid fifo
  pid="$(pgrep -x weechat | head -1 || true)"
  fifo="$WEE_CACHE/weechat_fifo_${pid}"

  if [ -n "$pid" ] && [ -p "$fifo" ]; then
    while IFS= read -r cmd; do
      [ -n "$cmd" ] || continue
      printf 'core.weechat *%s\n' "$cmd" > "$fifo"
      sleep 0.3
    done
    printf 'core.weechat */save\n' > "$fifo"
  else
    local joined=""
    while IFS= read -r cmd; do
      [ -n "$cmd" ] || continue
      joined="${joined}${cmd};"
    done
    TERM=xterm-256color script -q /dev/null \
      devbox run -q -c "$REPO_DIR" -- weechat -r "${joined}/save;/wait 2 /quit" >/dev/null 2>&1 || true
  fi
}

# La configuración no vive en este script sino en weechat/*.conf, para poder
# revisarla en un diff. Aquí solo se sustituyen los marcadores.
# Se usa perl porque tanto sed como la expansión de bash 5.2+ tratan '&' en el
# reemplazo como "el texto encontrado", y los canales privados empiezan por '&'.
apply_settings_file() {
  local file="$1"
  [ -f "$file" ] || die "No existe el fichero de configuración: $file"
  REPO_DIR="$REPO_DIR" WORKSPACE="$WORKSPACE" DEFAULT_CHANNEL="$DEFAULT_CHANNEL" \
    perl -pe 's/\@REPO\@/$ENV{REPO_DIR}/g;
              s/\@WORKSPACE\@/$ENV{WORKSPACE}/g;
              s/\@CHANNEL\@/$ENV{DEFAULT_CHANNEL}/g;' "$file" \
    | grep -vE '^[[:space:]]*(#|$)' \
    | wee_run
}

configure() {
  log "Aplicando configuración de WeeChat (weechat/settings.conf)…"
  apply_settings_file "$REPO_DIR/weechat/settings.conf"

  if [ -n "$DEFAULT_CHANNEL" ]; then
    log "Canal por defecto: $DEFAULT_CHANNEL"
    apply_settings_file "$REPO_DIR/weechat/default-channel.conf"
  fi
}

configure_token() {
  local token="${SLACK_TOKEN:-}" cookie="${SLACK_COOKIE:-}"

  if [ -z "$token" ]; then
    if [ ! -t 0 ]; then warn "Sin SLACK_TOKEN y sin terminal interactiva: omito el token"; return; fi
    cat <<'EOF'

Para obtener el token de sesión:
  1. Abre https://my.slack.com/customize y comprueba que es el workspace correcto
  2. Consola del navegador (Cmd+Opt+J) y ejecuta:
       window.prompt("Session token:", TS.boot_data.api_token)
  3. Application/Storage -> Cookies -> copia el valor de la cookie 'd'

EOF
    read -r -p "Token (xoxc-…, vacío para omitir): " token
    [ -n "$token" ] || { warn "Token omitido"; return; }
    read -r -p "Cookie d (solo el valor): " cookie
  fi
  case "$cookie" in d=*) : ;; *) cookie="d=$cookie" ;; esac

  log "Registrando el workspace '$WORKSPACE'…"
  wee_run <<CMDS
/slack workspace add $WORKSPACE
/set slack.workspace.$WORKSPACE.api_token $token
/set slack.workspace.$WORKSPACE.api_cookies $cookie
/set slack.workspace.$WORKSPACE.autoconnect on
CMDS
}

reload_scripts() {
  log "Recargando scripts…"
  wee_run <<'CMDS'
/python reload slack
CMDS
}

# ---------------------------------------------------------------------- main
install_devbox

if [ "$UPDATE_ONLY" -eq 1 ]; then
  install_deps
  install_weeslack
  install_scripts
  reload_scripts
  log "Actualizado. Si WeeChat no estaba abierto, los cambios se aplican al arrancarlo."
  exit 0
fi

install_deps
install_weeslack
install_scripts
install_launcher
if [ "$DO_CONFIG" -eq 1 ]; then
  configure
  [ "$DO_TOKEN" -eq 1 ] && configure_token
  reload_scripts
fi

# Pestañas del proyecto en Orca: el CLI de IA y Slack.
if [ "$DO_PROJECT" -eq 1 ] && command -v orca >/dev/null 2>&1; then
  "$REPO_DIR/bin/orcaso-project" || warn "No pude montar las pestañas en Orca"
fi

cat <<EOF

$(log "Listo.")
  Arranca con:      weeslack       (o: devbox run -c "$REPO_DIR" start)
  Saltar de canal:  Ctrl+g
  Manual:           $REPO_DIR/MANUAL.md
EOF
