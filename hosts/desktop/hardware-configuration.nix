# Replace this placeholder with the output of:
#   nixos-generate-config --show-hardware-config
# before installing on physical hardware.
{lib, ...}: {
  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-label/nixos";
    fsType = lib.mkDefault "ext4";
  };
}
