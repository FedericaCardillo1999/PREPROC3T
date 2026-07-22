#!/usr/bin/env bash
# Usage: source /home2/p315561/programs/cflaminar/shell/atlas/standard_benson.sh subj project
# e.g.: source standard_benson.sh 05 UMCG
# Projects the Benson atlas labels onto the subject's surface, saved into derivatives/freesurfer/subject/label

subject=sub-$1        # first arg is the subject number, e.g. "05" -> sub-05
project=$2            # second arg is the project name, e.g. "UMCG"

DERIV_DIR=/scratch/hb-EGRET-AAA/projects/${project}/derivatives
FS_DIR=${DERIV_DIR}/freesurfer/${subject}

# run neuropythy to predict the Benson atlas (eccen, sigma, angle, varea) for this subject based on their anatomy, and export as volume files
python -m neuropythy atlas $subject --volume-export --verbose

# convert the Benson surface maps (.mgz) into label files so pycortex can read them
for lbl in eccen sigma angle varea
do
  # left hemisphere
  mri_surfcluster --in ${FS_DIR}/surf/lh.benson14_${lbl}.mgz --subject $subject --hemi lh --thmin 0 --sign abs --no-adjust --olab ${FS_DIR}/label/lh.benson14_${lbl}
  # right hemisphere
  mri_surfcluster --in ${FS_DIR}/surf/rh.benson14_${lbl}.mgz --subject $subject --hemi rh --thmin 0 --sign abs --no-adjust --olab ${FS_DIR}/label/rh.benson14_${lbl}
done

# build a dilated binary mask covering V1-V3 and LO1-LO2 (codes 1,2,3,7,8 in the varea map)
# dilate by 3 voxels to give a bit of buffer around the strict roi boundaries
mkdir -p ${DERIV_DIR}/benson_mask/${subject}/ses-1
mri_binarize --dilate 3 --i ${FS_DIR}/mri/benson14_varea.mgz --match 1 2 3 7 8 --o ${DERIV_DIR}/benson_mask/${subject}/ses-1/${subject}_ses-1_desc-benson_mask.nii.gz

conda deactivate
