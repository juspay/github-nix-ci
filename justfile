default:
    @just --list

# Build & check everything (using github:srid/nixci)
check:
    nixci build

# Auto-format the Nix files in project tree
fmt:
    treefmt
