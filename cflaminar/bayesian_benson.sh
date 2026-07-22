#!/bin/bash
# converts my manual pRF maps to mgz, runs neuropythy's retinotopic registration,
# then turns the inferred maps back into labels

subject="sub-$1"  # first arg is the subject number, e.g. "05" -> sub-05
denoising="nordic"

# make sure SUBJECTS_DIR is actually set before doing anything
if [ -z "$SUBJECTS_DIR" ]; then
    echo "SUBJECTS_DIR environment variable is not set." >&2
    exit 1
fi

# pull the project name out of SUBJECTS_DIR (whatever comes right after "projects/")
project_name=$(echo "$SUBJECTS_DIR" | awk -F'/' '{for(i=1;i<=NF;i++) if($i=="projects") print $(i+1)}')
if [ -z "$project_name" ]; then
    echo "Could not extract project name from SUBJECTS_DIR: $SUBJECTS_DIR" >&2
    exit 1
fi

echo "Using project name from SUBJECTS_DIR: $project_name"
echo "Subject: $subject"
echo "Denoising: $denoising"
echo "Project: $project_name"

freesurfer_dir="/scratch/hb-EGRET-AAA/projects/${project_name}/derivatives/freesurfer/${subject}/surf"

# convert my manual pRF morph files (pol/ecc/r2/sigma) to mgz, renaming them
# to what neuropythy expects (angle/eccen/vexpl/sigma), still need python+nibabel for this bit
python3 << EOF
import os
import numpy as np
import nibabel as nib
from nibabel.freesurfer.io import read_morph_data

freesurfer_dir = "${freesurfer_dir}"
rename = {"pol": "angle", "ecc": "eccen", "r2": "vexpl", "sigma": "sigma"}

for hemi in ["lh", "rh"]:
    for old, new in rename.items():
        data = read_morph_data(os.path.join(freesurfer_dir, "pRF/manual", f"{hemi}.{old}"))
        out_path = os.path.join(freesurfer_dir, f"{hemi}.all-{new}.mgz")
        nib.save(nib.MGHImage(data.astype(np.float32), affine=np.eye(4)), out_path)
EOF

cd "$freesurfer_dir" || exit 1

# run neuropythy's retinotopy registration using my manual maps as input
python -m neuropythy register_retinotopy "$subject" --verbose \
       --surf-outdir=. \
       --surf-format="mgz" \
       --no-volume-export \
       --lh-angle=lh.all-angle.mgz \
       --lh-eccen=lh.all-eccen.mgz \
       --lh-weight=lh.all-vexpl.mgz \
       --lh-radius=lh.all-sigma.mgz \
       --rh-angle=rh.all-angle.mgz \
       --rh-eccen=rh.all-eccen.mgz \
       --rh-weight=rh.all-vexpl.mgz \
       --rh-radius=rh.all-sigma.mgz

# convert the inferred maps neuropythy just spat out into label files
labels_dir="${freesurfer_dir}/labels"
mkdir -p "$labels_dir"

for hemi in lh rh; do
    for measure in eccen angle varea sigma; do
        mri_cor2label --i "${hemi}.inferred_${measure}.mgz" --id 1 --l "${labels_dir}/${hemi}.${measure}.label"
    done
done