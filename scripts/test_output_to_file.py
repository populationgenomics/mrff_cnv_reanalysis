#!/usr/bin/env python3

"""
a small test script to test outputting to file / folder

set this off using
analysis-runner \
    --dataset acute-care \
    --access-level test \
    --description "running a test" \
    --output-dir "test_script" \
    scripts/test_output_to_file.py
"""

from cpg_utils.hail_batch import output_path

opath = output_path("hello_world.txt")

string_to_print = 'hello world'

f = open(opath, "w")
f.write("hello world")
f.close()
