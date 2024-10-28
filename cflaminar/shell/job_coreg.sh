#! /bin/sh
#$ -N coreg_anat2func
#$ -S /bin/sh
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt
#$ -pe smp 10

# Load modules
module load afni
module load AFNI #Habrok
module load ANTs
module load fsl/6.0.5.2
module load FSL #Habrok

# Usage: qsub -V job_coreg.sh [subject] [session] [task] e.g. qsub -V job_coreg.sh 001 1 ret
# Upsamples Nifti files

#set number of cores
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=10

echo "number of cores: ${ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS}"

subject=sub-$1
session=$2
task=$3

OLDPWD=${PWD}
PROJ_DIR=${DIR_DATA_HOME}
cd $PROJ_DIR

COREG_DIR=$PROJ_DIR/derivatives/coreg/${subject}/ses-${session}
if [[ ! -d $COREG_DIR ]]; then
  echo "Creating coreg folder"
  mkdir -p $COREG_DIR
else
  echo "$COREG_DIR folder already exists."
fi

Fixed=${COREG_DIR}/${subject}_ses-${session}_task-${task}_run-1_boldref.nii.gz
Fixed_sk=${COREG_DIR}/${subject}_ses-${session}_task-${task}_run-1_boldref_sk.nii.gz
Moving=${COREG_DIR}/${subject}_ses-${session}_acq-${ACQ}_desc-masked_T1w.nii.gz
Moving_sk=${COREG_DIR}/${subject}_ses-${session}_acq-${ACQ}_desc-masked_T1w_sk.nii.gz
spmMask=${COREG_DIR}/${subject}_ses-${session}_acq-${ACQ}_desc-spm_mask.nii.gz
bensonMask=${COREG_DIR}/${subject}_ses-${session}_desc-benson_mask.nii.gz

UP_DIR=$PROJ_DIR/derivatives/upsampling/${subject}/ses-${session} #folder with upsampled outputs
if [[ ! -f $Fixed ]]; then
  cp $UP_DIR/func/nordic/${subject}_ses-${session}_task-${task}_run-1_boldref.nii.gz $Fixed
fi

if [[ ! -f $Moving ]]; then
  if [[ ! -f $UP_DIR/anat/${subject}_ses-${session}_acq-${ACQ}_desc-masked_T1w.nii.gz ]]; then
    cp $UP_DIR/anat/${subject}_ses-${session}_acq-${ACQ}_T1w.nii.gz $Moving
  else
    cp $UP_DIR/anat/${subject}_ses-${session}_acq-${ACQ}_desc-masked_T1w.nii.gz $Moving
  fi  
fi

if [[ ! -f $spmMask ]]; then
  if [[ ! -f $UP_DIR/anat/${subject}_ses-${session}_acq-${ACQ}_desc-spm_mask.nii.gz ]]; then
    cp $UP_DIR/anat/${subject}_ses-${session}_acq-${ACQ}_desc-brain_mask.nii.gz $spmMask
  else
    cp $UP_DIR/anat/${subject}_ses-${session}_acq-${ACQ}_desc-spm_mask.nii.gz $spmMask
  fi  
fi

if [[ ! -f $bensonMask ]]; then
  cp $UP_DIR/anat/${subject}_ses-${session}_desc-benson_mask.nii.gz $bensonMask
fi

slabMask=${COREG_DIR}/${subject}_ses-${session}_desc-slabmask.nii.gz
bensonslabMask=${COREG_DIR}/${subject}_ses-${session}_desc-benson_slabmask.nii.gz

#Create slab mask
3dresample -master ${Fixed} -prefix ${slabMask} -input ${spmMask} -overwrite

#Create benson slab mask
3dresample -master ${slabMask} -prefix ${bensonslabMask} -input ${bensonMask} -overwrite

#Skullstrip func e T1w
fslmaths ${Moving} -mas ${spmMask} ${Moving_sk}
antsApplyTransforms --interpolation BSpline[5] -d 3 -i ${Moving_sk} -r ${Moving_sk} -o ${Moving_sk} -t ${PROJ_DIR}/derivatives/coreg/${subject}/ses-1/init_coreg.txt #forward transform

fslmaths ${Fixed} -mas ${slabMask} ${Fixed_sk}


#removed from antsRegistration: --initial-moving-transform ${COREG_DIR}/init_coreg.txt \
outputPrefix=${COREG_DIR}/out
echo "Calculating transform matrix..."


antsRegistration  --verbose 1 \
                  --dimensionality 3 \
                  --float 0 \
                  --interpolation BSpline[5] \
                  --use-histogram-matching 0 \
                  --winsorize-image-intensities [0.005,0.995] \
                  --collapse-output-transforms 1 \
                  --output [${outputPrefix},${outputPrefix}Warped.nii.gz,${outputPrefix}InverseWarped.nii.gz] \
                  --transform Rigid[0.2] \
                    --metric MI[${Fixed_sk},${Moving_sk},1,32,Regular,0.25] \
                    --convergence [1000x500x250x100,1e-6,10] \
                    --shrink-factors 12x8x4x2 \
                    --smoothing-sigmas 4x3x2x1vox \
                    --masks [${bensonslabMask},${bensonslabMask}] \
                  --transform Affine[0.2] \
                    --metric MI[${Fixed_sk},${Moving_sk},1,32,Regular,0.25] \
                    --convergence [1000x500x250x100,1e-6,10] \
                    --shrink-factors 12x8x4x2 \
                    --smoothing-sigmas 4x3x2x1vox \
                    --masks [${bensonslabMask},${bensonslabMask}] \
                  --transform Syn[0.1,3,0] \
                    --metric CC[${Fixed_sk},${Moving_sk},1,4] \
                    --convergence [50x50x200x200x300,1e-6,10] \
                    --shrink-factors 10x6x4x2x1 \
                    --smoothing-sigmas 5x3x2x1x0vox \
                    --masks [${bensonslabMask},${bensonslabMask}]

echo "Transform matrix calculated."

#antsApplyTransforms --interpolation BSpline[5] -d 3 -i ${Fixed} -r ${Fixed} -o ${COREG_DIR}/WarpedANAT.nii.gz -t [${outputPrefix}0GenericAffine.mat, 1]

#Affine for checking before applying Syn warping
antsApplyTransforms --interpolation BSpline[5] -d 3 -i ${Moving} -r ${Moving} -o ${COREG_DIR}/${subject}_ses-${session}_acq-MP2RAGE_desc-masked_T1wAffine.nii.gz -t ${outputPrefix}0GenericAffine.mat  -t ${PROJ_DIR}/derivatives/coreg/${subject}/ses-1/init_coreg.txt #forward transform
#Syn warping
antsApplyTransforms --interpolation BSpline[5] -d 3 -i ${Moving} -r ${Moving} -o ${COREG_DIR}/${subject}_ses-${session}_acq-MP2RAGE_desc-masked_T1wWarped.nii.gz -t ${outputPrefix}1Warp.nii.gz -t ${outputPrefix}0GenericAffine.mat -t ${PROJ_DIR}/derivatives/coreg/${subject}/ses-1/init_coreg.txt #forward transform

#reset number of threads
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1
