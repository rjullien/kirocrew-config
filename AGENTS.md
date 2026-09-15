# AGENTS.md — rules for AI agents working on this repo

This repo builds a **thin custom image** of the official Kiro Crew gateway for
René's personal k3s cluster. Read this before changing anything.

## Purpose

Re-publish `ghcr.io/kirodotdev/kirocrew` as
`ghcr.io/rjullien/kirocrew-config/kirocrew` with:

- version tag + digest pin (Renovate)
- optional apt security upgrade layer (Trivy CRITICAL gate)
- calver releases + multi-arch push to GHCR

**Not in scope:** Kubernetes manifests, channel credentials, dashboard tokens,
or any runtime config. Those live in **BaptTF/vps-infra** (GitOps) and Infisical.

**Not this repo:** `rjullien/kiro-cli-config` is a different project (CLI binary
only). Do not conflate them with Kiro Crew.

## Absolute rules

1. **No secrets in this public repo.** No tokens, refresh tokens, bot secrets,
   API keys, PII. Credentials go to Infisical / the runtime PVC — never the image.
2. **Keep the upstream contract.** `USER kirocrew`, `WORKDIR /home/kirocrew`,
   `ENTRYPOINT kirocrew-entrypoint`, `CMD gateway`. Never replace the entrypoint
   with `sleep infinity` or a custom shell loop.
3. **Do not add Kubernetes manifests here.** Deployments belong in
   `BaptTF/vps-infra`.
4. **Pin the base by tag + digest.** Renovate owns the pair (`pinDigests`).
5. **Prefer a thin layer.** Extra packages only when justified; prefer bumping
   the official base over growing this Dockerfile.

## Release flow

Calver tags `vYYYY.M.D` (with `.N` suffix if needed the same day):

1. Renovate (or a human) bumps `FROM ghcr.io/kirodotdev/kirocrew:…@sha256:…`
2. Merge to `main` → `auto-release.yml` creates the GitHub Release **and**
   builds/pushes in the **same run** (GitHub drops `release: published` when
   the release is created from a workflow — see hermes-leo-config #33)
3. Image tags pushed:
   - `vYYYY.M.D`, `vYYYY.M`, `latest`, `sha-<commit>`
4. Update the image digest/tag in **BaptTF/vps-infra** → ArgoCD syncs

Manual release (`gh release create …`) still triggers `build.yml` via
`release: published`. `workflow_dispatch` on `build.yml` only pushes
`sha-<commit>` (never moves `latest`).

## Renovate

- Self-hosted via `.github/workflows/renovate.yml` (not the public Renovate app)
- Requires secret `RENOVATE_TOKEN` (PAT); `GITHUB_TOKEN` is not enough
- Do **not** set `RENOVATE_AUTOMERGE=false` in the workflow env (it overrides
  `renovate.json`)
- After Renovate config changes: `gh workflow run renovate.yml`

## Smoke / CI expectations

PR validation builds `linux/amd64`, runs `kirocrew --help` / `kiro-cli --help`
(no login, no long-running gateway), checks USER/entrypoint, and gates on
Trivy CRITICAL fixable findings. Release builds are multi-arch
(`linux/amd64,linux/arm64`).

## First login (runtime, not build)

Documented in README — `kubectl exec … -- kiro-cli login` and
`kirocrew token --ttl 2h`. Likely need `KIROCREW_ALLOW_UNSANDBOXED=1` on k8s.

## Conventions

- Conventional Commits (`feat:`, `fix:`, `ci:`, `chore:`, `docs:`)
- One calver release = one image build with release tags
- Behavior changes → update README.md (public image consumers read it)
