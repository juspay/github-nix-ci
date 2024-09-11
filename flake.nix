{
  outputs = _: {
    nixosModules.default = ./nix/module.nix;
    darwinModules.default = ./nix/module.nix;

    # https://omnix.page/om/ci.html
    om.ci.default =
      let
        overrideInputs.github-nix-ci = ./.;
      in
      {
        example = {
          inherit overrideInputs;
          dir = "example";
        };
        dev = {
          inherit overrideInputs;
          dir = "dev";
        };
      };
  };
}
