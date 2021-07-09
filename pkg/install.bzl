# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""rules for creating install scripts from pkg_filegroups and friends.

This module provides an interface (`pkg_install`) for creating a `bazel
run`-able installation script.

For example:

```python
pkg_install(
    name = "install",
    srcs = [
        # mapping/grouping targets here
    ],
)
```

Installation can be done by invoking:

```
bazel run -- //path/to:install
```

Additional features can be accessed by invoking the script with the --help
option:

```
bazel run -- //path/to:install --help
```

"""

load("//:providers.bzl", "PackageDirsInfo", "PackageFilegroupInfo", "PackageFilesInfo", "PackageSymlinkInfo")
load("//private:pkg_files.bzl", "process_src", "write_manifest")
load("@rules_python//python:defs.bzl", "py_binary")

def _pkg_install_script_impl(ctx):
    script_file = ctx.actions.declare_file(ctx.attr.name + ".py")

    fragments = []
    files_to_run = []
    content_map = {}
    for src in ctx.attr.srcs:
        if DefaultInfo in src:
            files_to_run.append(src[DefaultInfo].files)

        process_src(content_map, src, src.label, "0644", None, None)

    manifest_file = ctx.actions.declare_file(ctx.attr.name + "-install-manifest.json")
    write_manifest(ctx, manifest_file, content_map, short_path = True)

    # Get the label of the actual py_binary used to run this script.
    #
    # This is super brittle, but I don't know how to otherwise get this
    # information without creating a circular dependency given the current state
    # of rules_python.
    binary_label_str = "{}//{}:{}".format(
        ctx.label.workspace_name,
        ctx.label.package,
        # The name of the binary is the name of this target, minus
        # "_install_script".
        ctx.label.name[:-len("_install_script")],
    )

    # Runfiles
    ctx.actions.expand_template(
        template = ctx.file.script_template,
        output = script_file,
        substitutions = {
            "##MANIFEST_INCLUSION##": manifest_file.short_path,
            "##WORKSPACE_NAME##": ctx.workspace_name,
            "##TARGET_LABEL##": str(Label(binary_label_str)),
        },
        is_executable = True,
    )

    my_runfiles = ctx.runfiles(
        files = [manifest_file],
        transitive_files = depset(transitive = files_to_run),
    )

    return [
        DefaultInfo(
            files = depset([script_file]),
            runfiles = my_runfiles,
            executable = script_file,
        ),
    ]

_pkg_install_script = rule(
    doc = """Document me""",
    implementation = _pkg_install_script_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            providers = [
                [PackageFilegroupInfo],
                [PackageFilesInfo],
                [PackageDirsInfo],
                [PackageSymlinkInfo],
            ],
        ),
        "script_template": attr.label(
            allow_single_file = True,
            default = "//:install.py.in",
        ),
    },
    executable = True,
)

def pkg_install(name, srcs, **kwargs):
    _pkg_install_script(
        name = name + "_install_script",
        srcs = srcs,
        **kwargs
    )

    kwargs.pop("script_template", None)

    py_binary(
        name = name,
        srcs = [":" + name + "_install_script"],
        main = name + "_install_script.py",
        deps = ["@rules_pkg//private:manifest"],
        **kwargs
    )
