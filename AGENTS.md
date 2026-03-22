# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the **Grafana Community Helm Charts** repository — a collection of Helm charts for Grafana ecosystem components. Charts are published to both a Helm repository (`grafana-community`) and as OCI artifacts on `ghcr.io`.

## Charts

All charts live under `charts/` with a subfolder for each chart.  The subfolder names must match the chart name as described in the Chart.yaml file `.name`.

Each chart follows standard Helm structure (`Chart.yaml`, `values.yaml`, `templates/`). Some charts will organize components into subdirectories (e.g., `templates/compactor/`, `templates/ingester/`).

## Helm Chart Design

Charts should be written idiomatically and favor the conventions that Helm users encounter daily. Templates must be readable by anyone familiar with the Helm language without needing to trace complex call chains.

### Named templates

Named templates in `_helpers.tpl` should prefer receiving the standard `.` (dot) context. Typical helpers — chart name, fullname, labels, selectors, service account name, namespace override — all work with dot and should stay that way.

For multi-component charts, passing a two-key dict is an accepted workaround since Helm templates only take one argument:

```yaml
{{- include "tempo.labels" (dict "ctx" . "component" "compactor") }}
```

Dicts with three or more keys, optional keyword arguments, and chained dict dispatches are not acceptable.

### Anti-patterns

Do not introduce these patterns into new or existing charts:

- **Function-style templates with many parameters** — named templates that accept dicts with 3+ keys to simulate function signatures (e.g., `dict "ctx" $ "component" .component "rolloutZoneName" .zone "suffix" .suffix`).
- **Render-then-parse** — templates that re-render other templates and parse the output (`include ... | fromYaml`) to inspect rendered resources at render time.
- **Double-dispatch dict chains** — template A builds a dict and passes it to template B, which builds another dict for template C.
- **Full resources inside helpers** — embedding complete Kubernetes resource manifests inside a named template. Helpers should produce YAML fragments (labels, annotations, env blocks), not entire resources. The exception is shared library patterns in `lib/` directories, which are designed to emit full resources.

### Scope

These conventions apply to all new and incoming charts. Existing charts should be refactored toward compliance over time.

## pre-commit testing

### helm-unittests

Pull Requests against this repository require that all charts which implement helm-unittests(https://github.com/helm-unittest/helm-unittest) must pass all of their unittests.  This can be done via a single command run from the repository root:

```bash
make helm-unittest
```

## Contributing Conventions

- **One chart per PR**: CI enforces that PRs only change a single chart.
- **PR title format**: Must start with `[chart-name] ` (e.g., `[grafana] Add new feature`).
- **Version bumps**: Every chart change (excluding files listed in `.helmignore`) requires a SemVer version bump in `Chart.yaml`. Major bumps for breaking changes.
- **DCO sign-off**: Commits must include `Signed-off-by` line (`git commit -s`).
- **Squash merge only**: The repository only allows squash merges.
- **CODEOWNERS/MAINTAINERS**: Auto-generated from `Chart.yaml` maintainer entries by `scripts/generate-codeowners.sh` and `scripts/generate-maintainers.sh`. Do not edit `.github/CODEOWNERS` or `MAINTAINERS.md` directly.
- **Minimum Kubernetes version**: Charts target `^1.25.0-0` (`kubeVersion` in `Chart.yaml`).

## Dependency Management

Renovate manages automated dependency updates. Charts with subchart dependencies (e.g., `tempo-distributed` depends on `minio`, `grafana-agent-operator`, `rollout-operator`) declare them in `Chart.yaml`. Dependency repositories used in CI/release:

```
bitnami, grafana, grafana-community, prometheus-community, minio
```
