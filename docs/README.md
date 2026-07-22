# helm-docs WebAssembly table renderer

This directory contains a browser-only values table renderer built from a fork of `helm-docs`.

Fork details from this checkout:

- Branch: `wasm`
- Remote: `https://github.com/jkroepke/helm-docs`

The page uses Go WebAssembly to reuse the forked `helm-docs` values parsing and HTML table rendering logic in the browser. It fetches a chart `values.yaml` from GitHub, renders only the values table, and does not provide an input field.

## URL format

Production GitHub Pages URL:

```text
https://<org>.github.io/<repo>/docs/?chart=<chart>
```

Example:

```text
https://grafana-community.github.io/helm-charts/docs/?chart=loki
```

The page resolves that to:

```text
https://raw.githubusercontent.com/<org>/<repo>/refs/heads/main/charts/<chart>/values.yaml
```

For the example above, it fetches:

```text
https://raw.githubusercontent.com/grafana-community/helm-charts/refs/heads/main/charts/loki/values.yaml
```

## Local development

Build and serve the page:

```bash
make wasm-serve
```

Open:

```text
http://localhost:8080/?org=grafana-community&chart=loki
```

On localhost only, the page accepts `org` as a query parameter. It also accepts `repo`; when omitted, `repo` defaults to `helm-charts` for the root local server path.

Generated files are intentionally ignored:

- `web/wasm/helm-docs.wasm`
- `web/wasm/wasm_exec.js`
