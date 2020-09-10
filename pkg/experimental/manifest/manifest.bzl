# Copyright 2020 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("//experimental:pkg_filegroup.bzl", "pkg_filegroup", "pkg_mkdirs", "pkg_mklinks")

"""This module provides an alternate way to specify package contents using a
csv-like "manifest" description.

This will allow a highly succinct descriptions of package contents in many
common cases.

The following cases are NOT supported by this scheme:

- Exclusion of any files from a source target with multiple files.
- Renaming of any files from a source target with multiple files.
- Any sort of prefix stripping or path manipulation.

Normal pkg_filegroup's should be used in the above cases.

"""

# Example manifest:
#
# Buildifier probably will almost certanily be cranky about this.  Might have to
# change the tables.
[
    # action     dest                            attributes...           source
    ["copy",    "/some/destination/directory/",  "unix=0755", ":target-or-label"],
    ["copy",    "/some/destination/binary-name", "unix=0755", ":target-or-label"],
    ["mkdir",   "/dir",                          "unix=0755", "IGNORED"],
    ["mkdir",   "/dir/child",                    "unix=0755", "IGNORED"],
    ["mkdir",   "/dir/child/other-child",        "unix=0755", "IGNORED"],
    ["symlink", "target",                        "unix=0777", "source"],
]

_MANIFEST_ROW_SIZE = 4

def _manifest_process_copy(name, destination, attrs, source, **kwargs):
    allowed_attrs = ["section", "unix", "user", "group"]

    section = None
    unix_perms = '-'
    user = '-'
    group = '-'
    for decl in attrs.split(';'):
        (attr, _, value) = decl.partition('=')
        if attr not in allowed_attrs:
            fail("{}: unknown attribute {}".format(name, attr))
        if attr == 'section':
            section = value
        elif attr == 'unix':
            unix_perms = value
        elif attr == 'user':
            user = value
        elif attr == 'group':
            group = group

    if destination.endswith('/'):
        prefix = destination
        renames = {}
    else:
        prefix = None
        renames = {source: destination}

    pkg_filegroup(
        name = name,
        srcs = [source],
        attrs = {"unix" : [unix_perms, user, group]},
        section = section,
        renames = renames,
        prefix = prefix,
        **kwargs
    )


def _manifest_process_mkdir(name, destination, attrs, source, **kwargs):
    allowed_attrs = ["section", "unix", "user", "group"]

    section = None
    unix_perms = '-'
    user = '-'
    group = '-'
    for decl in attrs.split(';'):
        (attr, _, value) = decl.partition('=')
        if attr not in allowed_attrs:
            fail("{}: unknown attribute {}".format(name, attr))
        if attr == 'section':
            section = value
        elif attr == 'unix':
            unix_perms = value
        elif attr == 'user':
            user = value
        elif attr == 'group':
            group = group

    pkg_mkdirs(
        name = name,
        dirs = [destination],
        attrs = {"unix" : [unix_perms, user, group]},
        section = section,
        **kwargs
    )

def _manifest_process_symlink(name, destination, attrs, source, **kwargs):
    allowed_attrs = ["section", "unix", "user", "group"]

    section = None
    unix_perms = '0777'
    user = '-'
    group = '-'

    if attrs != '-':
        for decl in attrs.split(';'):
            (attr, _, value) = decl.partition('=')
            if attr not in allowed_attrs:
                fail("{}: unknown attribute {}".format(name, attr))
            if attr == 'section':
                section = value
            elif attr == 'unix':
                unix_perms = value
            elif attr == 'user':
                user = value
            elif attr == 'group':
                group = group

    pkg_mklinks(
        name = name,
        links = {destination : source},
        attrs = {"unix" : [unix_perms, user, group]},
        section = section,
        **kwargs
    )

def pkg_process_manifest(name, manifest, **kwargs):
    rules = []

    for idx, desc in enumerate(manifest):
        if len(desc) != _MANIFEST_ROW_SIZE:
            fail("Package description index {} malformed (size {}, must be {})".format(
                idx, len(desc), _MANIFEST_ROW_SIZE,
            ))

        (action, destination, attrs, source) = desc

        rule_name = "{}_manifest_elem_{}".format(name, idx)
        if action == "copy": 
            _manifest_process_copy(rule_name, destination, attrs, source, **kwargs)
        elif action == "mkdir":
            _manifest_process_mkdir(rule_name, destination, attrs, source, **kwargs)
        elif action == "symlink":
            _manifest_process_symlink(rule_name, destination, attrs, source, **kwargs)
        else: 
            fail("Package description index {} malformed (unknown action {})".format(
                idx, action
            ))

        rules.append(':{}'.format(rule_name))

    # TODO: making this return something like a pkg_filegroup requires some sort
    # of "aggregator" rule.  The original pkg_filegroup framework was not
    # designed this way, and it needs to be rethought.
    return rules
