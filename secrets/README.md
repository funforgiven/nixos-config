# Secrets

Do not commit secret material here.

The system expects this root-owned file on the installed machine:

```text
/var/lib/nixos-secrets/funforgiven-password.hash
```

During installation, after disko mounts the target system at `/mnt`, generate it with:

```sh
sudo mkdir -p /mnt/var/lib/nixos-secrets
mkpasswd -m yescrypt | sudo tee /mnt/var/lib/nixos-secrets/funforgiven-password.hash >/dev/null
sudo chmod 600 /mnt/var/lib/nixos-secrets/funforgiven-password.hash
```
