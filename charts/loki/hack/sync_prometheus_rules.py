#!/usr/bin/env python3
"""Fetch alerting and aggregation rules from provided urls into this chart."""
import json
import os
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
    # renovate: github=docker.io/grafana/loki
    'ref.loki': 'v3.7.0',
}

# Source files list
charts = [
    {
        'git': 'https://github.com/grafana/loki.git',
        'branch': refs['ref.loki'],
        'source': 'mixin.libsonnet',
        'cwd': 'production/loki-mixin',
        'destination': '../templates/monitoring/rules',
        'mixin': """
        ((import 'recording_rules.libsonnet') + (import 'config.libsonnet') + {_config+:: { horizontally_scalable_compactor_enabled: false, internal_components: false, meta_monitoring+: { enabled: true }, promtail+: { enabled: false }, ssd+: { enabled: false, pod_prefix_matcher: 'loki.*' }}}).prometheusRules
        """
    },
]

# Additional conditions map
condition_map = {}

alert_condition_map = {}

replacement_map = {}

# standard header
header = '''{{- /*
Generated from '%(name)s' group from %(url)s
Do not change in-place! In order to change this file first read following link:
https://github.com/grafana-community/helm-charts/tree/main/charts/loki/hack
*/ -}}
{{- if and .Values.monitoring.rules.enabled%(condition)s }}%(init_line)s
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: {{ printf "%%s-%%s" (include "loki.fullname" .) "%(name)s" | trunc 63 | trimSuffix "-" }}
  namespace: {{ .Values.monitoring.rules.namespace | default (include "loki.namespace" $) }}
  labels:
    {{- include "loki.labels" $ | nindent 4 }}
    {{- with .Values.monitoring.rules.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.monitoring.rules.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  groups:
  -'''


def init_yaml_styles():
    represent_literal_str = change_style('|', SafeRepresenter.represent_str)
    yaml.add_representer(LiteralStr, represent_literal_str)


def escape(s):
    return s.replace("{{", "{{`{{").replace("}}", "}}`}}").replace("{{`{{", "{{`{{`}}").replace("}}`}}", "{{`}}`}}")


def fix_expr(rules):
    """Remove trailing whitespaces and line breaks, which happen to creep in
     due to yaml import specifics;
     convert multiline expressions to literal style, |-"""
    for rule in rules:
        rule['expr'] = rule['expr'].rstrip()
        if '\n' in rule['expr']:
            rule['expr'] = LiteralStr(rule['expr'])


def yaml_str_repr(struct, indent=4):
    """represent yaml as a string"""
    text = yaml.dump(
        struct,
        width=1000,  # to disable line wrapping
        default_flow_style=False  # to disable multiple items on single line
    )
    text = escape(text)  # escape {{ and }} for helm
    text = textwrap.indent(text, ' ' * indent)[indent - 1:]  # indent everything, and remove very first line extra indentation
    return text


def get_rule_group_condition(group_name, value_key):
    if group_name == '':
        return ''

    if group_name.count(".Values") > 1:
        group_name = group_name.split(' ')[-1]

    return group_name.replace('Values.defaultRules.rules', f"Values.defaultRules.{value_key}").strip()


