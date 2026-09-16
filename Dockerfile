# Custom Kiro Crew image — thin layer on the official gateway image.
# Pattern: rjullien/hermes-leo-config (build repo → GHCR; runtime GitOps in BaptTF/vps-infra).
#
# This is NOT kiro-cli-config. The official image already embeds kiro-cli as the
# agent runtime; this repo only rebuilds/publishes a pinned, scan-gated image
# for the k3s cluster GitOps'd via BaptTF/vps-infra.
#
# Base: ghcr.io/kirodotdev/kirocrew (Python 3.12 slim-trixie, multi-arch).
# Upstream contract preserved: USER kirocrew, HOME/WORKDIR /home/kirocrew,
# ENTRYPOINT kirocrew-entrypoint, CMD gateway. Do NOT replace the entrypoint
# with sleep/infinity.
#
# SECURITY: this repo is PUBLIC and the GHCR package must be public after the
# first push — NO secrets, tokens, or PII in this Dockerfile or the image.

# Base pinned by version tag + digest (S-02). Renovate maintains the pair
# (pinDigests). The digest is the multi-arch *index* digest; buildx selects
# amd64/arm64 per target platform.
FROM ghcr.io/kirodotdev/kirocrew:0.6.0@sha256:ba01bb1c75ea454af2b53773f39c3b38899f0d1d9ab51a0eb97001df6db27407

# Optional thin layer: digest-pinned bases lag Debian security fixes. Apply
# apt upgrades so the Trivy CRITICAL (fixable) gate stays green without
# widening .trivyignore for OS CVEs this layer can clear. Reliquats that
# truly cannot be fixed via apt belong in .trivyignore (documented).
USER root
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Restore the upstream non-root contract. Do not change ENTRYPOINT/CMD.
USER kirocrew
WORKDIR /home/kirocrew
