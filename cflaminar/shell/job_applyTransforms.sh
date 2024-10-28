#!/bin/sh

#$ -N antsTransform
#$ -S /bin/sh
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt

#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --mem=20GB

# Load modules
module load AFNI
module load ANTs

# Usage: source upsampling.sh sub-xxx
# Upsamples Nifti files

subject=sub-$1
session=$2
task=$3
nruns=$4

OLDPWD=${PWD}
PROJ_DIR=/scratch/hb-EGRET-AAA/projects/EGRET+
cd $PROJ_DIR

COREG_DIR=$PROJ_DIR/derivatives/coreg/${subject}/ses-${session}

T1w=$PROJ_DIR/derivatives/coreg/${subject}/ses-01/anat/${subject}_ses-01_acq-MPRAGE_T1w.nii.gz     
EPI_mean=${COREG_DIR}/func/${subject}_ses-${session}_task-${task}_run-1_boldref.nii.gz   
outputPrefix=${COREG_DIR}/out

#Transform EPI

antsApplyTransforms --interpolation BSpline[5] -d 3 -i ${EPI_mean} -r ${T1w} -o ${COREG_DIR}/func/${subject}_ses-${session}_task-${task}_run-1_boldref_transformed.nii.gz -t ${PROJ_DIR}/derivatives/coreg/${subject}/ses-${session}/func/init_coreg.txt

for run in $(seq "$nruns")
do
EPI=${COREG_DIR}/func/${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz
echo "applying transforms to bold files..."
antsApplyTransforms --interpolation BSpline[5] -d 3 -e 3 -i ${EPI} -r ${EPI_mean} -o ${COREG_DIR}/func/${subject}_ses-${session}_task-${task}_run-${run}_bold_transformed.nii.gz -t ${PROJ_DIR}/derivatives/coreg/${subject}/ses-${session}/func/init_coreg.txt -v 1
cp ${COREG_DIR}/func/${subject}_ses-${session}_task-${task}_run-${run}_bold_transformed.nii.gz ${PROJ_DIR}/${subject}/ses-${session}/func/${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz
done
