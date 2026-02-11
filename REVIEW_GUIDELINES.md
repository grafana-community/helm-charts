# Review Guidelines

This document is a quick-reference checklist for reviewers of pull requests in the `grafana-community/helm-charts` repository.
For full contributor instructions, see [CONTRIBUTING.md](./CONTRIBUTING.md).
For the review and merge process, see [PROCESSES.md](./PROCESSES.md).

## PR Metadata

- [ ] Title follows the format `[chart-name] short description`
- [ ] Only **one** chart is changed per PR
- [ ] All commits are [DCO signed-off](./CONTRIBUTING.md#sign-off-your-work) (`Signed-off-by:` trailer)

## Versioning

- [ ] Chart `version` in `Chart.yaml` is bumped
- [ ] Version follows [semver](https://semver.org/) (`MAJOR.MINOR.PATCH`)
- [ ] Breaking (backwards-incompatible) changes bump the **MAJOR** version and include an "Upgrading" section in the chart README

## Chart.yaml

Required fields:

| Field | Expectation |
|-------|-------------|
| `apiVersion` | `v2` |
| `name` | Matches the chart directory name |
| `version` | Valid semver, bumped from previous release |
| `appVersion` | Tracks the upstream application version |
| `description` | Short, meaningful summary |
| `kubeVersion` | Set appropriately (e.g. `^1.25.0-0`) |
| `maintainers` | `name`, `url` (`https://github.com/<username>`), `email` fields are mandatory |

Optional but encouraged:

- `home`, `icon`, `sources`, `keywords`
- ArtifactHub annotations (e.g. `artifacthub.io/license`, `artifacthub.io/links`)

## Values & Templates

- [ ] Container images are configurable via values file
- [ ] `resources` are **not** set by default (left for the user to configure)
- [ ] Features that require cluster resources (persistence, ingress, autoscaling) are **disabled** by default
- [ ] For Charts leveraging [helm-docs](https://github.com/norwoodj/helm-docs), Values file comments are prefixed with `# --` so that it can distinguish between documentation and examples

## Labels & Selectors

- [ ] Templates use the `app.kubernetes.io/*` [recommended labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/) (e.g. `app.kubernetes.io/name`, `app.kubernetes.io/instance`) 
- [ ] `helm.sh/chart` does **not** appear in `spec.selector.matchLabels` (selectors are immutable after creation; including the chart version would break upgrades)

## Documentation

- [ ] Chart README is auto-generated via [helm-docs](https://github.com/norwoodj/helm-docs)
- [ ] `templates/NOTES.txt` provides accurate post-install instructions when needed

## Testing

- [ ] Unit tests exist in the chart's `tests/` directory
- [ ] The chart installs cleanly in a Kind cluster (chart-testing install with 600s timeout)

## CI Checks

All of the CI jobs must pass before a PR can be merged

## Review & Merge Process

- A **chart maintainer** (listed in the chart's `Chart.yaml`) should review and approve each PR
- The approver should also **merge** the PR
- Only **squash merge** is allowed
- If no chart maintainer reviews within **two weeks**, the PR author may request a review from a repository admin
- Every chart should have at least **two maintainers** so PRs can always be reviewed

For the full process, see [PROCESSES.md](./PROCESSES.md).
