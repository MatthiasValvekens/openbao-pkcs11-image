# openbao-pkcs11 container image

OpenBao with the `kms-pkcs11` seal plugin and the Yubico YubiHSM PKCS#11
module, on Debian stable (glibc). Built from a `Containerfile` by GitHub
Actions, published to ghcr for `linux/amd64` and `linux/arm64`, signed with
keyless cosign.

This is a generic recipe. It contains no OpenBao configuration, no connector
URLs and no secrets: all of that belongs in the deployment (Helm chart).

## OpenTofu runner image

A sibling image, `ghcr.io/matthiasvalvekens/openbao-pkcs11-image/tofu`, carries
OpenTofu and the HashiCorp Vault provider for running configuration against an
OpenBao/Vault server without fetching anything at run time. See
[tofu/README.md](tofu/README.md).
