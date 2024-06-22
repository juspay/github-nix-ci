let
  srid = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHQRxPoqlThDrkR58pKnJgmeWPY9/wleReRbZ2MOZRyd";
  users = [ srid ];

  # Normally you would add the host's pub keys here.
  systems = [ ];
in
{
  "github-nix-ci/srid.token.age".publicKeys = users ++ systems;
  "github-nix-ci/zed-industries.token.age".publicKeys = users ++ systems;
}
