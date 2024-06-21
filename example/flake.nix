{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nix-darwin.url = "github:LnL7/nix-darwin";
    ragenix.url = "github:yaxitech/ragenix";
    github-nix-ci = { };
  };
  outputs = inputs: {
    nixosConfigurations.example = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.ragenix.nixosModules.default
        inputs.github-nix-ci.nixosModules.default
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          fileSystems."/" = { device = "/dev/sda"; fsType = "ext"; };
          boot.loader = {
            systemd-boot.enable = true;
            efi.canTouchEfiVariables = true;
          };
          system.stateVersion = "24.05";
        }
      ];
    };

    darwinConfigurations.example = inputs.nix-darwin.lib.darwinSystem {
      modules = [
        inputs.ragenix.darwinModules.default
        inputs.github-nix-ci.darwinModules.default
        {
          nixpkgs.hostPlatform = "aarch64-darwin";
          # TODO: Add this, and add fake ssh keys for agenix to work during nix build.
          #github-nix-ci = {
          #  orgRunners.juspay.num = 2;
          #};
          services.nix-daemon.enable = true;
        }
      ];
    };
  };
}
