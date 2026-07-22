#!/bin/sh

# Usage: source /home2/p315561/programs/cflaminar/shell/layers/generate_layers.sh <subject_number>
#
# Generates 10 equal-volume surfaces between white matter and pial for each
# hemisphere, using Wagstyl's equivolumetric surface tool. These are the
# surfaces the layer-resampling script later projects the functional data onto.

subject=sub-$1
session=01

export SUBJECTS_DIR=/scratch/hb-EGRET-AAA/projects/7T/derivatives/freesurfer
FS_DIR=${SUBJECTS_DIR}
OUT_DIR=${FS_DIR}/${subject}/surf
TOOL_DIR=/home2/p315561/programs/surface_tools/surface_tools/equivolumetric_surfaces

for hemi in lh rh; do
  echo "Generating equivolumetric surfaces for ${subject}, hemi-${hemi}"
  python ${TOOL_DIR}/generate_equivolumetric_surfaces.py \
    --smoothing 0 \
    ${FS_DIR}/${subject}/surf/${hemi}.white \
    ${FS_DIR}/${subject}/surf/${hemi}.pial \
    10 \
    ${OUT_DIR}/${hemi}.equi \
    --software freesurfer \
    --subject_id ${subject}
done

echo "Done generating equivolumetric surfaces for ${subject}."