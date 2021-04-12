#!/usr/bin/env python3

import json
import os
import shutil
import sys

# Input directory path
dir_in = sys.argv[1]
# Output directory path
dir_out = sys.argv[2]

dir_actions_json = sys.argv[3]

os.makedirs(dir_out, exist_ok=True)

for root, dirs, files in os.walk(dir_in):
    rel_root = os.path.relpath(root, dir_in)

    dest_dir = os.path.join(dir_out, rel_root)
    os.makedirs(dest_dir, exist_ok=True)

    for f in files:
        src = os.path.join(root, f)
        shutil.copy(
            src,
            dest_dir
        )
