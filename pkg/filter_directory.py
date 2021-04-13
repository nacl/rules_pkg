#!/usr/bin/env python3

import argparse
import os
import pathlib
import shutil
import sys

def main(argv):
    parser = argparse.ArgumentParser()

    parser.add_argument("--strip-prefix", type=str,
                        help="directory prefix to strip from all incoming paths")
    parser.add_argument("--prefix", type=str,
                        help="prefix to add to all output paths")
    parser.add_argument("--rename", type=str, action='append',
                        help="SOURCE=DESTINATION mappings.  Only supports files.")
    parser.add_argument("--exclude", type=str, action='append',
                        help="Input files to exclude from the output directory")

    parser.add_argument("input_dir", type=pathlib.Path,
                        help="input directory")
    parser.add_argument("output_dir", type=pathlib.Path,
                        help="output directory")

    args = parser.parse_args(argv)

    print(args)

    dir_in = args.input_dir
    dir_out = args.output_dir
    # TODO-NOW: properly use pathlib below

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


if __name__ == "__main__":
    exit(main(sys.argv[1:]))
