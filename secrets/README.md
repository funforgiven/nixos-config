# Password Bootstrap

Do not commit cleartext secret material here.

The immutable `funforgiven` account expects its password hash at:

```text
/var/lib/nixos-secrets/funforgiven-password.hash
```

Generate the hash with:

```sh
mkpasswd -m yescrypt
```

Place it at the path above during installation with owner `root` and mode `0600`.
