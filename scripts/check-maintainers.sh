#!/usr/bin/env bash

# Make sure sort works predictably.
export LC_ALL=C

cat <<EOF
# Maintainers

## General maintainers

- Jan-Otto Kröpke (<github@jkroepke.de> / @jkroepke)
- Sheikh-Abubaker (<sheikhabubaker761@gmail.com> / @Sheikh-Abubaker)
- Aviv Guiser (<avivguiser@gmail.com> / @KyriosGN0)
- Quentin Bisson (<quentin@giantswarm.io> / @QuentinBisson)
- TheRealNoob (<mike1118@live.com> / @TheRealNoob)

## GitHub Workflows & Renovate maintainers

- Jan-Otto Kröpke (<github@jkroepke.de> / @jkroepke)
- TheRealNoob (<mike1118@live.com> / @TheRealNoob)

## Helm charts maintainers
EOF

yq_script='"\n### " + .name + "\n\n" + ([.maintainers[] | "- " + .name + " (" + (("<" + .email + ">") // "unknown") + " / " + (.url | sub("https://github.com/", "@") + ")")] | sort | join("\n"))'
yq e "${yq_script}" charts/*/Chart.yaml
