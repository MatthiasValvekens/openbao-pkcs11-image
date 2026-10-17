# syntax=docker/dockerfile:1
#
# OpenBao + kms-pkcs11 plugin + Yubico YubiHSM PKCS#11 module, on Debian (glibc).
# Generic recipe: no runtime configuration lives here (see README.md).
#
# Versions below are bumped by Renovate (renovate.json). The base image is
# digest-pinned in both FROM lines; keep them identical.

# ---------------------------------------------------------------------------
# fetch: download and GPG-verify the upstream release artifacts.
# Runs on the *build* platform and only downloads/unpacks (never executes
# target-arch binaries), so the arm64 build needs no emulation here.
# ---------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM debian:trixie-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f AS fetch

# renovate: datasource=github-releases depName=openbao/openbao extractVersion=^v(?<version>.*)$
ARG OPENBAO_VERSION=2.7.1
# renovate: datasource=github-releases depName=openbao/openbao-plugins extractVersion=^kms-pkcs11-v(?<version>.*)$
ARG KMS_PKCS11_VERSION=0.2.1

# OpenBao release signing key (primary fingerprint, as published on openbao.org).
ARG OPENBAO_GPG_FINGERPRINT=66D15FDD87287219C8E15478D200CD702853E6D0

ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && rm -rf /var/lib/apt/lists/*

COPY openbao-release-key.asc /tmp/openbao-release-key.asc

# Import the key, and refuse to continue unless it is the pinned one.
RUN set -eu; \
    export GNUPGHOME=/tmp/gnupg; mkdir -m 700 "$GNUPGHOME"; \
    gpg --batch --import /tmp/openbao-release-key.asc; \
    got="$(gpg --batch --with-colons --fingerprint | awk -F: '$1=="fpr"{print $10; exit}')"; \
    [ "$got" = "$OPENBAO_GPG_FINGERPRINT" ] || { echo "unexpected key $got" >&2; exit 1; }

# OpenBao: signed checksums.txt, then the tarball against it, plus the
# tarball's own detached signature.
RUN set -eu; \
    export GNUPGHOME=/tmp/gnupg; mkdir /dl-bao; cd /dl-bao; \
    base="https://github.com/openbao/openbao/releases/download/v${OPENBAO_VERSION}"; \
    tarball="openbao_${OPENBAO_VERSION}_linux_${TARGETARCH}.tar.gz"; \
    curl -fsSLO "$base/$tarball"; curl -fsSLO "$base/$tarball.gpgsig"; \
    curl -fsSLO "$base/checksums.txt"; curl -fsSLO "$base/checksums.txt.gpgsig"; \
    gpg --batch --verify "$tarball.gpgsig" "$tarball"; \
    gpg --batch --verify checksums.txt.gpgsig checksums.txt; \
    grep " $tarball\$" checksums.txt | sha256sum -c -; \
    tar -xzf "$tarball" bao; \
    install -D -m 0755 bao /out/usr/bin/bao

# kms-pkcs11 plugin: the release signs each tarball (detached .sig). The
# upstream asset names carry the Go microarchitecture level.
RUN set -eu; \
    export GNUPGHOME=/tmp/gnupg; mkdir /dl-plugin; cd /dl-plugin; \
    case "$TARGETARCH" in amd64) suffix=amd64_v1 ;; arm64) suffix=arm64_v8 ;; *) echo "unsupported arch $TARGETARCH" >&2; exit 1 ;; esac; \
    base="https://github.com/openbao/openbao-plugins/releases/download/kms-pkcs11-v${KMS_PKCS11_VERSION}"; \
    tarball="openbao-plugin-kms-pkcs11_linux_${suffix}.tar.gz"; \
    curl -fsSLO "$base/$tarball"; curl -fsSLO "$base/$tarball.sig"; \
    gpg --batch --verify "$tarball.sig" "$tarball"; \
    tar -xzf "$tarball" "openbao-plugin-kms-pkcs11_linux_${suffix}"; \
    install -D -m 0755 "openbao-plugin-kms-pkcs11_linux_${suffix}" \
        /out/usr/libexec/openbao/plugins/openbao-plugin-kms-pkcs11; \
    mkdir -p /out/usr/share/openbao; \
    (cd /out/usr/libexec/openbao/plugins && sha256sum openbao-plugin-kms-pkcs11 > /out/usr/share/openbao/kms-pkcs11.sha256)

# ---------------------------------------------------------------------------
# final
# ---------------------------------------------------------------------------
FROM debian:trixie-slim@sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f

RUN set -eu; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates yubihsm-pkcs11 libyubihsm-http2; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /var/log/apt /var/log/dpkg.log /var/log/alternatives.log \
           /usr/share/man /usr/share/info /usr/share/p11-kit; \
    groupadd --system --gid 10001 openbao; \
    useradd --system --uid 10001 --gid 10001 --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin openbao; \
    # Build-time sanity: the module and the HTTP backend resolve all their libs.
    mod="$(ls /usr/lib/*/pkcs11/yubihsm_pkcs11.so)"; \
    http="$(ls /usr/lib/*/libyubihsm_http.so.2)"; \
    # (not `! ldd ... | grep`: set -e ignores a `!`-negated command)
    if ldd "$mod" "$http" | grep 'not found'; then exit 1; fi; \
    # Arch-independent path for the chart's `seal "pkcs11" { lib = ... }`.
    mkdir -p /usr/libexec; ln -s "$mod" /usr/libexec/yubihsm_pkcs11.so

COPY --from=fetch /out/ /

# openbao-helm runs /usr/local/bin/docker-entrypoint.sh (upstream image layout);
# its preStop hook also needs `pidof` (sysvinit-utils, Essential in Debian).
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

LABEL org.opencontainers.image.title="openbao-pkcs11" \
      org.opencontainers.image.description="OpenBao with the kms-pkcs11 plugin and the YubiHSM PKCS#11 module"

USER 10001:10001
EXPOSE 8200 8201
ENTRYPOINT ["/usr/bin/bao"]
CMD ["server", "-config=/etc/openbao/config.hcl"]
