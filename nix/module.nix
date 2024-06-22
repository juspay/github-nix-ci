top@{ pkgs, lib, config, ... }:

let
  inherit (pkgs.stdenv) isLinux;
  inherit (lib) types;

  # TODO: fail if not set
  host = builtins.toString config.networking.hostName;
  # The list of systems that this host can build for.
  # cf. https://stackoverflow.com/q/78649070/55246
  supportedSystems =
    let
      extra-systems =
        if lib.hasAttr "extra-platforms" config.nix.settings
        then lib.strings.splitString " " config.nix.settings.extra-platforms
        else [ ];
      host-system = config.nixpkgs.hostPlatform.system;
    in
    lib.unique ([ host-system ] ++ extra-systems);
  for = lib.flip builtins.map;
  forAttr = lib.flip lib.mapAttrsToList;
  # For input n, return [1..n]
  range =
    lib.genList (i: i + 1);
  # Poor man's zero-padding for numbers upto 99.
  paddedNum = n:
    if n < 10 then "0${builtins.toString n}" else builtins.toString n;

  # Labels for our runners (used to select them in workflows)
  #
  # The following labels are use:
  # - Hostname of the runner
  # - Nix systems it can build for.
  #
  # In workflow file, we expect the user to use the Nix system as label usually.
  extraLabels = [ host ] ++ supportedSystems;

  # Packages that will be made available to all runners.
  extraPackages =
    let
      # https://github.com/actions/upload-pages-artifact/blob/56afc609e74202658d3ffba0e8f6dda462b719fa/action.yml#L40
      gtar = pkgs.runCommandNoCC "gtar" { } ''
        mkdir -p $out/bin
        ln -s ${lib.getExe pkgs.gnutar} $out/bin/gtar
      '';
    in
    with pkgs; [
      # For nix builds
      nix
      nixci

      # Tools already available in standard GitHub Runners; so we provide
      # them here:
      coreutils
      which
      jq

      # Used in well-known GitHub Action workflows
      gtar
    ];

  # Runner configuration
  common = {
    inherit extraLabels extraPackages;
    enable = true;
    replace = true;
    ephemeral = true;
    noDefaultLabels = true;
  } // lib.optionalAttrs isLinux { inherit user group; };
  user = "github-runner";
  group = "github-runner";

in
{
  options = {
    services.github-nix-ci = lib.mkOption {
      type = types.submodule {
        options = {
          orgRunners = lib.mkOption {
            type = types.attrsOf (types.submodule ({ config, name, ... }: {
              options = {
                num = lib.mkOption {
                  type = types.int;
                };

                output.name = lib.mkOption {
                  type = types.str;
                  default = "${host}-${name}-${paddedNum config.num}";
                };
                output.runner = lib.mkOption {
                  type = types.raw;
                  default = common // {
                    tokenFile = top.config.age.secrets."github-nix-ci/${name}.token.age".path;
                    url = "https://github.com/${name}";
                  };
                };
              };
            }));
            default = { };
          };

          personalRunners = lib.mkOption {
            type = types.attrsOf (types.submodule ({ config, name, ... }: {
              options = {
                num = lib.mkOption {
                  type = types.int;
                };

                output.user = lib.mkOption {
                  type = types.str;
                  default =
                    let parts = lib.splitString "/" name;
                    in if lib.length parts == 2 then builtins.elemAt parts 0 else builtins.abort "Invalid user/repo";
                };
                output.repo = lib.mkOption {
                  type = types.str;
                  default =
                    let parts = lib.splitString "/" name;
                    in if lib.length parts == 2 then builtins.elemAt parts 1 else builtins.abort "Invalid user/repo";
                };

                output.name = lib.mkOption {
                  type = types.str;
                  default = "${host}-${config.output.user}-${config.output.repo}-${paddedNum config.num}";
                };
                output.runner = lib.mkOption {
                  type = types.raw;
                  default = common // {
                    tokenFile = top.config.age.secrets."github-nix-ci/${config.output.user}.token.age".path;
                    url = "https://github.com/${config.output.user}/${config.output.repo}";
                  };
                };
              };
            }));
            default = { };
          };
        };
      };
      default = { };
    };
  };
  config = {
    # Each org gets its own set of runners. There will be at max `num` parallels
    # CI builds for this org / host combination.
    services.github-runners = lib.listToAttrs
      (forAttr config.services.github-nix-ci.orgRunners
        (name: cfg:
          lib.nameValuePair cfg.output.name cfg.output.runner)
      ++
      forAttr config.services.github-nix-ci.personalRunners (name: cfg:
        lib.nameValuePair cfg.output.name cfg.output.runner)
      );

    # User (Linux only)
    users.users.${user} = lib.mkIf isLinux {
      inherit group;
      isSystemUser = true;
    };
    users.groups.${group} = lib.mkIf isLinux { };
    nix.settings.trusted-users = [
      (if isLinux then user else "_github-runner")
    ];
  };
}
