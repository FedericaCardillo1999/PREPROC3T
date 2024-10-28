#! /bin/sh
#$ -N wagstyl
#$ -S /bin/sh
#$ -j y
#$ -q short.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt

# Usage: source script.sh xxx / qsub -V script.sh 001

subject=sub-$1
session=1

PROJ_DIR=${DIR_DATA_HOME}
TOOL_DIR=${PATH_HOME}/programs/packages/surface_tools-master/equivolumetric_surfaces
FS_DIR=${PROJ_DIR}/derivatives/freesurfer/
OUT_DIR=${FS_DIR}/${subject}/surf

for hemi in lh rh
do
python ${TOOL_DIR}/generate_equivolumetric_surfaces.py --smoothing 0 ${FS_DIR}/${subject}/surf/${hemi}.white ${FS_DIR}/${subject}/surf/${hemi}.pial 9 ${OUT_DIR}/${hemi}.equi --software freesurfer --subject_id ${subject}
done
