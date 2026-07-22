#!/bin/sh

# Usage: source /home2/p315561/programs/cflaminar/shell/layers/visualizing_layers.sh.sh <subject_number>

export SUBJECTS_DIR=/scratch/hb-EGRET-AAA/projects/7T/derivatives/freesurfer
subject=sub-$1
session=01
denoising=nordic_sm4

PROJ_DIR=/scratch/hb-EGRET-AAA/projects/7T
RESAMPLED_DIR=${PROJ_DIR}/derivatives/resampled/${subject}/ses-${session}/${denoising}
FS_SURF_DIR=${SUBJECTS_DIR}/${subject}/surf

# depths you actually have
depths="0.3333333333333333 0.5555555555555556 0.7777777777777778"

echo "Creating FreeSurfer layer overlays for ${subject}"
for hemi in L R; do
  if [ "$hemi" = "L" ]; then fshemi=lh; else fshemi=rh; fi
  for depth in $depths; do
    in_gii=${RESAMPLED_DIR}/${subject}_ses-01_task-RestingState_run-1_space-fsnative_hemi-${hemi}_desc-${denoising}_bold_${depth}.gii
    out_mgh=${FS_SURF_DIR}/${fshemi}.layer_${depth}_${denoising}.mgh
    echo "Converting $in_gii -> $out_mgh"
    mri_convert $in_gii $out_mgh
  done
done
echo "Done. Overlays saved in ${FS_SURF_DIR}"

# quick QC view of the first depth in freeview, change $depth below (or loop
# over $depths yourself) to look at a different layer
depth=$(echo $depths | cut -d' ' -f1)
freeview \
  -f ${FS_SURF_DIR}/lh.inflated:overlay=${FS_SURF_DIR}/lh.layer_${depth}_${denoising}.mgh \
     ${FS_SURF_DIR}/rh.inflated:overlay=${FS_SURF_DIR}/rh.layer_${depth}_${denoising}.mgh