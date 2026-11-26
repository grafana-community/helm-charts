# Instructions for AI Agents

This is the **Grafana Community Helm Charts** repository, a collection of Helm charts for Grafana ecosystem components. Charts are published to both a Helm repository (`grafana-community`) and as OCI artifacts on `ghcr.io`.

Humans and agents follow the same rules. Read [CONTRIBUTING.md](./CONTRIBUTING.md) before making any change and follow it, in particular:

* [Pull Request Conventions](./CONTRIBUTING.md#pull-request-conventions)
* [Changing a Chart](./CONTRIBUTING.md#changing-a-chart)
* [Values Schema](./CONTRIBUTING.md#values-schema)
* [AI Guidance](./CONTRIBUTING.md#ai-guidance)

## Agent-specific Notes

* Ask the user for clarification only when the intended chart, behavior, or compatibility impact cannot be inferred from the request and local context.
* For schema-enabled charts, use the `helm-values-schema` skill for detailed annotation and regeneration rules. Use Context7 for current `helm-values-schema-json` docs when available.
* Do not add yourself as a co-author or add any assisted-by, co-developed-by or similar trailer to commits.
* Leave the commit message and replies to review comments to the human author, and remind them to disclose AI use in the PR description.
