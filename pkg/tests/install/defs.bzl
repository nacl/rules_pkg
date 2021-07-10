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

"""pkg_install test helpers"""

def _capture_pkg_install_impl(ctx):
    outdir = ctx.actions.declare_directory(ctx.attr.name)

    ctx.actions.run(
        outputs = [outdir],
        arguments = ["--destdir", outdir.path],
        executable = ctx.executable.target,
    )

    return DefaultInfo(files = depset([outdir]))

capture_pkg_install = rule(
    doc = """Capture the output of an invocation of pkg_install""",
    implementation = _capture_pkg_install_impl,
    attrs = {
        "target": attr.label(
            executable = True,
            cfg = "exec",
        ),
    },
)
