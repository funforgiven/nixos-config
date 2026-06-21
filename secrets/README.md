# Secrets

Do not commit secret material here.

The system expects this root-owned file on the installed machine:

```text
/var/lib/nixos-secrets/funforgiven-password.hash
```

Generate it with:

```sh
sudo mkdir -p /var/lib/nixos-secrets
mkpasswd -m yescrypt | sudo tee /var/lib/nixos-secrets/funforgiven-password.hash >/dev/null
sudo chmod 600 /var/lib/nixos-secrets/funforgiven-password.hash
```
