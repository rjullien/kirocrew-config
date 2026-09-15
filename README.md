# kirocrew-config

Custom image for **[Kiro Crew](https://kiro.dev/crew/)** (gateway 24/7:
dashboard, channels, cron, multi-agent) on the personal k3s cluster — same
build-repo pattern as [`hermes-leo-config`](https://github.com/rjullien/hermes-leo-config).

| | |
|---|---|
| **Base** | [`ghcr.io/kirodotdev/kirocrew`](https://github.com/kirodotdev/KiroCrew/blob/main/docs/guides/docker.md) (pinned by version tag + digest) |
| **Published image** | `ghcr.io/rjullien/kirocrew-config/kirocrew` |
| **Runtime GitOps** | [`BaptTF/vps-infra`](https://github.com/BaptTF/vps-infra) — **no Kubernetes manifests in this repo** |
| **Not this** | [`kiro-cli-config`](https://github.com/rjullien/kiro-cli-config) is the CLI binary only — ignore it here |

This Dockerfile keeps the upstream contract: `USER kirocrew`, home at
`/home/kirocrew`, `ENTRYPOINT kirocrew-entrypoint`, `CMD gateway`. The only
optional layer is an `apt-get upgrade` so digest-pinned bases do not lag Debian
security fixes (Trivy CRITICAL / fixable gate).

**No secrets in this public repo.** Channel tokens, OAuth, and dashboard
credentials belong in Infisical / the runtime volume — never in the image.

## Image tags (calver)

```
ghcr.io/rjullien/kirocrew-config/kirocrew:v2026.9.15   ← release (calver)
ghcr.io/rjullien/kirocrew-config/kirocrew:v2026.9     ← monthly
ghcr.io/rjullien/kirocrew-config/kirocrew:latest      ← moves on release
ghcr.io/rjullien/kirocrew-config/kirocrew:sha-<sha>   ← immutable
```

Platforms: `linux/amd64` + `linux/arm64` (official base publishes both).

Prefer deploying by **digest** from vps-infra; `latest` / monthly tags are mutable.

### Create a release

Automatic: Renovate bumps the `FROM` line → merge to `main` →
`auto-release.yml` creates the GitHub Release **and builds/pushes in the same
run** (GitHub suppresses `release: published` when a workflow creates the
release — lesson from hermes-leo-config #33).

Manual:

```bash
gh release create v2026.9.15 \
  --repo rjullien/kirocrew-config \
  --title "kirocrew-config v2026.9.15" \
  --notes "Pin official kirocrew 0.6.0 + apt security layer"
```

`workflow_dispatch` on `build.yml` only pushes `sha-<commit>` (does not move
`latest`).

### GHCR package visibility

After the **first** successful push, set the GitHub Packages container
`kirocrew` under this repo to **public** (Settings → Packages, or the package
page). Until then pulls fail for anonymous/cluster nodes without a pull secret.

## First login (runtime)

After the pod is up (volume on `/home/kirocrew`):

```bash
# 1. Log in the agent runtime (kiro-cli). Credentials persist on the volume.
kubectl exec -it -n <ns> deploy/<kirocrew> -- kiro-cli login

# 2. Mint a dashboard login link (token auth required on :5476).
kubectl exec -n <ns> deploy/<kirocrew> -- kirocrew token --ttl 2h
```

Open the printed URL against your ingress/port-forward host. Minted links expire
quickly — mint, then open immediately.

### Sandbox on Kubernetes

On many k8s runtimes the inner user-namespace sandbox probe fails (seccomp).
Agent exec then stays fail-closed unless you either ship a custom seccomp
profile or explicitly allow unsandboxed agent execution:

```yaml
env:
  - name: KIROCREW_ALLOW_UNSANDBOXED
    value: "1"
```

With that flag the **container is the only isolation boundary** — do not mount
host paths you would not hand to the agent. See upstream
[docker.md — Sandbox](https://github.com/kirodotdev/KiroCrew/blob/main/docs/guides/docker.md).

## CI

| Workflow | Role |
|---|---|
| `pr-validation.yml` | Build (amd64), smoke (`kirocrew` / `kiro-cli --help`), entrypoint/USER check, Trivy CRITICAL fixable gate |
| `build-image.yml` | Reusable build/push (multi-arch) + provenance attestation |
| `build.yml` | Manual release event + `workflow_dispatch` → build-image |
| `auto-release.yml` | Calver release + build in one run when `FROM` changes on `main` |
| `renovate.yml` | Self-hosted Renovate (needs `RENOVATE_TOKEN`) |

Smoke does **not** start the long-running gateway or require login.

## Renovate

Tracks `ghcr.io/kirodotdev/kirocrew` (7-day `minimumReleaseAge`, automerge) and
GitHub Actions digests. Human review of the running image happens when
vps-infra consumes a new digest.

Requires secret `RENOVATE_TOKEN` (dedicated PAT with `workflow` scope). Do not
set `RENOVATE_AUTOMERGE=false` in the workflow env.

## Local build

```bash
docker build -t kirocrew-config:dev .
docker run --rm --entrypoint kirocrew kirocrew-config:dev --help
docker run --rm --entrypoint kiro-cli kirocrew-config:dev --help
```

## License

MIT for the build files in this repository. Upstream Kiro Crew remains under
its own license / image terms.
