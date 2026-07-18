# Repository Secrets

Commit secret values only as SOPS ciphertext. Recipients are declared in
`../.sops.yaml`.

## Inventory

| SOPS file and key | Purpose |
| --- | --- |
| `github-ssh-key.sops` | GitHub SSH authentication and signing |
| `api-tokens.yaml` → `codex/anwa_github_mcp_token` | Anwa workspace GitHub MCP server |
| `api-tokens.yaml` → `codex/github_mcp_token` | GitHub MCP server |
| `api-tokens.yaml` → `codex/context7_api_key` | Context7 MCP server |
| `password-hashes.yaml` → `users/funforgiven/password_hash` | NixOS account password hash |

## Recovery

Back up the complete personal age identity at
`~/.config/sops/age/keys.txt`. It can decrypt and rekey every current secret.

NixOS also derives a recipient from `/etc/ssh/ssh_host_ed25519_key` for
unattended activation. Backing up that host key is optional; it preserves the
host identity and avoids updating recipients. When replacing it, derive the new
recipient, add it to `../.sops.yaml`, and update every SOPS file before
`nixos-install`.

## Editing

Edit the structured files with the repository-pinned CLI:

```sh
nix run .#sops --accept-flake-config -- secrets/api-tokens.yaml
nix run .#sops --accept-flake-config -- secrets/password-hashes.yaml
```

Replace the binary SSH key by encrypting a new private key directly. Do not
copy the plaintext key into this repository:

```sh
nix run .#sops --accept-flake-config -- encrypt \
  --input-type binary \
  --output-type binary \
  --filename-override secrets/github-ssh-key.sops \
  --output secrets/github-ssh-key.sops \
  /secure/path/github_ed25519
```

Generate a replacement password hash with `mkpasswd -m yescrypt`, then update
`users/funforgiven/password_hash` in `password-hashes.yaml`.

After changing a secret, activate the configuration and restart its consumer.

## Recipient Changes

Derive a recipient from a host public key with:

```sh
nix run .#ssh-to-age --accept-flake-config \
  < /path/to/ssh_host_ed25519_key.pub
```

After changing `../.sops.yaml`, update every encrypted file:

```sh
nix run .#sops --accept-flake-config -- updatekeys secrets/api-tokens.yaml
nix run .#sops --accept-flake-config -- updatekeys secrets/github-ssh-key.sops
nix run .#sops --accept-flake-config -- updatekeys secrets/password-hashes.yaml
```

If a recipient is compromised, remove it, run `updatekeys`, and rotate each
affected file's SOPS data key:

```sh
nix run .#sops --accept-flake-config -- rotate --in-place FILE
```

Also rotate every affected API token, SSH key, or password. Old ciphertext
remains available in Git history.
