# Usage

## New Configuration Syntax

Since Version X.Y.Z, the loki helm chart offers a new configuration syntax. The new syntax is more consistent and easier to use. The old syntax is still supported, but it is recommended to switch to the new syntax.

The new configuration syntax is based on the [Loki configuration file format](https://grafana.com/docs/loki/latest/configure/). If `newConfig` is set to `true`, the chart will use the new configuration syntax. If `newConfig` is set to `false`, the chart will use the old configuration syntax.

Note: The new configuration syntax will not use any existing configuration values set in the old syntax. If you want to use the new configuration syntax, you will need to migrate your existing configuration values to the new syntax. 
Any values under `loki.config`, `loki.memberlistConfig`,`loki.storage`,`loki.structuredConfig`,`loki.commonConfig`, `chunksCache`, `resultsCache`, `resultsCache` will be ignored when `newConfig` is set to `true`. All configuration values must be set explicit under `loki.config` when `newConfig` is set to `true`.

The `extraConfig` value can be used to add additional templated configuration values. `config` and `extraConfig` will be merged, with `extraConfig` taking precedence over `config`.
