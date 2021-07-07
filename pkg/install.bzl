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

    ctx.actions.expand_template(
        template = ctx.file.script_template,
        output = script_file,
        substitutions = {"##MANIFEST_INCLUSION##": manifest_file.short_path},
        is_executable = True,
    )

    my_runfiles = ctx.runfiles(
        files = [manifest_file],
        transitive_files = depset(transitive = files_to_run),
    )

    all_runfiles = my_runfiles.merge(ctx.attr._py_runfiles[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(
            files = depset([script_file]),
            runfiles = all_runfiles,
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
        "_py_runfiles": attr.label(
            default = "@bazel_tools//tools/python/runfiles",
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
        **kwargs
    )
