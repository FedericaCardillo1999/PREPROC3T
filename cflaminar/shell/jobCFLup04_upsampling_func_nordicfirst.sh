#! /bin/sh
#$ -N ups_func
#$ -S /bin/sh
#$ -j y
#$ -q short.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt

# Load modules
module load AFNI

# Usage: source script_name.sh [subject] [session] [task] [nruns] [new_resolution]/E.g. qsub -V script_name.sh 001 1 ret 4 0.8
# Upsamples Nifti files

subject=sub-$1
session=$2
task=$3
nruns=$4
new_res=$5

OLDPWD=${PWD}
PROJ_DIR=${DIR_DATA_HOME}
cd $PROJ_DIR

# Fmriprep - No NORDIC, No Pybest
# Upsampling nifti and copying json files from original bids folder to derivatives/upsampling


for denoising in nordic
do

  UP_DIR=$PROJ_DIR/derivatives/upsampling/${subject}/ses-${session}/func/${denoising}
  if [[ ! -d $UP_DIR ]]; then
    echo "Creating $UP_DIR  folder"
    mkdir -p $UP_DIR
  else
    echo "$UP_DIR  folder already exists."
  fi

  for run in $(seq "$nruns")
  do
    if [[ ${denoising} == "nordic" ]]; then
    NII_DIR=$PROJ_DIR/${subject}/ses-${session}/func
    filename=${subject}_ses-${session}_task-${task}_run-${run}_bold
    # elif [[ ${denoising} == "nordic" ]]; then
    # NII_DIR=$PROJ_DIR/${subject}/ses-1/func
    # filename=${subject}_ses-${session}_task-${suffix}_desc-nordic_bold
    # elif [[ ${denoising} == "no_preproc" ]]; then
    # NII_DIR=$PROJ_DIR/${subject}/ses-${session}/orig
    # filename=${subject}_ses-${session}_task-${suffix}_bold
    fi
    if [[ ! -f ${UP_DIR}/${filename}.nii.gz ]]; then
    3dresample -dxyz ${new_res} ${new_res} ${new_res} -rmode Cubic -prefix ${UP_DIR}/${filename}.nii.gz -input ${NII_DIR}/${filename}.nii.gz
    echo "Upsampling of run ${run} completed."
    # Backing up and replacing files with original resolution by upsampled files
    if [[ ! -f ${UP_DIR}/${filename}_ores.nii.gz ]]; then
      cp ${NII_DIR}/${filename}.nii.gz ${UP_DIR}/${filename}_ores.nii.gz
    else
      echo "backup of original resolution ${suffix} file already exists"
    fi
    fi
  done
done

cd ${OLDPWD}