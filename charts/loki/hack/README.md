# loki charts hacks

## [update_mixins.sh](update_mixins.sh)

This script is a useful wrapper to run `sync_grafana_dashboards.py`.

It clones all dependency dashboards into a tmp folder.

And it lets you know if you are missing commandline-tools necessary for the
update to complete.

Therefore, if you want to create a PR that updates the mixins, please
run `./hack/update_mixins.sh` from the charts directory
(`./charts/loki`).

## [sync_grafana_dashboards.py](sync_grafana_dashboards.py)

This script generates grafana dashboards from JSON files, splitting them to separate files based on group name.

List of imported dashboards:

- [grafana/loki](https://github.com/grafana/loki/tree/main/production/loki-mixin) dashboards.
    - In order to modify these dashboards:
        - prepare and merge PR into [loki-mixin](https://github.com/grafana/loki/tree/main/production/loki-mixin) main and/or release branch.
        - run sync_grafana_dashboards.py inside your fork of this repository
        - send PR with changes to this repository
