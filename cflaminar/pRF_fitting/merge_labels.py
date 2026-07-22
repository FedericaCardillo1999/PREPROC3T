#!/usr/bin/env python3
# merge_labels.py
# For each subject, assigns a ROI value to each manually delineated visual area label,
# then merges all areas into a single label file using mri_mergelabels.
# Usage: python merge_labels.py sub-01 UMCG

import numpy as np
import subprocess
import os
import sys

# Get subject and project from command line
subject_id = sys.argv[1]
project    = sys.argv[2]

# Visual areas and their corresponding ROI values
rois = np.array([['V1', 'V2', 'V3', 'V4', 'LO'], [1, 2, 3, 4, 5]])

# Directories
fs_dirPATH = f"/scratch/hb-EGRET-AAA/projects/{project}/derivatives/freesurfer"
label_dir  = os.path.join(fs_dirPATH, subject_id, "label")

# Step 1: For each hemisphere and visual area, assign the ROI value to each vertex
# and save as a new edited label file
for hemi in ['lh', 'rh']:
    for roi in range(len(rois[0])):
        roi_name = rois[0][roi]
        roi_val  = rois[1][roi]
        fname   = os.path.join(label_dir, f"{hemi}.manual_{roi_name}.label")
        outname = os.path.join(label_dir, f"{hemi}.manual{roi_name}edit.label")

        try:
            with open(fname, 'r') as f_in:
                lines = f_in.readlines()

            output_lines = ["#!ascii label\n"]
            vertex_lines = []

            for line in lines:
                parts = line.strip().split()
                # Only process lines that contain vertex data
                if len(parts) >= 4 and parts[0].isdigit():
                    idx = int(parts[0])
                    x, y, z = parts[1:4]
                    vertex_lines.append((idx, x, y, z, roi_val))

            output_lines.append(f"{len(vertex_lines)}\n")
            for v in vertex_lines:
                output_lines.append(f"{v[0]} {v[1]} {v[2]} {v[3]} {v[4]}\n")

            with open(outname, 'w') as f_out:
                f_out.writelines(output_lines)

        except FileNotFoundError:
            print(f"File not found: {fname}")

# Step 2: Merge all edited label files into one label file per hemisphere
os.chdir(label_dir)

for hemi in ['lh', 'rh']:
    required_files = [f"{hemi}.manual{roi}edit.label" for roi in ['V1', 'V2', 'V3', 'V4', 'LO']]

    if all(os.path.isfile(f) for f in required_files):
        cmd = [
            "mri_mergelabels",
            "-i", f"{hemi}.manualV1edit.label",
            "-i", f"{hemi}.manualV2edit.label",
            "-i", f"{hemi}.manualV3edit.label",
            "-i", f"{hemi}.manualV4edit.label",
            "-i", f"{hemi}.manualLOedit.label",
            "-o", f"{hemi}.manualdelin_new.label"
        ]
        print(f"Merging {hemi} labels for {subject_id}...")
        subprocess.run(cmd, check=True)
    else:
        missing = [f for f in required_files if not os.path.isfile(f)]
        print(f"Skipping {hemi} merge for {subject_id}: missing {missing}")

print(f"Done. Merged labels saved in {label_dir}")
