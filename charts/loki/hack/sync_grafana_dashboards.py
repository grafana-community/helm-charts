#!/usr/bin/env python3
"""Fetch dashboards from provided urls into this chart."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import textwrap

import _jsonnet
import requests
import yaml
from yaml.representer import SafeRepresenter


# https://stackoverflow.com/a/20863889/961092
class LiteralStr(str):
    pass


def change_style(style, representer):
    def new_representer(dumper, data):
        scalar = representer(dumper, data)
        scalar.style = style
        return scalar

    return new_representer


refs = {
    # renovate: github=grafana/loki
    'ref.loki': 'v3.7.1',
}

# Source files list
charts = [
    {
        'git': 'https://github.com/grafana/loki.git',
        'branch': refs['ref.loki'],
        'content': "(import 'dashboards.libsonnet') + (import 'config.libsonnet') + {_config+:: { horizontally_scalable_compactor_enabled: false, internal_components: false, meta_monitoring+: { enabled: true }, promtail+: { enabled: false }, ssd+: { enabled: false, pod_prefix_matcher: 'loki.*' }}}",
        'cwd': 'production/loki-mixin',
        'destination': '../templates/monitoring/dashboards',
        'type': 'jsonnet_mixin',
        'mixin_vars': {},
        'multicluster_key': '.Values.monitoring.multiCluster.enabled',
    },
]

# Additional conditions map
condition_map = {}
replacement_map = {
    '($namespace)/(bloom-gateway': {
        'replacement': '($namespace)/(.*-bloom-gateway',
    },
    '($namespace)/(distributor': {
        'replacement': '($namespace)/(.*-distributor',
    },
    '($namespace)/(querier': {
        'replacement': '($namespace)/(.*-querier',
    },
    '($namespace)/(index-gateway': {
        'replacement': '($namespace)/(.*-index-gateway',
    },
    '($namespace)/(query-frontend': {
        'replacement': '($namespace)/(.*-query-frontend',
    },
    '($namespace)/(partition-ingester.*|ingester.*': {
        'replacement': '($namespace)/(.*-partition-ingester.*|.*-ingester.*',
    },
    '($namespace)/(partition-ingester-.*|ingester-zone-.*': {
        'replacement': '($namespace)/(.*-partition-ingester|.*-ingester',
    },
    'ingester-zone-.*': {
        'replacement': '.*-ingester',
    },
    '($namespace)/bloom-gateway': {
        'replacement': '($namespace)/.*-bloom-gateway',
    },
    '($namespace)/query-frontend': {
        'replacement': '($namespace)/.*-query-frontend',
    },
    '($namespace)/query-scheduler': {
        'replacement': '($namespace)/.*-query-scheduler',
    },
    '($namespace)/distributor': {
        'replacement': '($namespace)/.*-distributor',
    },
    '($namespace)/ruler': {
        'replacement': '($namespace)/.*-ruler',
    },
    '($namespace)/querier': {
        'replacement': '($namespace)/.*-querier',
    },
    'loki.*-write': {
        'replacement': '.*-write',
    },
    'loki.*-read': {
        'replacement': '.*-read',
    },
    'loki.*-backend': {
        'replacement': '.*-backend',
    },
    '*.index-gateway': {
        'replacement': '.*index-gateway',
    },
    '\\"(.*compactor|.*-backend.*|loki-single-binary)\\"': {
        'replacement': '(.*-compactor|.*-backend.*|loki-single-binary)',
    },
    'loki-single-binary': {
        'replacement': '`}}{{ include "loki.resourceName" (dict "ctx" $) }}{{`',
    },
    # Upstream uses "cluster" for Loki instance identity. We keep "cluster" for k8s cluster
    # and add appInstanceLabelName alongside it for Loki instance selection.
    # Variable name/label placeholder (set in patch_dashboards_json).
    ':appInstanceLabelName:': {
        'replacement': '`}}{{ $.Values.monitoring.appInstanceLabelName }}{{`',
    },
    # Label selectors: conditionally keep cluster filter, always add app_instance filter.
    'cluster=\\"$cluster\\"': {
        'replacement': '`}}{{ if .Values.monitoring.multiCluster.enabled }}{{`cluster=\\"$cluster\\", `}}{{ end }}{{ $.Values.monitoring.appInstanceLabelName }}{{`=\\"$`}}{{ $.Values.monitoring.appInstanceLabelName }}{{`\\"',
    },
    'cluster=~\\"$cluster\\"': {
        'replacement': '`}}{{ if .Values.monitoring.multiCluster.enabled }}{{`cluster=~\\"$cluster\\", `}}{{ end }}{{ $.Values.monitoring.appInstanceLabelName }}{{`=~\\"$`}}{{ $.Values.monitoring.appInstanceLabelName }}{{`\\"',
    },
    # by() clauses: conditionally keep cluster, always add app_instance.
    'cluster, ': {
        'replacement': '`}}{{ if .Values.monitoring.multiCluster.enabled }}{{`cluster, `}}{{ end }}{{ $.Values.monitoring.appInstanceLabelName }}{{`, ',
    },
}

# standard header
header = '''{{- /*
Generated from '%(name)s' from %(url)s
Do not change in-place! In order to change this file first read following link:
https://github.com/grafana-community/helm-charts/tree/main/charts/loki/hack
*/ -}}
{{- if and .Values.monitoring.dashboards.enabled (dig "%(name)s" "enabled" true .Values.monitoring.dashboards) %(condition)s }}%(init_line)s
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "loki.resourceName" (dict "ctx" $ "component" "dashboards" "suffix" "%(name)s") }}
  namespace: {{ .Values.monitoring.namespace | default (include "loki.namespace" $) }}
  labels:
    {{- include "loki.labels" $ | nindent 4 }}
    {{- with .Values.monitoring.dashboards.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.monitoring.dashboards.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
data:
'''

    # Add GrafanaDashboard custom resource
grafana_dashboard_operator = """
---
{{- if and .Values.monitoring.dashboards.enabled .Values.monitoring.dashboards.grafanaOperator.enabled (dig "%(name)s" "enabled" true .Values.monitoring.dashboards) %(condition)s }}
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: {{ include "loki.resourceName" (dict "ctx" $ "component" "dashboards" "suffix" "%(name)s") }}
  namespace: {{ .Values.monitoring.namespace | default (include "loki.namespace" $) }}
  {{- with (mergeOverwrite dict .Values.monitoring.dashboards.annotations .Values.monitoring.dashboards.grafanaOperator.annotations) }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "loki.labels" $ | nindent 4 }}
    {{- with (mergeOverwrite dict .Values.monitoring.dashboards.labels .Values.monitoring.dashboards.grafanaOperator.labels) }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  allowCrossNamespaceImport: true
  resyncPeriod: {{ .Values.monitoring.dashboards.grafanaOperator.resyncPeriod | default "10m" | quote }}
  {{- include "loki.grafana.operator.folder" $ | nindent 2 }}
  instanceSelector:
    matchLabels:
      {{- include "loki.selectorLabels" $ | nindent 6 }}
      {{- with .Values.monitoring.dashboards.labels }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
  configMapRef:
    name: {{ include "loki.resourceName" (dict "ctx" $ "component" "dashboards" "suffix" "%(name)s") }}
    key: %(name)s.json
{{- end }}
"""

def init_yaml_styles():
    represent_literal_str = change_style('|', SafeRepresenter.represent_str)
    yaml.add_representer(LiteralStr, represent_literal_str)


def yaml_str_repr(struct, indent=2):
    """represent yaml as a string"""
    text = yaml.dump(
        struct,
        width=1000,  # to disable line wrapping
        default_flow_style=False  # to disable multiple items on single line
    )
    text = textwrap.indent(text, ' ' * indent)
    return text


def replace_nested_key(data, key, value, replace):
    if isinstance(data, dict):
        return {
            k: replace if k == key and v == value else replace_nested_key(v, key, value, replace)
            for k, v in data.items()
        }
    elif isinstance(data, list):
        return [replace_nested_key(v, key, value, replace) for v in data]
    else:
        return data


def patch_dashboards_json(content, multicluster_key):
    try:
        content_struct = json.loads(content)

        # multicluster
        cluster_var_json = None
        overwrite_list = []
        for variable in content_struct['templating']['list']:
            if variable['name'] == 'cluster':
                # Upstream uses "cluster" to mean "Loki instance". We split it into two variables:
                # 1. "cluster" for k8s cluster selection — only present when multiCluster enabled.
                #    Serialized separately and injected as a Helm conditional after json.dumps.
                cluster_var_json = json.dumps(variable, separators=(',', ':'))
                cluster_var_json = cluster_var_json.replace('`', '`}}`{{`')
                overwrite_list.append(':CLUSTER_VAR:')
                # 2. "app_instance" for Loki instance selection — always visible.
                #    Uses :appInstanceLabelName: placeholder replaced by replacement_map.
                app_instance_var = variable.copy()
                app_instance_var['name'] = ':appInstanceLabelName:'
                app_instance_var['label'] = ':appInstanceLabelName:'
                app_instance_var['query'] = 'label_values(loki_build_info, :appInstanceLabelName:)'
                app_instance_var['hide'] = 0
                app_instance_var.pop('allValue', None)
                overwrite_list.append(app_instance_var)
                continue
            overwrite_list.append(variable)
        content_struct['templating']['list'] = overwrite_list

        # Replace decimals=-1 with decimals= (nil value)
        # ref: https://github.com/kubernetes-monitoring/kubernetes-mixin/pull/859
        content_struct = replace_nested_key(content_struct, "decimals", -1, None)

        content = json.dumps(content_struct, separators=(',', ':'))
        content = content.replace('`', '`}}`{{`')
        # Inject cluster variable conditionally — present only when multiCluster enabled
        if cluster_var_json:
            content = content.replace(
                '":CLUSTER_VAR:",',
                '`}}{{ if %s }}{{`%s,`}}{{ end }}{{`' % (multicluster_key, cluster_var_json),
            )
        init_line = ''

        for line in replacement_map:
            if line in content and replacement_map[line].get('init'):
                init_line += '\n' + replacement_map[line]['init']
            content = content.replace(line, replacement_map[line]['replacement'])
    except (ValueError, KeyError) as e:
        print("WARNING: Failed to patch dashboard JSON: %s" % e)

    return init_line, "{{`" + content + "`}}"


def patch_json_set_timezone_as_variable(content):
    # content is no more in json format, so we have to replace using regex
    return re.sub(r'"timezone"\s*:\s*"(?:\\.|[^\"])*"', '"timezone": "`}}{{ .Values.monitoring.dashboards.defaultDashboardsTimezone }}{{`"', content, flags=re.IGNORECASE)


def patch_json_set_editable_as_variable(content):
    # content is no more in json format, so we have to replace using regex
    return re.sub(r'"editable"\s*:\s*(?:true|false)', '"editable":`}}{{ .Values.monitoring.dashboards.defaultDashboardsEditable }}{{`', content, flags=re.IGNORECASE)


def patch_json_set_interval_as_variable(content):
    # content is no more in json format, so we have to replace using regex
    return re.sub(r'"interval"\s*:\s*"(?:\\.|[^\"])*"', '"interval":"`}}{{ .Values.monitoring.dashboards.defaultDashboardsInterval }}{{`"', content, flags=re.IGNORECASE)

def jsonnet_import_callback(base, rel):
    # rel_base is the path relative to the current cwd.
    # see https://github.com/prometheus-community/helm-charts/issues/5283
    # for more details.

    rel_base = base
    if rel_base.startswith(os.getcwd()):
        rel_base = base[len(os.getcwd()):]

    if "github.com" in rel:
        base = os.getcwd() + '/vendor/'
    elif "github.com" in rel_base:
        base = os.getcwd() + '/vendor/' + rel_base[rel_base.find('github.com'):]

    # Try progressively reducing `base` up the directory tree (parent
    # directories) on each attempt until `base` becomes empty. Also attempt
    # the empty `base` once so that a plain relative `rel` is checked.
    tried = []
    # Normalize base to '' or a path ending with a single os.sep when non-empty
    if base:
        base = base.replace(os.sep * 2, os.sep)
        if not base.endswith(os.sep):
            base = base + os.sep

    while True:
        # Build candidate using os.path.join so behavior is correct for
        # absolute and relative paths.
        candidate = os.path.join(base, rel) if base else None
        if candidate:
            tried.append(candidate)
            if os.path.isfile(candidate):
                return candidate, Path(candidate).read_text().encode('utf-8')

        # If base is empty, also try the repository vendor/ path once
        # (so 'vendor/<rel>' is checked). This handles imports that live in
        # the vendored dependencies.
        if not base:
            vendor_candidate = os.path.join(os.getcwd(), 'vendor', rel)
            tried.append(vendor_candidate)
            if os.path.isfile(vendor_candidate):
                return vendor_candidate, open(vendor_candidate).read().encode('utf-8')

            # Also try the plain relative path (rel) in the current cwd.
            plain_candidate = rel
            tried.append(plain_candidate)
            if os.path.isfile(plain_candidate):
                return plain_candidate, open(plain_candidate).read().encode('utf-8')

            # We've tried empty base (vendor and plain rel), stop looping.
            break

        # Move `base` one directory up. Use rstrip to remove trailing
        # separators before dirname, then re-append a separator if result
        # is non-empty. If dirname returns root (e.g., '/'), convert to ''
        # after trying root once to avoid infinite loops.
        parent = os.path.dirname(base.rstrip(os.sep))
        if not parent or parent == os.sep:
            # Next iteration should try empty base and then stop.
            base = ''
        else:
            base = parent + os.sep

    # Fall back to a not-found error with helpful debug information.
    raise RuntimeError('File not found (tried: {})'.format(', '.join(tried)))

def write_group_to_file(resource_name, content, url, destination, multicluster_key):
    init_line, content = patch_dashboards_json(content, multicluster_key)

    # initialize header
    lines = header % {
        'name': resource_name,
        'url': url,
        'condition': condition_map.get(resource_name, ''),
        'init_line': init_line,
    }

    content = patch_json_set_timezone_as_variable(content)
    content = patch_json_set_editable_as_variable(content)
    content = patch_json_set_interval_as_variable(content)

    filename_struct = {resource_name + '.json': (LiteralStr(content))}
    # rules themselves
    lines += yaml_str_repr(filename_struct)

    # footer
    lines += '{{- end }}'

    lines_grafana_operator = grafana_dashboard_operator % {
        'name': resource_name,
        'condition': condition_map.get(resource_name, '')
    }

    lines += lines_grafana_operator

    filename = resource_name + '.yaml'
    new_filename = "%s/%s" % (destination, filename)

    # make sure directories to store the file exist
    os.makedirs(destination, exist_ok=True)

    # recreate the file
    with open(new_filename, 'w') as f:
        f.write(lines)

    print("Generated %s" % new_filename)


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    init_yaml_styles()
    # read the rules, create a new template file per group
    for chart in charts:
        if 'git' in chart:
            if 'source' not in chart:
                chart['source'] = '_mixin.jsonnet'

            url = chart['git']

            print("Clone %s" % chart['git'])
            checkout_dir = os.path.basename(chart['git'])
            shutil.rmtree(checkout_dir, ignore_errors=True)

            branch = "main"
            if 'branch' in chart:
                branch = chart['branch']

            subprocess.run(["git", "init", "--initial-branch", "main", checkout_dir, "--quiet"])
            subprocess.run(["git", "-C", checkout_dir, "remote", "add", "origin", chart['git']])
            subprocess.run(["git", "-C", checkout_dir, "fetch", "--depth", "1", "origin", branch, "--quiet"])
            subprocess.run(["git", "-c", "advice.detachedHead=false", "-C", checkout_dir, "checkout", "FETCH_HEAD", "--quiet"])
            print("Generating rules from %s" % chart['source'])

            mixin_file = chart['source']
            mixin_dir = checkout_dir + '/' + chart['cwd'] + '/'
            if os.path.exists(mixin_dir + "jsonnetfile.json"):
                print("Running jsonnet-bundler, because jsonnetfile.json exists")
                subprocess.run(["jb", "install"], cwd=mixin_dir)

            if 'content' in chart:
                f = open(mixin_dir + mixin_file, "w")
                f.write(chart['content'])
                f.close()

            mixin_vars = json.dumps(chart['mixin_vars'])

            cwd = os.getcwd()
            os.chdir(mixin_dir)
            raw_text = '((import "%s") + %s)' % (mixin_file, mixin_vars)
            source = os.path.basename(mixin_file)
        elif 'source' in chart and chart['source'].startswith('http'):
            print("Generating rules from %s" % chart['source'])
            response = requests.get(chart['source'])
            if response.status_code != 200:
                print('Skipping the file, response code %s not equals 200' % response.status_code)
                continue
            raw_text = response.text
            source = chart['source']
            url = chart['source']
        else:
            with open(chart['source']) as f:
                raw_text = f.read()

            source = chart['source']
            url = chart['source']

        if ('max_kubernetes' not in chart):
            chart['max_kubernetes']="9.9.9-9"

        if chart['type'] == 'yaml':
            yaml_text = yaml.full_load(raw_text)
            groups = yaml_text['items']
            for group in groups:
                for resource, content in group['data'].items():
                    write_group_to_file(resource.replace('.json', ''), content, url, chart['destination'], chart['multicluster_key'])
        elif chart['type'] == 'jsonnet_mixin':
            json_text = json.loads(_jsonnet.evaluate_snippet(source, raw_text + '.grafanaDashboards', import_callback=jsonnet_import_callback))

            if 'git' in chart:
                os.chdir(cwd)
            # is it already a dashboard structure or is it nested (etcd case)?
            flat_structure = bool(json_text.get('annotations'))
            if flat_structure:
                resource = os.path.basename(chart['source']).replace('.json', '')
                write_group_to_file(resource, json.dumps(json_text, indent=4), url, chart['destination'], chart['multicluster_key'])
            else:
                for resource, content in json_text.items():
                    write_group_to_file(resource.replace('.json', ''), json.dumps(content, indent=4), url, chart['destination'], chart['multicluster_key'])
        elif chart['type'] == 'dashboard_json':
            write_group_to_file(os.path.basename(source).replace('.json', ''),
                                raw_text, url, chart['destination'], chart['multicluster_key'])


print("Finished")


if __name__ == '__main__':
    main()
