# github-nix-ci

`github-nix-ci` is simple NixOS &amp; nix-darwin module for managing and running [self-hosted GitHub runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners) on your machines, so as to provide CI for both personal and organization-wide repositories on GitHub.

>[!WARNING]
> Work in progress. Do not use *yet*.

## What it does

We provide a [NixOS][nixos] and [nix-darwin] module that can be imported and utilized as easily as:

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

Activate your configuration spins the required GitHub runners, with appropriate labels (Nix `system` string).

In conjunction with [nixci], your CI workflow file can be as simple as follows, in order to schedule jobs on these runners (by using the same `system` string label):

```yaml
jobs:
  nix:
    runs-on: ${{ matrix.system }}
    strategy:
      matrix:
        system: [aarch64-darwin, x86_64-darwin, x86_64-linux]
      fail-fast: false
    steps:
      - uses: actions/checkout@v4
      - name: nixci
        run: nixci build --systems "github:nix-systems/${{ matrix.system }}"
```

## Getting Starrted

TODO


## Tips

### Matrix builds

[nixci]: https://github.com/srid/nixci
[nix-darwin]: https://nixos.asia/en/nix-darwin
[nixos]: https://nixos.asia/en/nixos