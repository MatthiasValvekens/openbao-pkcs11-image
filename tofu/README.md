# OpenTofu runner image

OpenTofu, the `hashicorp/vault` provider in an in-image filesystem mirror, the
provider lock file that matches that mirror, `jq`, and a generic plan guard, on
Debian stable (glibc). Built from `Containerfile` by GitHub Actions, published
to ghcr for `linux/amd64` and `linux/arm64`, signed with keyless cosign.

This is a generic recipe. It contains no `.tf` files, no server addresses and no
policy: those belong to whoever runs the image.

## Interface

| Path | What |
|---|---|
| `/usr/bin/tofu` | OpenTofu (the entrypoint; default command `version`) |
| `/usr/share/tofu/providers` | filesystem mirror, `registry.opentofu.org/hashicorp/vault` |
| `/usr/share/tofu/.terraform.lock.hcl` | lock file for exactly that provider version, `h1:` and `zh:` hashes for linux/amd64 and linux/arm64 |
| `/etc/tofu/tofurc` | CLI config (`TF_CLI_CONFIG_FILE`): provider installation from the mirror only, no registry fallback |
| `/usr/bin/tofu-destroy-guard` | plan guard, see below |

Providers come from the mirror only. The configuration declares just a version
constraint (`source = "hashicorp/vault"`, `version = "~> 5.0"`); copy the lock
file next to the `.tf` files before `tofu init`. The image sets
`TF_CLI_ARGS_init=-lockfile=readonly`, so `init` verifies against the shipped
lock file, never rewrites it, and fails if the configuration's constraint does
not match the shipped provider version or if the lock file is missing.

```sh
cp /usr/share/tofu/.terraform.lock.hcl .
tofu init
tofu plan -out=plan.bin
tofu-destroy-guard plan.bin
tofu apply plan.bin
```

The image runs as uid/gid 10001 and works with a read-only root filesystem.
Only the working directory (which holds the `.tf` files, the lock file and
`.terraform/`) and `$TMPDIR` (default `/tmp`) must be writable, e.g. emptyDirs.

## Plan guard

`tofu-destroy-guard PLANFILE` (or `-` to read `tofu show -json` output from
stdin) exits non-zero if the plan deletes or replaces a resource whose type is
not on the allowlist, or renames a mount in place (`vault_mount`,
`vault_auth_backend`, `vault_jwt_auth_backend` with a changed `path`). `forget`
(from `removed { lifecycle { destroy = false } }`) passes.

- `TOFU_GUARD_ALLOW_DELETE`: resource types that may be deleted, separated by
  commas and/or whitespace. Unset or empty means nothing may be deleted.
- `TOFU_GUARD_PATH_TYPES`: types checked for a path change (default: the three
  above; `-` disables the check).

Exit status: 0 acceptable, 1 refused, 2 error (an unreadable plan is never a
pass). `sh test/guard-test.sh` tests it against fixtures.
