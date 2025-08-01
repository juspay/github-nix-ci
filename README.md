[![project chat](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://nixos.zulipchat.com/register/)

# github-nix-ci

`github-nix-ci` is a simple NixOS &amp; nix-darwin module (wrapping[^wrap] the ones in nixpkgs and nix-darwin) for [self-hosting GitHub runners][gh-runner] on your machines (which could be a remote server or your personal macbook), so as to provide self-hosted CI for both personal and organization-wide repositories on GitHub.

- [What it does](#what-it-does)
- [Getting Started](#getting-started)
  - [1. Create system configuration for the machine](#1-create-system-configuration-for-the-machine)
  - [2. Create personal access tokens](#2-create-personal-access-tokens)
  - [3. Configure `github-nix-ci` runners](#3-configure-github-nix-ci-runners)
  - [4. Add the workflow to your repositories](#4-add-the-workflow-to-your-repositories)
- [Production](#production)
  - [Common issues](#common-issues)
- [Examples](#examples)


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

In conjunction with [nixci] (which is installed in the runners by default), your GitHub Actions workflow YAML can be as simple as follows in order to run CI, on your own machines, for your Nix flakes based projects:

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

If you do not already have a NixOS (for Linux) or nix-darwin (for macOS) system configuration, begin with [the templates](https://community.flake.parts/nixos-flake/templates) provided by `nixos-flake`. Alternatively, you may start from the minimal example ([`./example`](./example/flake.nix)) in this repo. If you use both the platforms, you can keep them in a single flake as the aforementioned example demonstrates.

>[!TIP]
> If you use `nixos-flake`, activating the configuration is as simple as running `nix run .#activate` (if done locally) or [`nix run .#deploy`](https://github.com/srid/nixos-flake/pull/54) if done remotely.


#### Existing configuration

If you already have a NixOS or nix-darwin system configuration, you can use `github-nix-ci` as follows:

1. Switch your configuration to [using flakes](https://nixos.asia/en/configuration-as-flake), if not already.[^non-flake]
1. Add this repo as a flake input
1. Add `inputs.github-nix-ci.nixosModules.default` (if NixOS) or `inputs.github-nix-ci.darwinModules.default` (if macOS/nix-darwin) to the `modules` list of your top-level system configuration.

[^non-flake]: Non-flake users too can use this module by using [`fetchGit`](https://noogle.dev/f/builtins/fetchGit) or the like.

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
            - Don't forget to "Allow public repositories" under "Actions -> Runner groups -> Default" ([ref](https://stackoverflow.com/a/77415170)).

#### Add tokens to your configuration using `agenix`

>[!TIP]
> Follow [the agenix tutorial](https://github.com/ryantm/agenix?tab=readme-ov-file#tutorial) for details. [This PR](https://github.com/srid/nixos-config/pull/57) in `srid/nixos-config` can also be used as reference. 

> [!NOTE]
> This module does not *mandate* the use of `agenix`. If you use something else other than `agenix` for secrets management, set the `tokenFile` option manually.

1. Create a `./secrets/secrets.nix` containing the SSH keys of yourself and the machines, as well as the list of token `.age` files (see next point). See [`./example/secrets/secrets.nix`](https://github.com/juspay/github-nix-ci/blob/main/example/secrets/secrets.nix) for reference.
2. Create a `.age` file for each PAC secret you created in the previous section
   - Run `agenix -e secrets/github-nix-ci/NAME.token.age` where `NAME` is the name of the github user or the organization the PAC is associated with, and then paste your token secret in it, saving the file. 

### 3. Configure `github-nix-ci` runners

Now that you have set everything up, it is time to configure the runners themselves. For both NixOS and nix-darwin, you can add the following configuration:

```nix
services.github-nix-ci = {
  age.secretsDir = ./secrets; # Only if you use agenix
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

>[!WARNING]
> **A note on security** of self-hosted GitHub runners: GitHub [recommends](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security) using self-hosted runners only with *private* repositories, as forks *"can potentially run dangerous code on [the] self-hosted runner machine by creating a pull request that executes the code in a workflow"*. 
> 
> You can mitigate this risk by going to the **Fork pull request workflows from outside collaborators** setting (under **Settings -> Actions -> General**) and enabling "Require approval for all outside collaborators".

Finally, you are equipped to add an [actions workflow file](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions) to one of the repositories to test everything out. Here's an example if you have configured both NixOS and macOS runners:

```yaml
# ./.github/workflows/nix.yaml
name: "CI"
on:
  push:
    branches:
      - main
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

The above workflow uses [nixci] to build *all* outputs of your project flake.

#### Matrix builds

Because [nixci] supports generating GitHub's [workflow matrix](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs) configuration, you can use the following workflow YAML to schedule jobs at a fine-grained level to each runner:

```yaml
# ./.github/workflows/nix.yaml
name: "CI"
on:
  push:
    branches:
      - main
  pull_request:
jobs:
  
  configure:
    runs-on: x86_64-linux
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
     - uses: actions/checkout@v4
     - id: set-matrix
       run: echo "matrix=$(nixci gh-matrix --systems=x86_64-linux,aarch64-darwin | jq -c .)" >> $GITHUB_OUTPUT
  
  nix:
    runs-on: ${{ matrix.system }}
    permissions:
      contents: read
    needs: configure
    strategy:
      matrix: ${{ fromJson(needs.configure.outputs.matrix) }}
      fail-fast: false
    steps:
      - uses: actions/checkout@v4
      - run: |
          nixci \
            --extra-access-tokens "github.com=${{ secrets.GITHUB_TOKEN }}" \
            build \
            --systems "${{ matrix.system }}" \
            .#default.${{ matrix.subflake}}
```

See [srid/haskell-flake](https://github.com/srid/haskell-flake/blob/master/.github/workflows/ci.yaml) for a  real-world example.

## Production

### Common issues

#### `Forbidden Runner version ... is deprecated and cannot receive messages.`

Your runner may suddenly crash with an error like this:

```
Jun 27 22:39:54 dosa Runner.Listener[424134]: An error occured: Error: Forbidden Runner version v2.316.1 is deprecated and cannot receive messages.
```

To resolve this, you need to update your github runner package by updating the `nixpkgs` flake input and then re-deploy. See https://github.com/actions/runner/issues/3332#issuecomment-2187929070

>[!TIP]
>
> The `github-runner` package is auto-updated in nixpkgs by the r-ryantm bot ([example](https://github.com/NixOS/nixpkgs/pull/316806)), and then automatically gets backported ([example](https://github.com/NixOS/nixpkgs/pull/316888)) to stable NixOS releases.


## Examples

- [`./example`](./example)
- [`srid/nixos-config`](https://github.com/srid/nixos-config/pull/60)



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
