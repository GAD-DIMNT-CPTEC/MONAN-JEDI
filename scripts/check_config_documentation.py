#!/usr/bin/env python3
"""Enforce the MONAN-JEDI configuration documentation contract.

The configuration YAML files are operator-facing documentation, not merely
machine-readable input. This checker prevents pull requests from silently
removing the explanatory context required to maintain them safely.

Compatible with Python 3.6 so it can run before the JACI stack is activated.
"""

import importlib.util
import re
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
READER_PATH = ROOT / "scripts" / "lib" / "read_config.py"
JACI_PATH = ROOT / "config" / "jaci.yaml"
TEMPLATE_PATH = ROOT / "config" / "template.yaml"
REFERENCE_PATH = ROOT / "docs" / "configuration-reference.md"

REQUIRED_HEADER_MARKERS = (
    "PURPOSE",
    "IMPORTANT FILESYSTEM MODEL",
    "MAIN DERIVED PATHS",
    "GENERAL RULES",
)

MIN_COMMENT_LINES = 2
MIN_COMMENT_CHARACTERS = 90
MIN_REFERENCE_SECTION_CHARACTERS = 120

KEY_RE = re.compile(r"^(\s*)([A-Za-z_][A-Za-z0-9_]*):(?:\s.*)?$")
DECORATION_RE = re.compile(r"^[-=_]+$")


def load_reader_module():
    spec = importlib.util.spec_from_file_location("monan_jedi_read_config", str(READER_PATH))
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load scripts/lib/read_config.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_yaml(path):
    with path.open("r", encoding="utf-8") as stream:
        data = yaml.safe_load(stream)
    if not isinstance(data, dict):
        raise ValueError("{0}: expected a YAML mapping at file root".format(path))
    return data


def get_nested(data, dotted_path):
    current = data
    for part in dotted_path.split("."):
        if not isinstance(current, dict) or part not in current:
            raise KeyError(dotted_path)
        current = current[part]
    return current


def leaf_paths(data, prefix=""):
    result = []
    for key, value in data.items():
        path = "{0}.{1}".format(prefix, key) if prefix else str(key)
        if isinstance(value, dict):
            result.extend(leaf_paths(value, path))
        else:
            result.append(path)
    return result


def locate_leaf_lines(text, data):
    lines = text.splitlines()
    stack = []
    found = {}

    for index, line in enumerate(lines):
        if line.lstrip().startswith("#") or not line.strip():
            continue
        match = KEY_RE.match(line)
        if not match:
            continue

        indent = len(match.group(1))
        key = match.group(2)
        while stack and indent <= stack[-1][0]:
            stack.pop()

        parent = ".".join(item[1] for item in stack)
        path = "{0}.{1}".format(parent, key) if parent else key

        try:
            value = get_nested(data, path)
        except KeyError:
            continue

        if isinstance(value, dict):
            stack.append((indent, key))
        else:
            found[path] = index

    return lines, found


def substantive_comment_block(lines, key_line):
    comments = []
    index = key_line - 1

    # Documentation must be immediately adjacent to the key. A blank line breaks
    # the association and therefore fails the contract.
    while index >= 0:
        stripped = lines[index].lstrip()
        if not stripped.startswith("#"):
            break
        body = stripped[1:].strip()
        if body and not DECORATION_RE.match(body):
            comments.append(body)
        index -= 1

    comments.reverse()
    return comments


def check_yaml_documentation(path, require_complete_schema, supported):
    errors = []
    text = path.read_text(encoding="utf-8")
    data = load_yaml(path)

    for marker in REQUIRED_HEADER_MARKERS:
        if marker not in text:
            errors.append("{0}: missing required header block: {1}".format(path, marker))

    leaves = set(leaf_paths(data))
    unknown = sorted(leaves - supported)
    for item in unknown:
        errors.append("{0}: undocumented/unsupported YAML key: {1}".format(path, item))

    if require_complete_schema:
        missing = sorted(supported - leaves)
        for item in missing:
            errors.append(
                "{0}: template must expose every public key; missing {1}".format(path, item)
            )

    lines, locations = locate_leaf_lines(text, data)
    for item in sorted(leaves & supported):
        if item not in locations:
            errors.append("{0}: could not locate YAML key in source: {1}".format(path, item))
            continue

        comments = substantive_comment_block(lines, locations[item])
        characters = sum(len(line) for line in comments)
        if len(comments) < MIN_COMMENT_LINES or characters < MIN_COMMENT_CHARACTERS:
            errors.append(
                "{0}: {1} needs at least {2} substantive adjacent comment lines "
                "and {3} documented characters; found {4} lines/{5} chars".format(
                    path,
                    item,
                    MIN_COMMENT_LINES,
                    MIN_COMMENT_CHARACTERS,
                    len(comments),
                    characters,
                )
            )

    return errors


def extract_reference_sections(text):
    headings = list(re.finditer(r"^###\s+`([^`]+)`\s*$", text, flags=re.MULTILINE))
    result = {}
    for index, match in enumerate(headings):
        start = match.end()
        end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
        result[match.group(1)] = text[start:end].strip()
    return result


def check_reference_documentation(supported):
    errors = []
    text = REFERENCE_PATH.read_text(encoding="utf-8")
    sections = extract_reference_sections(text)

    for item in sorted(supported):
        body = sections.get(item)
        if body is None:
            errors.append(
                "{0}: missing detailed section heading for {1}".format(
                    REFERENCE_PATH, item
                )
            )
            continue
        prose = re.sub(r"\s+", " ", body)
        if len(prose) < MIN_REFERENCE_SECTION_CHARACTERS:
            errors.append(
                "{0}: section {1} is too brief ({2} chars; minimum {3})".format(
                    REFERENCE_PATH,
                    item,
                    len(prose),
                    MIN_REFERENCE_SECTION_CHARACTERS,
                )
            )

    return errors


def run_checks():
    reader = load_reader_module()
    supported = set(reader.supported_yaml_paths())
    errors = []

    errors.extend(check_yaml_documentation(JACI_PATH, False, supported))
    errors.extend(check_yaml_documentation(TEMPLATE_PATH, True, supported))
    errors.extend(check_reference_documentation(supported))

    return errors


def main():
    try:
        errors = run_checks()
    except (OSError, ValueError, yaml.YAMLError, RuntimeError) as exc:
        sys.stderr.write("Configuration documentation check failed: {0}\n".format(exc))
        return 1

    if errors:
        sys.stderr.write("Configuration documentation contract violations:\n")
        for error in errors:
            sys.stderr.write("  - {0}\n".format(error))
        return 1

    print("Configuration documentation contract passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
