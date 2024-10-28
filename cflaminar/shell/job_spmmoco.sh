#! /bin/sh
#$ -N spmMoCo
#$ -S /bin/sh
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt
#$ -V


#Usage: qsub -V job_spmmoco.sh [Project_name] [subject] [nruns]; will search for bold files in /Project/sub-xxx/func
module load matlab/R2021b


PROJ_DIR=${DIR_DATA_HOME}
subject=sub-$2
SPM_DIR=${PROJ_DIR}/derivatives/spm/
NoMoCo_DIR=${SPM_DIR}/${subject}/ses-1/no_moco
OUT_DIR=${SPM_DIR}/${subject}/ses-1/func
fmriprep_DIR=${PROJ_DIR}/derivatives/fmriprep/
nruns=$3

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
    cp ${fmriprep_DIR}/${subject}/ses-1/func/${subject}_ses-1_task-ret_run-${run}_desc-preproc_bold.nii.gz ${NoMoCo_DIR}
done

cd ${PATH_HOME}/programs/cflaminar/shell
echo "Running spmMoCo on project $1, ${subject}"

if [[ ${nruns} == "4" ]]; then
    matlab -nodesktop -nodisplay -nosplash -r "main_spmmoco('$1', '$2')"
elif [[ ${nruns} == "5" ]]; then
    matlab -nodesktop -nodisplay -nosplash -r "main_spmmoco_5runs('$1', '$2')"
elif [[ ${nruns} == "6" ]]; then
    matlab -nodesktop -nodisplay -nosplash -r "main_spmmoco_6runs('$1', '$2')"
else
    echo "Sorry, I can only process 4 to 6 runs."
    break
fi

until [ -f ${OUT_DIR}/meansub-${2}_ses-1_task-ret_run-1_desc-preproc_bold.nii ]
do
    echo "Waiting for spm MoCo to finish..."
    sleep 1
done

echo "SPM MoCo finished. Cleaning directory and compressing files..."

cd ${OUT_DIR}
rm -r sub*

for run in $(seq "$nruns")
do
    gzip -c r${subject}_ses-1_task-ret_run-${run}_desc-preproc_bold.nii > ${subject}_ses-1_task-ret_run-${run}_desc-preproc_bold.nii.gz
done

gzip -c mean${subject}_ses-1_task-ret_run-1_desc-preproc_bold.nii > ${subject}_ses-1_task-ret_run-1_boldref.nii.gz

rm -r *.nii

cp ${DERIVATIVES}/spm/${subject}/ses-1/func/*.nii.gz ${DERIVATIVES}/fmriprep/${subject}/ses-1/func/

echo "Finished."
