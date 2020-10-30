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

"""Package creation helper mapping rules.

This module declares Provider interfaces and rules for specifying the contents
of packages in a package-type-agnostic way.  The main rules supported here are
the following:

- `pkg_files` describes destinations for rule outputs
- `pkg_mkdirs` describes directory structures
- `pkg_mklinks` describes symbolic links
- `pkg_filegroup` creates groupings of above to add to packages

Rules that actually make use of the outputs of the above rules are not specified
here.  See `rpm.bzl` for an example that builds out RPM packages.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//:providers.bzl", "PackageFilesInfo", "PackageFileGroupinfo", "PackageDirsInfo", "PackageSymlinksInfo")

_PKGFILEGROUP_STRIP_ALL = "."

def _sp_files_only():
    return _PKGFILEGROUP_STRIP_ALL

def _sp_from_pkg(path):
    if path.startswith("/"):
        return from_pkg[1:]
    else:
        return from_pkg

def _sp_from_root(path = ""):
    if from_root.startswith("/"):
        return from_root
    else:
        return "/" + from_root

strip_prefix = struct(
    _doc = """TODO: see make_strip_prefix""",
    files_only = _sp_files_only,
    from_pkg = _sp_from_pkg,
    from_root = _sp_from_root,
)


####
# Internal helpers
####

def _validate_attr(attr):
    # If/when the "attr" list expands, this should probably be modified to use
    # sets (like the one in skylib) instead
    valid_keys = ["unix"]
    for k in attr.keys():
        if k not in valid_keys:
            fail("Invalid attr {}, allowed are {}".format(k, valid_keys), "attrs")

    # We could do more here, perhaps
    if "unix" in attr.keys():
        if len(attr["unix"]) != 3:
            fail("'unix' attrs key must have three child values")

def _do_strip_prefix(path, to_strip):
    path_norm = paths.normalize(path)
    to_strip_norm = paths.normalize(to_strip) + "/"

    if path_norm.startswith(to_strip_norm):
        return path_norm[len(to_strip_norm):]
    else:
        return path_norm

# The below routines make use of some path checking magic that may difficult to
# understand out of the box.  This following table may be helpful to demonstrate
# how some of these members may look like in real-world usage:
#
# Note: "F" is "File", "FO": is "File.owner".

# | File type | Repo     | `F.path`                                                 | `F.root.path`                | `F.short_path`          | `FO.workspace_name` | `FO.workspace_root` |
# |-----------|----------|----------------------------------------------------------|------------------------------|-------------------------|---------------------|---------------------|
# | Source    | Local    | `dirA/fooA`                                              |                              | `dirA/fooA`             |                     |                     |
# | Generated | Local    | `bazel-out/k8-fastbuild/bin/dirA/gen.out`                | `bazel-out/k8-fastbuild/bin` | `dirA/gen.out`          |                     |                     |
# | Source    | External | `external/repo2/dirA/fooA`                               |                              | `../repo2/dirA/fooA`    | `repo2`             | `external/repo2`    |
# | Generated | External | `bazel-out/k8-fastbuild/bin/external/repo2/dirA/gen.out` | `bazel-out/k8-fastbuild/bin` | `../repo2/dirA/gen.out` | `repo2`             | `external/repo2`    |

def _owner(file):
    # File.owner allows us to find a label associated with a file.  While highly
    # convenient, it may return None in certain circumstances, which seem to be
    # primarily when bazel doesn't know about the files in question.
    #
    # Given that a sizeable amount of the code we have here relies on it, we
    # should fail() when we encounter this if only to make the rare error more
    # clear.
    #
    # File.owner returns a Label structure
    if file.owner == None:
        fail("File {} ({}) has no owner attribute; cannot continue".format(file, file.path))
    else:
        return file.owner

def _relative_workspace_root(label):
    # Helper function that returns the workspace root relative to the bazel File
    # "short_path", so we can exclude external workspace names in the common
    # path stripping logic.
    #
    # This currently is "../$LABEL_WORKSPACE_ROOT" if the label has a specific
    # workspace name specified, else it's just an empty string.
    #
    # XXX: Make this not a hack
    return paths.join("..", label.workspace_name) if label.workspace_name else ""

def _path_relative_to_package(file):
    # Helper function that returns a path to a file relative to its package.
    owner = _owner(file)
    return paths.relativize(
        file.short_path,
        paths.join(_relative_workspace_root(owner), owner.package),
    )

def _path_relative_to_repo_root(file):
    # Helper function that returns a path to a file relative to its workspace root.
    return paths.relativize(
        file.short_path,
        _relative_workspace_root(_owner(file)),
    )

def _pkg_files_impl(ctx):
    # The input sources are already known.  Let's calculate the destinations...

    # Exclude excludes
    srcs = [f for f in ctx.files.srcs if f not in ctx.files.excludes]

    if ctx.attr.strip_prefix == _PKGFILEGROUP_STRIP_ALL:
        dests = [paths.join(ctx.attr.prefix, src.basename) for src in srcs]
    elif ctx.attr.strip_prefix.startswith("/"):
        # Relative to workspace/repository root
        dests = [
            paths.join(
                ctx.attr.prefix,
                _do_strip_prefix(
                    _path_relative_to_repo_root(f),
                    ctx.attr.strip_prefix[1:],
                ),
            )
            for f in srcs
        ]
    else:
        # Relative to package
        dests = [
            paths.join(
                ctx.attr.prefix,
                _do_strip_prefix(
                    _path_relative_to_package(f),
                    ctx.attr.strip_prefix,
                ),
            )
            for f in srcs
        ]

    # If the lengths of these are not the same, then it impossible to correlate
    # them in the actual package helpers, and in the map below.
    if len(srcs) != len(dests):
        fail("INTERNAL ERROR: pkg_files length mismatch")

    # TODO(nacl): It would be nice to be able to
    # build it in one fell swoop.
    src_dest_files_map = dict(zip(srcs, dests))

    _validate_attr(ctx.attr.attrs)

    # Do file renaming
    for rename_src, rename_dest in ctx.attr.renames.items():
        # rename_src.files is a depset
        rename_src_files = rename_src.files.to_list()

        # Need to do a length check before proceeding.  We cannot rename
        # multiple files simultaneously.
        if len(rename_src_files) != 1:
            fail(
                "Target {} expands to multiple files, should only refer to one".format(rename_src),
                "renames",
            )

        src_file = rename_src_files[0]
        if src_file not in src_dest_files_map:
            fail(
                "File remapping from {0} to {1} is invalid: {0} is not provided to this rule or was excluded".format(rename_src, rename_dest),
                "renames",
            )
        src_dest_files_map[src_file] = paths.join(ctx.attr.prefix, rename_dest)

    return [
        PackageFilesInfo(
            source_dest_map = src_dest_files_map,
            attributes = ctx.attr.attrs,
        ),
        DefaultInfo(
            # Simple passthrough
            files = depset(src_dest_files_map.keys()),
        ),
    ]

pkg_files = rule(
    doc = """General-purpose package target-to-destination mapping rule.

    This rule provides a specification for the locations and attributes of
    targets when they are packaged. No outputs are created other than Providers
    that are intended to be consumed by other packaging rules, such as
    `pkg_rpm`.

    Instead of providing the actual rules that generate your desired outputs to
    packaging rules, you instead pass in the associated `pkg_filegroup`

    Consumers of `pkg_filegroup`s will, where possible, create the necessary
    directory structure for your files so you do not have to unless you have
    special requirements.  Consult `pkg_mkdirs` for more details.
    """,
    implementation = _pkg_filegroup_impl,
    # @unsorted-dict-items
    attrs = {
        "srcs": attr.label_list(
            doc = """Files/Labels to include in this target filegroup""",
            mandatory = True,
            allow_files = True,
        ),
        "attrs": attr.string_list_dict(
            doc = """Attributes to set for the output targets

            Must be a dict of:

            ```
            "unix" : [
                "Four-digit octal permissions string (e.g. "0644") or "-" (don't change from what's provided),
                "User Id, or "-" (use current user)",
                "Group Id, or "-" (use current group)",
            ]
            ```

            All values default to "-".

            Optionally, the following attributes are supported:

            ```
            rpm_section: list of a single item.  See "section", below.
            """,
            default = {"unix": ["-", "-", "-"]},
        ),
        "prefix": attr.string(
            doc = """Installation prefix.

            This may be an arbitrary string, but it should be understandable by
            the packaging system you are using to have the desired outcome.  For
            example, RPM macros like `%{_libdir}` may work correctly in paths
            for RPM packages, not, say, Debian packages.

            If any part of the directory structure of the computed destination
            of a file provided to `pkg_filegroup` or any similar rule does not
            already exist within a package, the package builder will create it
            for you with a reasonable set of default permissions (typically
            `0755 root.root`).

            It is possible to establish directory structures with arbitrary
            permissions using `pkg_mkdirs`.
            """,
            default = "",
        ),
        "strip_prefix": attr.string(
            doc = """What prefix of a file's path to discard prior to installation.

            This specifies what prefix of an incoming file's path should not be
            included in the path the file is installed at after being appended
            to the install prefix (the prefix attribute).  Note that this is
            only applied to full directory names, see `make_strip_prefix` for
            more details.

            Use the `make_strip_prefix()` function to define this attribute.  If this
            attribute is not specified, all directories will be stripped from
            all files prior to being included in packages
            (`strip_prefix(files_only = True`).
            """,
            default = strip_prefix.files_only(),
        ),

        "excludes": attr.label_list(
            doc = """List of files or labels to exclude from the inputs to this file collection

            Mostly useful for removing files from generated outputs or
            preexisting `filegroup`s.
            """,
            allow_files = True,
            default = [],
        ),
        "renames": attr.label_keyed_string_dict(
            doc = """Destination override map

            This attribute allows the user to override destinations of files in
            `pkg_filegroup`s relative to the `prefix` attribute.  Keys to the
            dict are source files/labels, values are destinations relative to
            the `prefix`, ignoring whatever value was provided for
            `strip_prefix`.

            This is the most effective way to rename files using
            `pkg_filegroup`s.  For single files, consider using
            `pkg_rename_single`.

            The following keys are rejected:

            - Any label that expands to more than one file (mappings must be
              one-to-one).

            - Any label or file that was either not provided or explicitly
              `exclude`d.
            """,
            default = {},
            allow_files = True,
        ),
    },
)

def _pkg_filegroup_impl(ctx):
    files = []
    dirs = []
    links = []
    for s in srcs:
        # TODO: reroot
        if PackageFilesInfo in s:
            files.append(s[PackageFilesInfo])
        if PackageDirsInfo in s:
            dirs.append(s[PackageDirsInfo])
        if PackageLinksInfo in s:
            links.append(s[PackageLinksInfo])
    return [
        PackageFilegroupInfo(
            pkg_files = files,
            pkg_dirs = dirs,
            pkg_symlinks = pkg_links,
        )
    ]

pkg_filegroup = rule(
    doc = """Document me""",
    implementation = _pkg_filegroup_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            providers = [
                [PackageFilesInfo],
                [PackageDirsInfo],
                [PackageSymlinksInfo],
            ],
        ),
        "prefix": attr.string(

        )

    },
)

def _pkg_mkdirs_impl(ctx):
    _validate_attr(ctx.attr.attrs)

    if ctx.attr.section not in ["dir", "docdir"]:
        fail("Invalid 'section' value", "section")
    return [
        PackageDirInfo(
            dirs = ctx.attr.dirs,
            attrs = ctx.attr.attrs,
        ),
    ]

pkg_mkdirs = rule(
    doc = """Defines creation and ownership of directories in packages

    Use this if:

    1) You need to create an empty directory in your package.

    2) Your package needs to explicitly own a directory, even if it already owns
       files in those directories.

    3) You need nonstandard permissions (typically, not "0755") on a directory
       in your package.

    For some package management systems (e.g. RPM), directory ownership (2) may
    imply additional semantics.  Consult your package manager's and target
    distribution's documentation for more details.
    """,
    implementation = _pkg_mkdirs_impl,
    # @unsorted-dict-items
    attrs = {
        "dirs": attr.string_list(
            doc = """Directory names to make within the package

            If any part of the requested directory structure does not already
            exist within a package, the package builder will create it for you
            with a reasonable set of default permissions (typically `0755
            root.root`).

            """,
            mandatory = True,
        ),
        "attrs": attr.string_list_dict(
            doc = """Attributes to set for the output targets.

            Must be a dict of:

            ```
            "unix" : [
                "Four-digit octal permissions string (e.g. "0755") or "-" (don't change from what's provided),
                "User Id, or "-" (use current user)",
                "Group Id, or "-" (use current group)",
            ]
            ```

            All values default to "-".
            """,
            default = {"unix": ["-", "-", "-"]},
        ),
    },
)

def _pkg_mklinks_impl(ctx):
    _validate_attr(ctx.attr.attrs)
    return [
        PackageSymlinksInfo(
            link_map = ctx.attr.links,
            attrs = ctx.attr.attrs,
        ),
    ]

pkg_mklinks = rule(
    doc = """Define symlinks within packages

    This rule results in the creation of one or more symbolic links in a
    package.

    Symbolic links specified by this rule may be dangling, or refer to a
    file/directory outside of the current created package.

    The link may point to a location outside of it.

    """,
    implementation = _pkg_mklinks_impl,
    attrs = {
        "links": attr.string_dict(
            doc = """Link mappings to create within the target archive.

            The keys of this dict are paths of the created links, the values are
            the link destinations ("targets" in `ln(1)` parlance).

            If the directory structure mentioned in the "link" part of the
            package does not yet exist within the package when it is built, it
            will be created by the package builder.

            """,
            mandatory = True,
        ),
        "attrs": attr.string_list_dict(
            doc = """Attributes to set for the output targets.

            Must be a dict of:

            ```
            "unix" : [
                "Four-digit octal permissions string (e.g. "0755") or "-" (don't change from what's provided),
                "User Id, or "-" (use current user)",
                "Group Id, or "-" (use current group)",
            ]
            ```

            The permissions value defaults to "0777".  The user/group values
            default to "-".
            """,
            default = {"unix": ["0777", "-", "-"]},
        ),
        "section": attr.string(
            doc = """Symlink section mapping.

            Legal values for this attribute are:
            - "" (i.e. an empty string)
            - "doc"
            - "config"
            - "config(missingok)"
            - "config(noreplace)"
            - "config(missingok, noreplace)"

            See the "section" attribute of `pkg_filegroup` for more information.
            """,
            default = "",
            values = [
                "",
                "doc",
                "config",
                "config(missingok)",
                "config(noreplace)",
                "config(missingok, noreplace)",
            ],
        ),
        "prefix": attr.string(
            # TODO: implement
        )
    },
)
