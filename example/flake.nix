{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nix-darwin.url = "github:LnL7/nix-darwin";
    ragenix.url = "github:yaxitech/ragenix";
    github-nix-ci = { };
  };
  outputs = inputs: {
    nixosModules.my-github-runners = {
      services.github-nix-ci = {
        age.secretsDir = ./secrets;
        personalRunners = {
          "srid/nixos-config".num = 1;
          "srid/haskell-flake".num = 3;
        };
        orgRunners = {
          "zed-industries".num = 10;
        };
      };
    };

    nixosConfigurations.example = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.ragenix.nixosModules.default
        inputs.github-nix-ci.nixosModules.default
        inputs.self.nixosModules.my-github-runners
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          fileSystems."/" = { device = "/dev/sda"; fsType = "ext"; };
          boot.loader = {
            systemd-boot.enable = true;
            efi.canTouchEfiVariables = true;
          };
          services.openssh.enable = true;
          system.stateVersion = "24.05";
        }
      ];
    };

    darwinConfigurations.example = inputs.nix-darwin.lib.darwinSystem {
      modules = [
        inputs.ragenix.darwinModules.default
        inputs.github-nix-ci.darwinModules.default
        inputs.self.nixosModules.my-github-runners
        {
          nixpkgs.hostPlatform = "aarch64-darwin";
          networking.hostName = "example";
          services.nix-daemon.enable = true;
        }
      ];
    };
  };
}