def add_rules_conditions(rules, rules_map, indent=4):
    """Add if wrapper for rules, listed in rules_map"""
    rule_condition = '{{- if %s }}\n'
    for alert_name in rules_map:
        line_start = ' ' * indent + '- alert: '
        if line_start + alert_name in rules:
            rule_text = rule_condition % rules_map[alert_name]
            start = 0
            # to modify all alerts with same name
            while True:
                try:
                    # add if condition
                    index = rules.index(line_start + alert_name, start)
                    start = index + len(rule_text) + 1
                    rules = rules[:index] + rule_text + rules[index:]
                    # add end of if
                    try:
                        next_index = rules.index(line_start, index + len(rule_text) + 1)
                    except ValueError:
                        # we found the last alert in file if there are no alerts after it
                        next_index = len(rules)

                    # depending on the rule ordering in rules_map it's possible that an if statement from another rule is present at the end of this block.
                    found_block_end = False
                    last_line_index = next_index
                    while not found_block_end:
                        last_line_index = rules.rindex('\n', index, last_line_index - 1)  # find the starting position of the last line
                        last_line = rules[last_line_index + 1:next_index]

                        if last_line.startswith('{{- if'):
                            next_index = last_line_index + 1  # move next_index back if the current block ends in an if statement
                            continue

                        found_block_end = True
                    rules = rules[:next_index] + '{{- end }}\n' + rules[next_index:]
                except ValueError:
                    break
    return rules


def add_rules_conditions_from_condition_map(rules, indent=4):
    """Add if wrapper for rules, listed in alert_condition_map"""
    rules = add_rules_conditions(rules, alert_condition_map, indent)
    return rules


def add_rules_per_rule_conditions(rules, group, indent=4):
    """Add if wrapper for rules, listed in alert_condition_map"""
    rules_condition_map = {}
    for rule in group['rules']:
        if 'alert' in rule:
            rules_condition_map[rule['alert']] = f"not (.Values.defaultRules.disabled.{rule['alert']} | default false)"

    rules = add_rules_conditions(rules, rules_condition_map, indent)
    return rules


def add_custom_labels(rules_str, group, indent=4, label_indent=2):
    """Add if wrapper for additional rules labels"""
    rule_group_labels = get_rule_group_condition(condition_map.get(group['name'], ''), 'additionalRuleGroupLabels')

    additional_rule_labels = textwrap.indent("""
{{- with .Values.monitoring.rules.additionalRuleLabels }}
  {{- toYaml . | nindent 8 }}
{{- end }}""", " " * (indent + label_indent * 2))

    additional_rule_labels_condition_start = "\n" + " " * (indent + label_indent) + '{{- if or $.Values.monitoring.rules.additionalRuleLabels %s }}' % (rule_group_labels,)
    additional_rule_labels_condition_end = "\n" + " " * (indent + label_indent) + '{{- end }}'
    # labels: cannot be null, if a rule does not have any labels by default, the labels block
    # should only be added if there are .Values.monitoring.rules.additionalRuleLabels defined
    rule_seperator = "\n" + " " * indent + "-.*"
    label_seperator = "\n" + " " * indent + "  labels:"
    section_seperator = "\n" + " " * indent + "  \\S"
    section_seperator_len = len(section_seperator)-1
    rules_positions = re.finditer(rule_seperator,rules_str)

    # fetch breakpoint between each set of rules
    ruleStartingLine = [(rule_position.start(),rule_position.end()) for rule_position in rules_positions]
    head = rules_str[:ruleStartingLine[0][0]]

    # construct array of rules so they can be handled individually
    rules = []
    # pylint: disable=E1136
    # See https://github.com/pylint-dev/pylint/issues/1498 for None Values
    previousRule = None
    for r in ruleStartingLine:
         if previousRule != None:
             rules.append(rules_str[previousRule[0]:r[0]])
         previousRule = r
    rules.append(rules_str[previousRule[0]:len(rules_str)-1])

    for i, rule in enumerate(rules):
        current_label = re.search(label_seperator,rule)
        if current_label:
            # `labels:` block exists
            # determine if there are any existing entries
            entries = re.search(section_seperator,rule[current_label.end():])
            if entries:
                entries_start = current_label.end()
                entries_end = entries.end()+current_label.end()-section_seperator_len
                rules[i] = rule[:entries_end] + additional_rule_labels_condition_start + additional_rule_labels + additional_rule_labels_condition_end + rule[entries_end:]
            else:
                # `labels:` does not contain any entries
                # append template to label section
                rules[i] += additional_rule_labels_condition_start + additional_rule_labels + additional_rule_labels_condition_end
        else:
            # `labels:` block does not exist
            # create it and append template
            rules[i] += additional_rule_labels_condition_start + "\n" + " " * indent + "  labels:" + additional_rule_labels + additional_rule_labels_condition_end
    return head + "".join(rules) + "\n"


