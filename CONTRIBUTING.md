# Contributing Guidelines

Contributions are welcome via GitHub pull requests. This document outlines the process to help get your contribution accepted.

These guidelines apply to everyone, whether a change is written by hand or with the help of AI tools. AI agents read the same rules through [AGENTS.md](./AGENTS.md).

## Sign off Your Work

The Developer Certificate of Origin (DCO) is a lightweight way for contributors to certify that they wrote or otherwise have the right to submit the code they are contributing to the project. Here is the full text of the [DCO](http://developercertificate.org/). Contributors must sign-off that they adhere to these requirements by adding a `Signed-off-by` line to commit messages.

```text
This is my commit message

Signed-off-by: Random J Developer <random@developer.example.org>
```

See `git help commit`:

```text
-s, --signoff
    Add Signed-off-by line by the committer at the end of the commit log
    message. The meaning of a signoff depends on the project, but it typically
    certifies that committer has the rights to submit this work under the same
    license and agrees to a Developer Certificate of Origin (see
    http://developercertificate.org/ for more information).
```

## How to Contribute

1. Fork this repository, develop, and test your changes
1. Remember to sign off your commits as described above
1. Submit a pull request

***NOTE***: In order to make testing and merging of PRs easier, please submit changes to multiple charts in separate PRs.

### Technical Requirements

* Must pass [DCO check](#sign-off-your-work)
* Must follow [Charts best practices](https://helm.sh/docs/topics/chart_best_practices/)
* Must pass CI jobs for linting and installing changed charts with the [chart-testing](https://github.com/helm/chart-testing) tool
* Must pass the chart's [helm-unittest](#helm-unittest) tests, if it has any
* Any change to a chart requires a version bump following [SemVer](https://semver.org/) principles. See [Immutability](#immutability) and [Versioning](#versioning) below

Once changes have been merged, the release job will automatically run to package and release changed charts.

### Pull Request Conventions

* **One chart per PR**: CI enforces that PRs only change a single chart.
* **PR title format**: Must start with the chart name in brackets, e.g. `[grafana] Add new feature`.
* **Squash merge only**: The repository only allows squash merges, so add new commits when addressing review feedback instead of squashing your history.
* **CODEOWNERS/MAINTAINERS**: Auto-generated from `Chart.yaml` maintainer entries by `scripts/generate-codeowners.sh` and `scripts/generate-maintainers.sh`. Do not edit `.github/CODEOWNERS` or `MAINTAINERS.md` directly.
* **Dependencies**: Renovate manages all dependency updates.

### Immutability

Chart releases must be immutable. Any change to a chart (excluding files listed in its `.helmignore`) warrants a chart version bump even if it is only changed to the documentation.

### Versioning

The chart `version` should follow [SemVer](https://semver.org/).

Charts should start at `1.0.0`. Any breaking (backwards incompatible) changes to a chart should:

1. Bump the MAJOR version
2. In the readme, under a section called "Upgrading", describe the manual steps necessary to upgrade to the new (specified) MAJOR version

### Upgrading section

Major version bumps **must** add a `### X.0.0` subsection under the chart README's `## Upgrading` heading that documents:

1. What is breaking
2. Who is affected
3. How affected users should proceed

## Development

### Repository Layout

All charts live under `charts/` with a subfolder for each chart. The subfolder names must match the chart name as described in the `Chart.yaml` file `.name`.

Each chart follows standard Helm structure (`Chart.yaml`, `values.yaml`, `templates/`). Some charts organize components into subdirectories (e.g., `templates/compactor/`, `templates/ingester/`).

Charts target Kubernetes `^1.25.0-0` (`kubeVersion` in `Chart.yaml`).

### Changing a Chart

1. Identify the affected chart under `charts/<chart>/` and keep changes scoped to that chart.
2. Read the relevant `Chart.yaml`, `values.yaml`, templates, helpers, and existing tests before editing.
3. Implement the change using the chart's existing template style and values structure.
4. If `values.yaml` changes in a schema-enabled chart, update schema annotations and regenerate `values.schema.json` (see [Values Schema](#values-schema)).
5. Add or update focused helm-unittest coverage for the rendered behavior controlled by the change.
6. Bump the chart version in `Chart.yaml` according to [SemVer](#versioning).
7. Run the relevant validation commands, normally `make helm-unittest HELM_CHART=<chart-name>` and any required schema generation command.

### Values Schema

Some charts generate `values.schema.json` from `values.yaml` using [helm-values-schema-json](https://github.com/losisin/helm-values-schema-json/blob/main/docs/README.md). A chart uses this flow if `values.yaml` contains `# @schema` comments or a top-level `# $schema: ./values.schema.json` comment.

Helm validates chart values with JSON Schema draft-07. Keep generated schemas compatible with draft-07 even if external schema tooling supports newer drafts.

When changing `values.yaml` in a schema-enabled chart:

* Preserve and update nearby `# @schema` annotations.
* Add `# @schema` annotations when inferred schema types would be wrong or too loose.
* Keep `# @schema` comments before helm-docs comments (`# -- ...`) when both are present.
* Regenerate `values.schema.json` with `make helm-schema HELM_CHART=<chart-name>` (e.g. `loki`, `grafana`) and include it in the change.
* Add or update helm-unittest coverage for rendered behavior controlled by the changed values.

### helm-unittest

Pull requests against this repository require that all charts which implement [helm-unittest](https://github.com/helm-unittest/helm-unittest) tests pass all of them. Run them from the repository root:

```bash
make helm-unittest HELM_CHART=<chart-name>
```

### AI Guidance

Using AI tools to help write your PR is acceptable, but as the author, you are responsible for understanding every change. If you used AI tools in preparing your PR, you must disclose this in the description of your PR. For example, including "This PR was written in part with the assistance of generative AI," in the PR description is sufficient.

Listing AI tooling as a co-author, co-signing commits using an AI tool, or using the assisted-by, co-developed or similar commit trailer is not allowed.

The commit message or the PR description is the primary way in which you communicate the intention of a pull request to maintainers and other contributors.

Please do not use AI to generate the commit message, as it can often turn into an unnecessary wall of text, with code-level details about the change, without capturing original motivations for it. If such a description is raised, it will be ignored for review until rectified.

Do not leave the first review of AI generated changes to the reviewers. Verify the changes (code review, testing, etc.) before submitting your PR. Reviewers may ask questions about your AI-assisted code, and if you cannot explain why a change was made, the PR will be closed.

When responding to review comments, you must do so without relying on AI tools. Reviewers want to engage directly with you, not with generated responses. If you do not engage directly with reviewers, the PR will be closed.

## Community Requirements

This project is released with a [Contributor Covenant](https://www.contributor-covenant.org).
By participating in this project you agree to abide by its terms.
See [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).
