# github-nix-ci

`github-nix-ci` is a simple NixOS &amp; nix-darwin module for [self-hosting GitHub runners][gh-runner] on your machines (which could be a remote server or your personal macbook), so as to provide self-hosted CI for both personal and organization-wide repositories on GitHub.

- [github-nix-ci](#github-nix-ci)
  - [What it does](#what-it-does)
  - [Getting Started](#getting-started)
    - [1. Create system configuration for the machine](#1-create-system-configuration-for-the-machine)
      - [New configuration](#new-configuration)
      - [Existing configuration](#existing-configuration)
    - [2. Create personal access tokens](#2-create-personal-access-tokens)
      - [Add tokens to your configuration using `agenix`](#add-tokens-to-your-configuration-using-agenix)
    - [3. Configure `github-nix-ci` runners](#3-configure-github-nix-ci-runners)
    - [4. Add the workflow to your repositories](#4-add-the-workflow-to-your-repositories)
  - [Examples](#examples)
  - [Tips](#tips)
    - [Matrix builds](#matrix-builds)


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

## Getting Started

Repurposing an existing machine for running [self-hosted GitHub runners][gh-runner] involves the following steps.

### 1. Create system configuration for the machine

#### New configuration

If you do not already have a NixOS (for Linux) or nix-darwin (for macOS) system configuration, begin with [the templates](https://community.flake.parts/nixos-flake/templates) provided by `nixos-flake`. Alternatively, you may start from the minimal example ([`./example`](./example)) in this repo. If you use both the platforms, you can keep them in a single flake as the aforementioned example demonstrates.

>[!TIP]
> If you use `nixos-flake`, activating the configuration is as simple as running `nix run .#activate` (if done locally) or [`nix run .#deploy`](https://github.com/srid/nixos-flake/pull/54) if done remotely.


#### Existing configuration

If you already have a NixOS or nix-darwin system configuration, you can use `github-nix-ci` as follows:

1. Switch your configuration to [using flakes](https://nixos.asia/en/configuration-as-flake) and thereon to using [flake-parts]
1. Add this repo as a flake input
1. Add `inputs.github-nix-ci.nixosModules.default` (if NixOS) or `inputs.github-nix-ci.darwinModules.default` (if macOS/nix-darwin) to the `imports` of your top-level flake-parts module.

Test that everything is okay by activating your configuration.

### 2. Create personal access tokens

For our runners to be able to authorize against GitHub, we need to create **fine-grained personal access tokens** (PAC) for each user and organization. 

1. Go to https://github.com/settings/personal-access-tokens/new
1. Create a fine-grained PAC
    - Under **Resource owner**, choose the user or organization for whose repositories your runners will be building the CI for.
    - Under **Repository access**, choose the appropriate option based on your needs
    - Setup the necessary permissions
        - If the token is for a personal account, under **Permissions -> Repository permissions**, set *Administration* to "Read and write"
        - If the token is for an organization, under **Permissions -> Organization permissions**, set _Self-hosted runners_ to "Read and write"

#### Add tokens to your configuration using `agenix`

>[!TIP]
> Follow [the agenix tutorial](https://github.com/ryantm/agenix?tab=readme-ov-file#tutorial) for details. [This PR](https://github.com/srid/nixos-config/pull/57) in `srid/nixos-config` can also be used as reference.

1. Create a `./secrets/secrets.nix` containing the SSH keys of yourself and the machines, as well as the list of token `.age` files (see next point). See [`./example/secrets/secrets.nix`](https://github.com/juspay/github-nix-ci/blob/main/example/secrets/secrets.nix) for reference.
2. Create a `.age` file for each PAC secret you created in the previous section
   - Run `agenix -e secrets/github-nix-ci/NAME.token.age` where `NAME` is the name of the github user or the organization the PAC is associated with, and then paste your token secret in it, saving the file. 

### 3. Configure `github-nix-ci` runners

Now that you have set everything up, it is time to configure the runners themselves. For both NixOS and nix-darwin, you can add the following configuration:

```nix
services.github-nix-ci = {
  age.secretsDir = ./secrets;
  personalRunners = {
    "srid/emanote".num = 1;
    "srid/haskell-flake".num = 3;
  };
  orgRunners = {
    "zed-industries".num = 10;
  };
};
```

The above configuration adds 3 sets of GitHub runner daemons. Two of them are associated with the personal repos, whereas the 3rd set is associated with the organization (and thus *any* repository under that organization). The `num` property will spin-up that many runners for the associated repo or organization. Setting a `num` value that is greater than `1` enables you to run actions in parallel (upto the value of `num`).

Activate your configuration, and visit **Settings -> Actions -> Runners** page of your repository or organization settings to confirm that the runners are ready and healthy.

### 4. Add the workflow to your repositories

Finally, you are equipped to add an [actions workflow file](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions) to one of the repositories to test everything out. Here's an example if you have configured both NixOS and macOS runners:

```yaml
-- ./.github/workflows/nix.yaml
name: "CI"
on:
  push:
    branches:
      - master
  pull_request:
jobs:
  nix:
    runs-on: ${{ matrix.system }}
    strategy:
      matrix:
        system: [aarch64-darwin, x86_64-linux]
      fail-fast: false
    steps:
      - uses: actions/checkout@v4
      - name: nixci
        run: nixci --extra-access-tokens "github.com=${{ secrets.GITHUB_TOKEN }}" build --systems "${{ matrix.system }}"
```

## Examples

- [`./example`](./example)
- [`srid/nixos-config`](https://github.com/srid/nixos-config/pull/60)

## Tips

### Matrix builds

TODO

[nixci]: https://github.com/srid/nixci
[nix-darwin]: https://nixos.asia/en/nix-darwin
[nixos]: https://nixos.asia/en/nixos
[label]: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/using-labels-with-self-hosted-runners
[system]: https://flake.parts/system
[gh-runner]: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners
[pac]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token
[ragenix]: https://github.com/yaxitech/ragenix
[flake-parts]: https://nixos.asia/en/flake-parts

[^wrap]: Our module wraps the upstream [NixOS](https://github.com/NixOS/nixpkgs/tree/master/pkgs/development/tools/continuous-integration/github-runner) and [nix-darwin](https://github.com/LnL7/nix-darwin/tree/master/modules/services/github-runner) modules, whilst providing a platform-independent module interface, in addition to wiring up anything else required (users, secrets) to get going easily.