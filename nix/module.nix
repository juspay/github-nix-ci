{ pkgs, lib, config, ... }:

let
  inherit (pkgs.stdenv) isLinux;

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

  # Create 'num' runners for the given GitHub org
  mkOrgRunners = { orgName, num }:
    lib.listToAttrs (for (range num)
      (n: {
        name = "${host}-${orgName}-${paddedNum n}";
        value = common // {
          tokenFile = config.age.secrets."github-runner-tokens/${orgName}".path;
          url = "https://github.com/${orgName}";
        };
      })
    );

  # Like mkOrgRunner but for personal repos
  mkPersonalRunners = { user, repo, num ? 1 }:
    lib.listToAttrs (for (range num)
      (n: {
        name = "${host}-${user}-${repo}-${paddedNum n}";
        value = common // {
          tokenFile = config.age.secrets."github-runner-tokens/${user}".path;
          url = "https://github.com/${user}/${repo}";
        };
      })
    );
in
{
  options = { };
  config = {
    # Each org gets its own set of runners. There will be at max `num` parallels
    # CI builds for this org / host combination.
    services.github-runners = lib.mkMerge [
      # Example: org runners
      # (mkOrgRunners { orgName = "juspay"; num = 10; })
      # Example: personal runners
      # (mkPersonalRunners { user = "srid"; repo = "emanote"; })
    ];

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
