---
name: helm-values-schema
description: Maintain values.schema.json for Helm charts that use helm-values-schema-json annotations in values.yaml.
user_invocable: true
---

# /helm-values-schema [chart]

Use this skill when the user asks to add, change, review, or regenerate a Helm chart `values.schema.json`, or when a chart feature changes `values.yaml` in a chart that uses schema annotations.

## Detection

A chart uses `helm-values-schema-json` if `charts/<chart>/values.yaml` contains either:

- `# @schema` comments
- a top-level schema reference such as `# $schema: ./values.schema.json`

When a chart uses this flow, changes to `values.yaml` must keep schema annotations and `values.schema.json` in sync.

## Documentation

Prefer Context7 for current `helm-values-schema-json` docs when available.

Upstream documentation:

```text
https://github.com/losisin/helm-values-schema-json/blob/main/docs/README.md
```

## Compatibility

Helm validates chart values with JSON Schema draft-07. Keep generated schemas compatible with draft-07 even if external schema tooling supports newer drafts.

## Workflow

1. Read `charts/<chart>/values.yaml`.
2. Check whether `# @schema` annotations or `# $schema: ./values.schema.json` are present.
3. If changing or adding values, preserve nearby annotations and add annotations when inferred schema would be wrong or too loose.
4. Preserve helm-docs comments. When a field has both `# @schema` and helm-docs `# --` comments, `# @schema` comments must be above the helm-docs description comments.
5. Regenerate `values.schema.json`.
6. Review the schema diff for only intentional changes.
7. Ensure values changes also have helm-unittest coverage for rendered behavior where applicable.

## helm-docs Integration

`helm-values-schema-json` supports using descriptions from `helm-docs` comments since v2.0.0, but only when enabled with `--use-helm-docs`.

Example:

```bash
helm schema --use-helm-docs
```

```yaml
# -- My description
fullnameOverride: bar
```

Generates:

```json
{
  "fullnameOverride": {
    "description": "My description",
    "type": "string"
  }
}
```

### Unsupported helm-docs Features

The schema plugin does not support helm-docs-specific properties such as:

- `# @default --`
- `# @section --`

It also does not support detached helm-docs comments. Comments must be directly above the property or inline in a supported form.

Supported:

```yaml
# fullnameOverride -- This works
fullnameOverride: bar
```

Not supported by the schema plugin:

```yaml
fullnameOverride: bar

# fullnameOverride -- This does not work for schema generation.
fullnameOverride: bar
```

Helm-docs itself does not understand `# @schema` comments. When both `# @schema` and helm-docs comments are above a field, put `# @schema` first so schema annotations are not included in the generated description. Treat the inverse order as invalid: helm-docs will include the schema annotation text in the description.

Good:

```yaml
# @schema maxLength:10
# -- My awesome nameOverride description
nameOverride: "myapp"
```

Bad:

```yaml
# -- My awesome nameOverride description
# @schema maxLength:10
nameOverride: "myapp"
```

## Annotation Placement

`# @schema` annotations may be placed inline, on the line above a field, or in specific cases below a block. Preserve the surrounding style already used in the chart, except when the existing style conflicts with helm-docs ordering. If a value has a helm-docs `# --` description, any standalone `# @schema` comments for that value must be above the `# --` comment, never between the helm-docs comment and the value.

Examples:

```yaml
fullnameOverride: "myapp" # @schema maxLength:10;pattern:^[a-z]+$

# @schema maxLength:10;pattern:^[a-z]+$
nameOverride: "myapp"

# @schema maxLength:10
# -- My awesome nameOverride description
nameOverride: "myapp"

# Invalid with helm-docs: the schema annotation becomes part of the description.
# -- My awesome nameOverride description
# @schema maxLength:10
nameOverride: "myapp"

resources:
  limits: {}
  requests: {}
# @schema additionalProperties:false
```

Multiple schema annotations can be separated with semicolons.

## Commands

Use the repository target:

```bash
make helm-schema HELM_CHART=<chart-name>
```

The target only regenerates charts whose `values.yaml` contains `# $schema: ./values.schema.json`. For each such chart it runs:

```bash
helm schema --config .github/linters/.schema.yaml -f charts/<chart-name>/values.yaml -o charts/<chart-name>/values.schema.json
```

When enabling the schema for another chart, add the `# $schema: ./values.schema.json` header to `values.yaml` and a `charts/<chart-name>/ci/lint.sh` that runs the target and fails on a diff (see `charts/loki/ci/lint.sh`).

## Known Caveats

Inferred types are often too strict. Each of these needed a follow-up fix in Loki:

- Values whose default is `null` infer `"type": "null"` and reject everything else. Always annotate them, e.g. `type:[string, null]`.
- Replica counts that may be omitted for HPA/KEDA need `type:[integer, null]`.
- PodDisruptionBudget `minAvailable`/`maxUnavailable` and rollout `maxSurge`/`maxUnavailable` accept percentages: `type:[string, integer, null]`.
- Durations and Kubernetes quantities accept strings and numbers: `type:[string, integer]` (or `number` for fractional CPU).
- Use `integer`, not `number`, for counts and ports.
- Kubernetes objects with non-empty defaults (probes, security contexts, strategies) and free-form config maps need `skipProperties:true;additionalProperties:true`, otherwise default sub-keys get pinned to their inferred type (e.g. a probe `port: http` rejects `port: 3000`).
- Label and annotation maps are rendered with `toYaml`, so constrain them with `additionalProperties:{"type":"string"}`. Env maps rendered through `quote` must stay unconstrained.
- Check the template before choosing a type: values passed through `tpl` must be strings, values passed through `join` accept a string or a list.
- helm-unittest validates `set` values against the schema, so tests that deliberately pass wrong types must be removed or turned into `failedTemplate` assertions.
- helm-unittest `set` cannot address top-level keys containing a dot (e.g. `grafana.ini`).

## Rules

- Do not hand-edit `values.schema.json` when it can be regenerated.
- Do not remove existing `# @schema` annotations unless the associated value is removed.
- Keep schema annotations as close as possible to the value they describe.
- Keep `# @schema` comments above helm-docs `# --` comments. Never add a standalone `# @schema` comment below a helm-docs description comment for the same value.
- Include regenerated `values.schema.json` in the change.
- Values changes that affect rendered manifests should also be covered by helm-unittest tests.
