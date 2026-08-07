#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os


def parse_modules_dep(path):
    deps = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            lhs, _, rhs = line.partition(":")
            mod = lhs.strip()
            dep_list = rhs.split()
            deps[mod] = dep_list
    return deps


def parse_modules_builtin(path):
    builtin = set()
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            base = os.path.basename(line)
            stem = base.split(".ko")[0].replace("-", "_")
            builtin.add(stem)
    return builtin


def find_module_path(deps, name):
    name = name.replace("-", "_")
    for mod_path in deps:
        base = os.path.basename(mod_path)
        # strip .ko, .ko.gz, .ko.xz etc.
        stem = base.split(".ko")[0].replace("-", "_")
        if stem == name:
            return mod_path
    return None


def resolve(deps, builtin, name, seen=None, order=None):
    if seen is None:
        seen = set()
    if order is None:
        order = []

    name_norm = name.replace("-", "_")
    if name_norm in builtin:
        return order

    mod_path = find_module_path(deps, name)
    if mod_path is None:
        raise KeyError(f"module '{name}' not found in modules.dep or modules.builtin")

    if mod_path in seen:
        return order

    seen.add(mod_path)

    for dep in deps.get(mod_path, []):
        resolve(deps, builtin, os.path.basename(dep).split(".ko")[0], seen, order)

    order.append(mod_path)
    return order


def main():
    if len(sys.argv) < 4:
        print("usage: resolve_modules.py <ramfs_dir> <path> <module1> [module2 ...]")
        sys.exit(1)

    ramfs_dir = sys.argv[1]
    path = sys.argv[2]
    module_names = sys.argv[3:]

    target_path = os.path.join(ramfs_dir, path)
    dep_file = os.path.join(target_path, "modules.dep")
    builtin_file = os.path.join(target_path, "modules.builtin")

    deps = parse_modules_dep(dep_file)
    builtin = parse_modules_builtin(builtin_file)

    seen = set()
    order = []
    for name in module_names:
        resolve(deps, builtin, name, seen, order)

    for mod_path in order:
        print(f"/{path}/{mod_path}")


if __name__ == "__main__":
    main()
