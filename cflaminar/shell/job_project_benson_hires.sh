#! /bin/bash
#! /usr/bin/env python
#! /usr/bin/env bash
#$ -N bensons_hires
#$ -S /bin/sh
#$ -j y
#$ -q short.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt
#$ -V
# Usage: source project_benson.sh xxx
# Projects the labels from Benson to the subject inside derivatives/freesurfer/subject/labels

subject=sub-$1

export SURF_DIR=${DIR_DATA_DERIV}/freesurfer/$subject

conda activate mypy311 # not necessary, should be activated in the terminal though
python -m neuropythy atlas $subject --volume-export --verbose

#create labels for pycortex
for lbl in eccen sigma angle varea
do
  mri_surfcluster --in ${SURF_DIR}/surf/lh.benson14_${lbl}.mgz --subject $subject --hemi lh --thmin 0 --sign pos --no-adjust --olab ${SURF_DIR}/label/lh.benson14_${lbl}
  mri_surfcluster --in ${SURF_DIR}/surf/rh.benson14_${lbl}.mgz --subject $subject --hemi rh --thmin 0 --sign pos --no-adjust --olab ${SURF_DIR}/label/rh.benson14_${lbl}
done

conda deactivate

#cp -r ${SURF_DIR} ${DIR_DATA_DERIV}/fs_hires
