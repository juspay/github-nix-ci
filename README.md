# github-nix-ci

`github-nix-ci` is simple NixOS &amp; nix-darwin module for managing and running [self-hosted GitHub runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners) on your machines, so as to provide CI for both personal and organization-wide repositories on GitHub.

>[!WARNING]
> Work in progress. Do not use *yet*.

## What it does

We provide a [NixOS][nixos] and [nix-darwin] module[^wrap] that can be imported and utilized as easily as:

```nix
{
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
}
```

Activating this configuration spins up the required GitHub runners, with appropriate [labels][label] (hostname and Nix [system]s).

In conjunction with [nixci] (which is installed in the runners by default), your CI workflow file can be as simple as follows - for scheduling jobs on these runners (by using the same [system] string label for example):

```yaml
jobs:
  nix:
    runs-on: ${{ matrix.system }}
    strategy:
      matrix:
        system: [aarch64-darwin, x86_64-darwin, x86_64-linux]
    steps:
      - uses: actions/checkout@v4
      - run: nixci build --systems "github:nix-systems/${{ matrix.system }}"
```

## Getting Starrted

TODO


## Tips

### Matrix builds

[nixci]: https://github.com/srid/nixci
[nix-darwin]: https://nixos.asia/en/nix-darwin
[nixos]: https://nixos.asia/en/nixos
[label]: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/using-labels-with-self-hosted-runners
[system]: https://flake.parts/system

[^wrap]: Our module wraps the upstream [NixOS](https://github.com/NixOS/nixpkgs/tree/master/pkgs/development/tools/continuous-integration/github-runner) and [nix-darwin](https://github.com/LnL7/nix-darwin/tree/master/modules/services/github-runner) modules, whilst providing a platform-independent module interface, in addition to wiring up anything else required (users, secrets) to get going easily.