def add_custom_annotations(rules, group, indent=4):
    """Add if wrapper for additional rules annotations"""
    rule_condition = '{{- if .Values.defaultRules.additionalRuleAnnotations }}\n{{ toYaml .Values.defaultRules.additionalRuleAnnotations | indent 8 }}\n{{- end }}'
    rule_group_labels = get_rule_group_condition(condition_map.get(group['name'], ''), 'additionalRuleGroupAnnotations')
    rule_group_condition = '\n{{- if %s }}\n{{ toYaml %s | indent 8 }}\n{{- end }}' % (rule_group_labels, rule_group_labels)
    annotations = "      annotations:"
    annotations_len = len(annotations) + 1
    rule_condition_len = len(rule_condition) + 1
    rule_group_condition_len = len(rule_group_condition)

    separator = " " * indent + "- alert:.*"
    alerts_positions = re.finditer(separator,rules)
    alert = 0

    for alert_position in alerts_positions:
        # Add rule_condition after 'annotations:' statement
        index = alert_position.end() + annotations_len + (rule_condition_len + rule_group_condition_len) * alert
        rules = rules[:index] + "\n" + rule_condition + rule_group_condition +  rules[index:]
        alert += 1

    return rules


def add_custom_keep_firing_for(rules, indent=4):
    """Add if wrapper for additional rules annotations"""
    indent_spaces = " " * indent + "  "
    keep_firing_for = (indent_spaces + '{{- with .Values.defaultRules.keepFiringFor }}\n' +
                        indent_spaces + 'keep_firing_for: "{{ . }}"\n' +
                        indent_spaces + '{{- end }}')
    keep_firing_for_len = len(keep_firing_for) + 1

    separator = " " * indent + "  for:.*"
    alerts_positions = re.finditer(separator, rules)
    alert = 0

    for alert_position in alerts_positions:
        # Add rule_condition after 'annotations:' statement
        index = alert_position.end() + keep_firing_for_len * alert
        rules = rules[:index] + "\n" + keep_firing_for + rules[index:]
        alert += 1

    return rules


def add_custom_for(rules, indent=4):
    """Add custom 'for:' condition in rules"""
    replace_field = "for:"
    rules = add_custom_alert_rules(rules, replace_field, indent)

    return rules


def add_custom_severity(rules, indent=4):
    """Add custom 'severity:' condition in rules"""
    replace_field = "severity:"
    rules = add_custom_alert_rules(rules, replace_field, indent)

    return rules


def add_custom_alert_rules(rules, key_to_replace, indent):
    """Extend alert field to allow custom values"""
    key_to_replace_indented = ' ' * indent + key_to_replace
    alertkey_field = '- alert:'
    found_alert_key = False
    alertname = None
    updated_rules = ''

    # pylint: disable=C0200
    i = 0
    while i < len(rules):
        if rules[i:i + len(alertkey_field)] == alertkey_field:
            found_alert_key = True
            start_index_word_after = i + len(alertkey_field) + 1
            end_index_alertkey_field = start_index_word_after
            while end_index_alertkey_field < len(rules) and rules[end_index_alertkey_field].isalnum():
                end_index_alertkey_field += 1

            alertname = rules[start_index_word_after:end_index_alertkey_field]

        if found_alert_key:
            if rules[i:i + len(key_to_replace_indented)] == key_to_replace_indented:
                found_alert_key = False
                start_index_key_value = i + len(key_to_replace_indented) + 1
                end_index_key_to_replace = start_index_key_value
                while end_index_key_to_replace < len(rules) and rules[end_index_key_to_replace].isalnum():
                    end_index_key_to_replace += 1

                word_after_key_to_replace = rules[start_index_key_value:end_index_key_to_replace]
                new_key = key_to_replace_indented + ' {{ dig "' + alertname + \
                    '" "' + key_to_replace[:-1] + '" "' + \
                    word_after_key_to_replace + '" .Values.customRules }}'
                updated_rules += new_key
                i = end_index_key_to_replace

        updated_rules += rules[i]
        i += 1

    return updated_rules


