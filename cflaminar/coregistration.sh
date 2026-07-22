#!/bin/bash
# apply_coreg.sh
# Usage: bash apply_coreg.sh subject task project nruns [session]

subject=$1
task=$2
project=$3
nruns=$4
session=$5

module load AFNI
module load ANTs
module load FSL

# Project settings
if [ "$project" == "OVGU" ]; then
    PROJ_DIR=/scratch/hb-EGRET-AAA/projects/OVGU; T1w_acq=MPRAGE; T1w_suffix=T1w
elif [ "$project" == "RS-7T" ]; then
    PROJ_DIR=/scratch/hb-EGRET-AAA/projects/RS-7T; T1w_acq=MP2RAGE; T1w_suffix=T1w_resampled; session=01
elif [ "$project" == "EGRET+" ]; then
    PROJ_DIR=/scratch/hb-EGRET-AAA/projects/EGRET+; T1w_acq=MPRAGE; T1w_suffix=T1w
else
    echo "Unknown project: ${project}. Options: OVGU, RS-7T, EGRET+"; exit 1
fi

# Auto-detect session for EGRET+
if [ "$project" == "EGRET+" ] && [ -z "$session" ]; then
    for s in 01 02 03; do
        CHECK_FILE=${PROJ_DIR}/derivatives/coreg/${subject}/ses-${s}/func/${subject}_ses-${s}_task-${task}_run-1_bold.nii.gz
        if [ -f "$CHECK_FILE" ]; then
            session=$s
            break
        fi
    done
    if [ -z "$session" ]; then
        echo "Error: Could not find task ${task} for ${subject}"; exit 1
    fi
fi

ANAT_DIR=${PROJ_DIR}/derivatives/coreg/${subject}/ses-01/anat
T1w=${ANAT_DIR}/${subject}_ses-01_acq-${T1w_acq}_${T1w_suffix}.nii.gz
transform=${ANAT_DIR}/init_coreg.txt
NII_DIR=${PROJ_DIR}/derivatives/coreg/${subject}/ses-${session}/func

# Apply transform to boldref
boldref=${NII_DIR}/${subject}_ses-${session}_task-${task}_run-1_boldref.nii.gz
antsApplyTransforms --interpolation "BSpline[5]" -d 3 \
    -i ${boldref} \
    -r ${T1w} \
    -o ${NII_DIR}/${subject}_ses-${session}_task-${task}_run-1_boldref_transformed.nii.gz \
    -t ${transform}

# Apply transform to each BOLD run
for run in $(seq "$nruns"); do
    EPI=${NII_DIR}/${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz
    OUTPUT=${NII_DIR}/${subject}_ses-${session}_task-${task}_run-${run}_bold_transformed.nii.gz

    if [ -f "$EPI" ]; then
        echo "Applying transforms to run ${run}..."
        antsApplyTransforms --interpolation Linear -d 3 -e 3 \
            -i ${EPI} \
            -r ${T1w} \
            -o ${OUTPUT} \
            -t ${transform} \
            -v 1
    fi
done
