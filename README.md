# OpenBao and OpenTofu container images

Two sister images, one directory each. Every directory holds a `Containerfile`
and is its own build context. Both images are built on Debian stable (glibc) by
GitHub Actions, published to ghcr for `linux/amd64` and `linux/arm64`, and signed
with keyless cosign. Both are generic recipes: no configuration, server
addresses or secrets.

| Directory | Image | Version tag |
|---|---|---|
| [openbao/](openbao/README.md) | `ghcr.io/matthiasvalvekens/openbao-pkcs11-image` | `<bao>-pkcs11-<plugin>` |
| [tofu/](tofu/README.md) | `ghcr.io/matthiasvalvekens/openbao-pkcs11-image/tofu` | `<tofu>-vault-<provider>` |

## CI

Each image has a workflow (`.github/workflows/<dir>-image.yml`) that runs when
its directory, its workflow, or the shared composite action
`.github/actions/build-image` changes, and on `v*` tags. Pull requests build
both platforms without publishing. On `master` the tags are `latest`, the
version tag and `sha-<short>`; `v*` tags add semver. The version tag is filled
in from the Containerfile's `ARG` defaults.

The signing identity is the image's own workflow:

```
cosign verify ghcr.io/matthiasvalvekens/openbao-pkcs11-image@sha256:... \
  --certificate-identity 'https://github.com/MatthiasValvekens/openbao-pkcs11-image/.github/workflows/openbao-image.yml@refs/heads/master' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

(`tofu-image.yml` for the `/tofu` image.)

## Updates

Renovate (`renovate.json`) bumps the digest-pinned Debian base, the
`# renovate:`-annotated `ARG` versions in each Containerfile, and the pinned
actions in the workflows and in the composite action.