def write_group_to_file(group, url, destination):
    fix_expr(group['rules'])
    group_name = group['name']

    # prepare rules string representation
    rules = yaml_str_repr(group)
    # add replacements of custom variables and include their initialisation in case it's needed
    init_line = ''
    for line in replacement_map:
        if group_name in replacement_map[line].get('limitGroup', [group_name]) and line in rules:
            rules = rules.replace(line, replacement_map[line]['replacement'])
            if replacement_map[line]['init']:
                init_line += '\n' + replacement_map[line]['init']
    # append per-alert rules
    rules = add_custom_labels(rules, group)
    rules = add_custom_annotations(rules, group)
    rules = add_custom_keep_firing_for(rules)
    rules = add_custom_for(rules)
    rules = add_custom_severity(rules)
    rules = add_rules_conditions_from_condition_map(rules)
    rules = add_rules_per_rule_conditions(rules, group)
    # initialize header
    lines = header % {
        'name': sanitize_name(group['name']),
        'url': url,
        'condition': condition_map.get(group['name'], ''),
        'init_line': init_line
    }

    # rules themselves
    lines += re.sub(
        r'\s(by|on) ?\(',
        r' \1 ({{ range $.Values.monitoring.rules.additionalAggregationLabels }}{{ . }},{{ end }}',
        rules,
        flags=re.IGNORECASE
    )

    # footer
    lines += '{{- end }}'

    filename = group['name'] + '.yaml'
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

            if chart.get('mixin'):
                cwd = os.getcwd()

                source_cwd = chart['cwd']
                mixin_file = chart['source']

                mixin_dir = cwd + '/' + checkout_dir + '/' + source_cwd + '/'
                if os.path.exists(mixin_dir + "jsonnetfile.json"):
                    print("Running jsonnet-bundler, because jsonnetfile.json exists")
                    subprocess.run(["jb", "install"], cwd=mixin_dir)

                if 'content' in chart:
                    f = open(mixin_dir + mixin_file, "w")
                    f.write(chart['content'])
                    f.close()

                print("Generating rules from %s" % mixin_file)
                print("Change cwd to %s" % checkout_dir + '/' + source_cwd)
                os.chdir(mixin_dir)

                alerts = json.loads(_jsonnet.evaluate_snippet(mixin_file, chart['mixin'], import_callback=jsonnet_import_callback))

                os.chdir(cwd)
            else:
                with open(checkout_dir + '/' + chart['source'], "r") as f:
                    raw_text = f.read()

                alerts = yaml.full_load(raw_text)

        else:
            url = chart['source']
            print("Generating rules from %s" % url)
            response = requests.get(url)
            if response.status_code != 200:
                print('Skipping the file, response code %s not equals 200' % response.status_code)
                continue
            raw_text = response.text
            if chart.get('mixin'):
                alerts = json.loads(_jsonnet.evaluate_snippet(url, raw_text + '.prometheusAlerts'))
            else:
                alerts = yaml.full_load(raw_text)

        # etcd workaround, their file don't have spec level
        groups = alerts['spec']['groups'] if alerts.get('spec') else alerts['groups']
        for group in groups:
            write_group_to_file(group, url, chart['destination'])

    print("Finished")


def sanitize_name(name):
    return re.sub('[_]', '-', name).lower()


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
                return candidate, open(candidate).read().encode('utf-8')

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


if __name__ == '__main__':
    main()
