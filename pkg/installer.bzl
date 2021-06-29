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

load("//:providers.bzl", "PackageFilegroupInfo", "PackageSymlinksInfo", "PackageDirsInfo", "PackageFilesInfo")
load("@bazel_skylib//lib:shell.bzl", "shell")
load("@bazel_skylib//lib:paths.bzl", "paths")

_INSTALL_FILE_STANZA_FMT = """
_install {0} {1} 
"""
def _script_for_pkg_files(pfi, default_workspace_name):
    fragments = []
    for src, dest in pfi.source_dest_map.items():
        # TODO: use a custom _owner function

        # The "workspace_name" of a label that is in the current workspace is
        # empty.
        workspace_name = src.owner.workspace_name or default_workspace_name
        
        fragments.append(_INSTALL_FILE_STANZA_FMT.format(
            # Runfiles are relative to each WORKSPACE used
            shell.quote(paths.join(workspace_name, src.short_path)),
            shell.quote(dest)
        ))
    return "".join(fragments)

_INSTALL_DIR_STANZA_FMT = """
_mkdir {0}
"""

def _script_for_pkg_mkdirs(pdi):
    fragments = []
    for d in pdi.dirs:
        fragments.append(_INSTALL_DIR_STANZA_FMT.format(shell.quote(d)))
    return "".join(fragments)

_INSTALL_LINK_STANZA_FMT = """
_mklink {0} {1}
"""

def _script_for_pkg_mklinks(psi):
    fragments = []
    for dest, src in psi.links:
        fragments.append(_INSTALL_LINK_STANZA_FMT.format(shell.quote(src), shell.quote(dest)))
    return "".join(fragments)

def _pkg_installer_impl(ctx):
    script_file = ctx.actions.declare_file(ctx.attr.name + "-install.sh")

    fragments = []
    needed_files = []
    for pfg_src in ctx.attr.srcs:
        pfg_info = pfg_src[PackageFilegroupInfo]
        fragments += [_script_for_pkg_files(pfi, ctx.workspace_name) for pfi in pfg_info.pkg_files]
        needed_files += [s for pfi in pfg_info.pkg_files for s in pfi.source_dest_map.keys()]

        fragments += [_script_for_pkg_mkdirs(pdi) for pdi in pfg_info.pkg_dirs]
        fragments += [_script_for_pkg_mkdirs(psi) for psi in pfg_info.pkg_symlinks]
        
    script_contents = "".join(fragments)
    print(needed_files)

    ctx.actions.expand_template(
        template = ctx.file.script_template,
        output = script_file,
        substitutions = {"{{CONTENTS}}": script_contents},
        is_executable = True,
    )

    my_runfiles = ctx.runfiles(
        files = needed_files,
    )

    all_runfiles = my_runfiles.merge(ctx.attr._sh_runfiles[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(
            files = depset([script_file]),
            runfiles = all_runfiles,
            executable = script_file,
        )
    ]

pkg_installer = rule(
    doc = """Document me""",
    implementation = _pkg_installer_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            providers = [PackageFilegroupInfo]
        ),
        "script_template": attr.label(
            allow_single_file = True,
            default = "//:installer.sh.in",
        ),
        "_sh_runfiles": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        )
    },
    executable = True,
    # executable = False,
    # cfg = None,
    # fragments = [],
    # host_fragments = [],
    # toolchains = [],
    # build_setting = None,
)
