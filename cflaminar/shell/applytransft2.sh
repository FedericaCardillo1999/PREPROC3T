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

# Usage: source upsampling.sh sub-xxx session task
# Transforms T2-weighted Nifti files

subject=sub-$1
session=$2

OLDPWD=${PWD}
PROJ_DIR=/scratch/hb-EGRET-AAA/projects/EGRET+
cd $PROJ_DIR

T1w=$PROJ_DIR/${subject}/ses-01/anat/${subject}_ses-01_acq-MPRAGE_T1w.nii.gz     
T2w=$PROJ_DIR/${subject}/ses-${session}/anat/${subject}_ses-${session}_acq-spacecorp2iso_run-1_T2w.nii.gz   
outputPrefix=$PROJ_DIR/out

# Transform T2-weighted image
echo "Applying transforms to T2-weighted image..."
antsApplyTransforms --interpolation BSpline[5] -d 3 -i ${T2w} -r ${T1w} -o $PROJ_DIR/${subject}/ses-${session}/anat/${subject}_ses-${session}_acq-spacecorp2iso_run-1_T2w_transformed.nii.gz -t $PROJ_DIR/${subject}/ses-01/anat/init_coreg.txt -v 1

# Copy transformed T2-weighted image to the appropriate directory
cp $PROJ_DIR/${subject}/ses-${session}/anat/${subject}_ses-${session}_acq-spacecorp2iso_run-1_T2w_transformed.nii.gz ${PROJ_DIR}/${subject}/ses-${session}/anat/${subject}_ses-${session}_acq-spacecorp2iso_run-1_T2w.nii.gz