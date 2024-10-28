#! /bin/sh
#$ -N ups_boldref
#$ -S /bin/sh
#$ -j y
#$ -q short.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt

# Load modules
# module load afni

# Usage: source script_name.sh [subject] [session] [new resolution]/E.g. qsub -V script.sh 001 1 0.8
# Upsamples Nifti files

subject=sub-$1
session=$2

# module load fsl

OLDPWD=${PWD}
PROJ_DIR=${DIR_DATA_HOME}
cd $PROJ_DIR

# Boldref
# Upsampling nifti and copying json files from original bids folder to derivatives/upsampling

denoising='nordic'

UP_DIR=$PROJ_DIR/derivatives/upsampling/${subject}/ses-${session}/func/${denoising}

if [[ ! -d $UP_DIR ]]; then
  echo "$UP_DIR does not exist. Run upsampling_func."
  exit 1
fi

NII_DIR=$PROJ_DIR/derivatives/spm/${subject}/ses-${session}/func
suffix='RET_run-1' 
filename=${subject}_ses-${session}_task-${suffix}_boldref
if [[ ! -f ${UP_DIR}/${filename}_ores.nii.gz ]]; then
cp ${NII_DIR}/${filename}.nii.gz ${UP_DIR}/${filename}_ores.nii.gz
else
echo "backup of original resolution ${suffix} file already exists"
fi
3dresample -dxyz ${new_res} ${new_res} ${new_res} -rmode Cubic -prefix ${UP_DIR}/${filename}.nii.gz -input ${NII_DIR}/${filename}.nii.gz -overwrite
echo "replaced original ${suffix} file by upsampled in ${UP_DIR}."

cd ${OLDPWD}
