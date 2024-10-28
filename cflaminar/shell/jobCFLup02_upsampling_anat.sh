#! /bin/sh
#$ -N ups_anat
#$ -S /bin/sh
#$ -j y
#$ -q short.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt
#$ -V

# Load modules
# module load afni
module load AFNI #Habrok

# Usage: qsub -V job_upsampling_anat.sh [subject] [session] [new resolution]/E.g. qsub -V script.sh 001 1 0.8
# Upsamples Nifti files

subject=sub-$1
session=$2
new_res=$3
echo "Running subject: $subject, session $session"

OLDPWD=${PWD}
PROJ_DIR=${DIR_DATA_HOME}

cd $PROJ_DIR

# ANAT
# Upsampling nifti and copying json files from original bids folder to derivatives/upsampling
UP_DIR=$PROJ_DIR/derivatives/upsampling/${subject}/ses-${session}/anat
if [[ ! -d $UP_DIR ]]; then
  echo "Creating anat folder"
  mkdir -p $UP_DIR
else
  echo "anat folder already exists."
fi
echo "Acquisition: ${ACQ}"

for suffix in acq-${ACQ}_T1w 
do
  if [[ ${suffix} == "acq-${ACQ}_T1w" ]]; then
    NII_DIR=$PROJ_DIR/derivatives/denoised/${subject}/ses-${session}
  fi
  
  # Backing up original resolution files
  if [[ ! -f ${UP_DIR}/${subject}_ses-${session}_${suffix}_ores.nii.gz ]]; then
    cp ${NII_DIR}/${subject}_ses-${session}_${suffix}.nii.gz ${UP_DIR}/${subject}_ses-${session}_${suffix}_ores.nii.gz
  else
    echo "backup of original resolution ${suffix} file already exists"
  fi
  if [[ ! -f ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz ]]; then
    cp ${UP_DIR}/${subject}_ses-${session}_${suffix}_ores.nii.gz ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz
    3dWarp -deoblique -prefix ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz -newgrid ${new_res} ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz -overwrite > ${UP_DIR}/orient${suffix}_ores.1D

  # 3dresample -dxyz 0.4 0.4 0.4 -rmode Cu -overwrite -prefix ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz -input ${UP_DIR}/${subject}_ses-${session}_${suffix}_ores.nii.gz
  # 3dWarp -deoblique ${UP_DIR}/${subject}_ses-${session}_${suffix}_ores.nii.gz -overwrite > ${UP_DIR}/orient${suffix}_ores.1D
  # 3dAllineate -trilinear -1Dmatrix_apply ${UP_DIR}/orient${suffix}_ores.1D -prefix ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz -overwrite
    cp -TRv ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz ${NII_DIR}/${subject}_ses-${session}_${suffix}.nii.gz
    echo "${suffix} upsampled."
  else
    echo "${suffix} upsampled already exists."
  fi
done

# 3dresample -dxyz 0.4 0.4 0.4 -rmode Cu -overwrite -prefix ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz -input ${UP_DIR}/${subject}_ses-${session}_${suffix}_ores.nii.gz
# 3dWarp -card2oblique ${UP_DIR}/${subject}_ses-${session}_${suffix}_ores.nii.gz -verb ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz -overwrite > ${UP_DIR}/orient${suffix}_ores.1D
# 3dAllineate -trilinear -1Dmatrix_apply ${UP_DIR}/orient${suffix}_ores.1D -prefix ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz ${UP_DIR}/${subject}_ses-${session}_${suffix}.nii.gz -overwrite
#

#Replace
# # Replacing original bids folder to with derivatives/upsampling
# NII_DIR=$PROJ_DIR/${subject}/ses-${session}/anat
# UP_DIR=$PROJ_DIR/derivatives/upsampling/${subject}/ses-${session}/anat
# cp  -TRv $UP_DIR $NII_DIR