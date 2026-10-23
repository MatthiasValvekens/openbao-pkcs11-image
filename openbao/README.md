# openbao-pkcs11 image

OpenBao with the `kms-pkcs11` seal plugin and the Yubico YubiHSM PKCS#11
module, on Debian stable (glibc). Built from `Containerfile` by GitHub
Actions, published to ghcr for `linux/amd64` and `linux/arm64`, signed with
keyless cosign.

This is a generic recipe. It contains no OpenBao configuration, no connector
URLs and no secrets: all of that belongs in the deployment (Helm chart).

## Interface

| Path | What |
|---|---|
| `/usr/bin/bao` | OpenBao (the entrypoint; default command `server -config=/etc/openbao/config.hcl`) |
| `/usr/libexec/openbao/plugins/openbao-plugin-kms-pkcs11` | the kms-pkcs11 plugin |
| `/usr/share/openbao/kms-pkcs11.sha256` | the plugin's sha256, for plugin registration |
| `/usr/libexec/yubihsm_pkcs11.so` | arch-independent link to the YubiHSM PKCS#11 module |
| `/usr/local/bin/docker-entrypoint.sh` | shim for openbao-helm, which starts the server through it |

The image runs as uid/gid 10001 and exposes 8200 and 8201.
