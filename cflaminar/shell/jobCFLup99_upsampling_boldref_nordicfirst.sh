#! /bin/sh
#$ -N ups_boldref
#$ -S /bin/sh
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt

# Load modules
# module load afni

# Usage: source upsampling.sh sub-xxx / qsub -V script.sh sub-xxx
# Upsamples Nifti files

subject=sub-$1
session=1

# module load fsl

OLDPWD=${PWD}
PROJ_DIR=/data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp
cd $PROJ_DIR

# Boldref
# Upsampling nifti and copying json files from original bids folder to derivatives/upsampling

UP_DIR=$PROJ_DIR/derivatives/upsampling/${subject}/ses-${session}/func

if [[ ! -d $UP_DIR ]]; then
  echo "$UP_DIR does not exist. Run upsampling_func."
  exit 1
fi

for denoising in nordic
do
  NII_DIR=$UP_DIR/${denoising}
  for suffix in ret_run-5 ret_run-6 #ret_run-1 ret_run-2 ret_run-3 ret_run-4
  do
  filename=${subject}_ses-${session}_task-${suffix}_boldref
  if [[ ! -f ${NII_DIR}/${filename}.nii.gz ]]; then
    if [[ $denoising == "nordic" ]]; then
    fslmaths ${NII_DIR}/${subject}_ses-${session}_task-${suffix}_desc-preproc_bold_ores.nii.gz -Tmean ${NII_DIR}/${filename}.nii.gz
    # elif [[ $denoising == "nordic" ]]; then
    # fslmaths ${NII_DIR}/${subject}_ses-${session}_task-${suffix}_desc-nordic_bold_ores.nii.gz -Tmean ${NII_DIR}/${filename}.nii.gz
    # elif [[ $denoising == "no_preproc" ]]; then
    # fslmaths ${NII_DIR}/${subject}_ses-${session}_task-${suffix}_bold_ores.nii.gz -Tmean ${NII_DIR}/${filename}.nii.gz
    fi
    # Backing up and replacing files with original resolution by upsampled files
    if [[ ! -f ${NII_DIR}/${filename}_ores.nii.gz ]]; then
      cp ${NII_DIR}/${filename}.nii.gz ${NII_DIR}/${filename}_ores.nii.gz
    else
    echo "backup of original resolution ${suffix} file already exists"
    fi
  3dresample -dxyz 0.4 0.4 0.4 -rmode Cubic -prefix ${NII_DIR}/${filename}.nii.gz -input ${NII_DIR}/${filename}.nii.gz -overwrite
  echo "replaced original ${suffix} file by upsampled in ${NII_DIR}."
  fi
  done
done

cd ${OLDPWD}
