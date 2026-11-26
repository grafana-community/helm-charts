#!/usr/bin/env bash
# Reduce GitHub-generated release notes to the pull requests of one chart.
#
# GitHub generates release notes from all pull requests merged between the
# previous and the current tag. In this repository the tags of all charts share
# one history, so every release lists the pull requests of every chart. Pull
# request titles start with the chart name (e.g. "[grafana] ..."), which this
# script uses to keep only the entries that belong to the released chart.
#
# Usage: filter-release-notes.sh <chart-name> < notes.md > filtered.md

set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
  echo "Usage: $0 <chart-name> < notes.md" >&2
  exit 1
fi

awk -v chart="$1" '
  function flush_section() {
    if (section == "") {
      return
    }
    if (kept > 0) {
      printf "%s", buffer
    }
    section = ""
    buffer = ""
    kept = 0
  }

  # PR URL at the end of a generated entry: "... in https://github.com/o/r/pull/1".
  function pr_url(line) {
    if (match(line, / in https:\/\/[^ ]+\/pull\/[0-9]+$/)) {
      return substr(line, RSTART + 4, RLENGTH - 4)
    }
    return ""
  }

  /^## / {
    flush_section()
    if ($0 == "## What'"'"'s Changed") {
      section = "changes"
    } else if ($0 == "## New Contributors") {
      section = "contributors"
    }
    if (section != "") {
      buffer = $0 "\n"
      next
    }
  }

  /^\*\*Full Changelog\*\*/ {
    flush_section()
  }

  section == "changes" && /^\* / {
    if (index($0, "* [" chart "] ") == 1) {
      url = pr_url($0)
      if (url != "") {
        prs[url] = 1
      }
      buffer = buffer $0 "\n"
      kept++
    }
    next
  }

  section == "contributors" && /^\* / {
    url = pr_url($0)
    if (url != "" && (url in prs)) {
      buffer = buffer $0 "\n"
      kept++
    }
    next
  }

  section != "" {
    buffer = buffer $0 "\n"
    next
  }

  { print }

  END { flush_section() }
'
