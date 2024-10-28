#! /bin/sh
#$ -N spmMoCo
#$ -S /bin/sh
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt
#$ -V
#SBATCH --job-name=spmMoCo
#SBATCH --time=2:00:00
#SBATCH --partition=regular
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1

#Usage: qsub -V job_spmmoco.sh [subject] [task] [ses] [nruns]; will search for bold files in /Project/derivatives/fmriprep/sub-xxx/ses-x/func
# module load matlab/R2021b   #SoG(Spinoza)
module load MATLAB/2022b-r5 #Habrok (RUG)


PROJ_DIR=${DIR_DATA_HOME}
subject=sub-$1
task=$2
ses=$3
nruns=$4
SPM_DIR=${PROJ_DIR}/derivatives/spm
NoMoCo_DIR=${SPM_DIR}/${subject}/ses-${ses}/no_moco
OUT_DIR=${SPM_DIR}/${subject}/ses-${ses}/func
fmriprep_DIR=${PROJ_DIR}/derivatives/fmriprep   ####

if [[ ! -d ${PROJ_DIR}/derivatives/fmriprep/${subject} ]]; then
  fmriprep_flag=0
  INPUT_DIR=${PROJ_DIR}
  # INPUT_DIR=${PROJ_DIR}
  echo "No fmriprep data found $subject."
else
  fmriprep_flag=1
  INPUT_DIR=${PROJ_DIR}
  echo "Fmriprep data found for $subject."
fi

if [[ ! -d $NoMoCo_DIR ]]; then
  echo "Creating $NoMoCo_DIR folder"
  mkdir -p $NoMoCo_DIR
else
  echo "$NoMoCo_DIR folder already exists."
fi

if [[ ! -d $OUT_DIR ]]; then
  echo "Creating $OUT_DIR folder"
  mkdir -p $OUT_DIR
else
  echo "$OUT_DIR folder already exists."
fi

for run in $(seq "$nruns")
do
if [[ ${fmriprep_flag} == "1" ]]; then
     cp ${INPUT_DIR}/${subject}/ses-${ses}/func/${subject}_ses-${ses}_task-${task}_run-${run}_bold.nii.gz ${NoMoCo_DIR}
else
     cp ${INPUT_DIR}/${subject}/ses-${ses}/func/${subject}_ses-${ses}_task-${task}_run-${run}_bold.nii.gz ${NoMoCo_DIR}
fi
done

cd ${PATH_HOME}/programs/cflaminar/shell
echo "Running spmMoCo on project ${PROJECT}, ${subject}, ses-${ses}, task-${task}"

if [[ ${nruns} == "4" ]]; then
    matlab -nodesktop -nodisplay -nosplash -r "main_spmmoco('${PROJECT}', '$1')"
elif [[ ${nruns} == "5" ]]; then
    matlab -nodesktop -nodisplay -nosplash -r "main_spmmoco_5runs('${PROJECT}', '$1')"
elif [[ ${nruns} == "6" ]]; then
    matlab -nodesktop -nodisplay -nosplash -r "main_spmmoco_6runs('${PROJECT}', '$1')"
else
    echo "Sorry, I can only process 4 to 6 runs."
    break
fi

until [ -f ${OUT_DIR}/meansub-${1}_ses-${ses}_task-${task}_run-1_bold.nii ]
do
    echo "Waiting for spm MoCo to finish..."
    sleep 1
done

echo "SPM MoCo finished. Cleaning directory and compressing files..."

cd ${OUT_DIR}

rm -r sub*

for run in $(seq "$nruns")
do
    gzip -c r${subject}_ses-${ses}_task-${task}_run-${run}_desc-preproc_bold.nii > ${subject}_ses-${ses}_task-${task}_run-${run}_desc-preproc_bold.nii.gz
    gzip -c r${subject}_ses-${ses}_task-${task}_run-${run}_bold.nii > ${subject}_ses-${ses}_task-${task}_run-${run}_bold.nii.gz
done

gzip -c mean${subject}_ses-${ses}_task-${task}_run-1_desc-preproc_bold.nii > ${subject}_ses-${ses}_task-${task}_run-1_boldref.nii.gz
gzip -c mean${subject}_ses-${ses}_task-${task}_run-1_bold.nii > ${subject}_ses-${ses}_task-${task}_run-1_boldref.nii.gz

rm -r *.nii

if [[ $fmriprep_flag == 1 ]]; then
  echo "Replacing fmriprep files by SPM motion corrected files."
  cp ${DERIVATIVES}/spm/${subject}/ses-${ses}/func/*.nii.gz ${DERIVATIVES}/fmriprep/${subject}/ses-${ses}/func/
else
  echo "Preparing coreg folder for manual coregistration."
  mkdir -p ${DERIVATIVES}/coreg/${subject}/ses-${ses}/func
  cp ${DERIVATIVES}/spm/${subject}/ses-${ses}/func/*.nii.gz ${DERIVATIVES}/coreg/${subject}/ses-${ses}/func/
  mkdir -p ${DERIVATIVES}/coreg/${subject}/ses-01/anat
  cp ${INPUT_DIR}/derivatives/denoised/${subject}/ses-01/*T1w.nii.gz ${DERIVATIVES}/coreg/${subject}/ses-01/anat/
  echo "Finished."
fi