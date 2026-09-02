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

        default = weechat-slack;
      });
    };
}
