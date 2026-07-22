#!/bin/bash

#SBATCH --job-name=spmMoCo
#SBATCH --time=2:00:00
#SBATCH --partition=regular
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1

# Usage: source /home2/p315561/programs/cflaminar/shell/motion_correction/moco.sh <subject_number> <task> <project>
#
# Finds which session has this task, copies the raw (still zipped) bold
# files into no_moco/, runs SPM motion correction via main_spmmoco.m (which
# handles its own unzipping and run-count detection), then gzips the
# outputs and sets up a coreg folder for the next pipeline step.

MATLAB_BIN="/cvmfs/hpc.rug.nl/versions/2023.01/rocky8/x86_64/generic/software/MATLAB/2022b-r5/bin/matlab"
MOCO_DIR=/home2/p315561/programs/cflaminar/shell/motion_correction

subject=sub-$1
task=$2
project=$3

PROJ_DIR=/scratch/hb-EGRET-AAA/projects/${project}
INPUT_DIR=${PROJ_DIR}
DERIVATIVES=${PROJ_DIR}/derivatives
SPM_DIR=${DERIVATIVES}/spm

# find which session has this task, and how many runs it has
session=""
nruns=0
for ses in 01 02; do
  func_dir=${INPUT_DIR}/${subject}/ses-${ses}/func
  if [ -d "$func_dir" ]; then
    count=$(find "$func_dir" -maxdepth 1 -type f -name "${subject}_ses-${ses}_task-${task}_run-*_bold.nii.gz" | wc -l)
    if [ "$count" -gt 0 ]; then
      session=$ses
      nruns=$count
      echo "Found $nruns run(s) for task ${task} in ses-${session}"
      break
    fi
  fi
done

if [ -z "$session" ] || [ "$nruns" -eq 0 ]; then
  echo "No runs found for ${subject}, task ${task}"
  exit 1
fi

NoMoCo_DIR=${SPM_DIR}/${subject}/ses-${session}/no_moco
OUT_DIR=${SPM_DIR}/${subject}/ses-${session}/func
mkdir -p "$NoMoCo_DIR"
mkdir -p "$OUT_DIR"

# copy the raw functional files into no_moco - still zipped, main_spmmoco.m
# does its own unzipping, don't gunzip here or it'll find nothing to unzip
echo "Copying functional files..."
for run in $(seq "$nruns"); do
    cp ${INPUT_DIR}/${subject}/ses-${session}/func/${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz ${NoMoCo_DIR}
done

cd "$MOCO_DIR"
echo "Running spmMoCo on project ${project}, ${subject}, ses-${session}, task-${task}, with ${nruns} runs"
$MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco('${project}', '${subject}', '${session}', '${task}'); exit"

# make sure MATLAB actually produced output before doing anything destructive
if ! ls ${OUT_DIR}/mean${subject}_ses-${session}_task-${task}_run-1_bold.nii 1> /dev/null 2>&1; then
    echo "SPM MoCo output not found. Exiting."
    exit 1
fi

cd "$OUT_DIR"
# remove the plain unzipped originals SPM copied into func, keeping only
# the r-prefixed (realigned) and mean-prefixed outputs
rm -f sub*

for run in $(seq "$nruns"); do
    gzip -c r${subject}_ses-${session}_task-${task}_run-${run}_bold.nii > ${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz
done
gzip -c mean${subject}_ses-${session}_task-${task}_run-1_bold.nii > ${subject}_ses-${session}_task-${task}_run-1_boldref.nii.gz
rm -f *.nii

mkdir -p ${DERIVATIVES}/coreg/${subject}/ses-${session}/func
cp ${OUT_DIR}/*.nii.gz ${DERIVATIVES}/coreg/${subject}/ses-${session}/func/

# NOTE: T1w source kept at ses-01 to match the original script exactly -
# double check this is correct if this subject's anat isn't under ses-01
mkdir -p ${DERIVATIVES}/coreg/${subject}/ses-01/anat
cp ${DERIVATIVES}/denoised/${subject}/ses-01/*T1w.nii.gz ${DERIVATIVES}/coreg/${subject}/ses-01/anat/

echo "Finished."