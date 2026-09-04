{
  description = "WeeChat preparado para wee-slack: el Python del plugin lleva websocket-client";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        # wee-slack necesita que websocket-client sea importable desde el
        # intérprete que embebe el plugin python de WeeChat. Con un gestor de
        # paquetes del sistema esto obliga a adivinar contra qué Python se
        # enlazó y a saltarse PEP 668; aquí se declara y ya está.
        weechat-slack = pkgs.weechat.override {
          configure = { availablePlugins, ... }: {
            plugins = with availablePlugins; [
              (python.withPackages (ps: with ps; [ websocket-client ]))
            ];
          };
        };

        # Opcional: no está en devbox.json, así que quien clone el repo no se lo
        # encuentra. Se usa a demanda con `nix run ./nix#slack-tui`, o se activa
        # por máquina con ORCASO_SLACK=tui en weechat/local.env.
        mkSlackTui = { suffix, patches }: pkgs.buildGoModule {
          pname = "slack-tui";
          version = "0.6.1${suffix}";
          src = pkgs.fetchFromGitHub {
            owner = "kurenn";
            repo = "slack-tui";
            rev = "dd5b82492c5b42e0248f6918b4b080d9ad4190e0";
            hash = "sha256-APhxsJq4Ot6JCHOKyOtOZ79NQECjlAjX/Vx1u1EvOI8=";
          };
          vendorHash = "sha256-TyJEJujiciHHAUbcHQIsG1vc7sPqlVL8lcBOZDniRvM=";
          inherit patches;
          ldflags = [ "-s" "-w" "-X" "main.version=0.6.1${suffix}" ];
          meta.mainProgram = "slack-tui";
        };

        # Parcheado: al arrancar, el upstream recorre conversations.list entero
        # (todo el workspace) para quedarse solo con tus canales, lo que en un
        # Slack de empresa son minutos de paginación y 429. Ver nix/patches/.
        slack-tui = mkSlackTui {
          suffix = "-orcaso";
          patches = [
            ./patches/0001-source-list-conversations-with-users.conversations.patch
            ./patches/0002-prefs-add-default_channel.patch
          ];
        };

        # El mismo commit sin tocar, para comparar. Ojo: en un workspace grande
        # tarda minutos en arrancar, que es justo lo que arregla el parche.
        slack-tui-upstream = mkSlackTui { suffix = "-upstream"; patches = [ ]; };

        # fang: gestor de ficheros TUI (Rust). Otra cosa más que deja de
        # obligarte a salir de Orca.
        fang = pkgs.rustPlatform.buildRustPackage {
          pname = "fang";
          version = "1.0.0";
          src = pkgs.fetchFromGitHub {
            owner = "theburrowhub";
            repo = "fang";
            rev = "8a25e6b4567c9cde1f17b78e81e5bbc236d714af";
            hash = "sha256-l88hyBzj0WN47CLkp3zbkWDqdWpxgFeonCYsTmI3G8c=";
          };
          # El repositorio no publica Cargo.lock, así que se genera una vez y
          # se versiona aquí: fija las 263 dependencias transitivas en lugar de
          # resolverlas de nuevo en cada máquina.
          cargoLock.lockFile = ./fang-Cargo.lock;
          postPatch = "cp ${./fang-Cargo.lock} Cargo.lock";
          meta.mainProgram = "fang";
        };

        default = weechat-slack;
      });
    };
}
