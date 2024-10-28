#! /bin/sh
#$ -N resampling_GM
#$ -S /bin/sh
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt

#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --mem=20GB 

# Usage: source script_name.sh [subject] [session] [task] [nruns]/E.g. qsub -V script_name.sh 001 1 ret 4 

subject=sub-$1
session=$2
task=$3
nruns=$4
depth=1.0
a=0

PROJ_DIR=${DIR_DATA_HOME}
OUT_DIR=${PROJ_DIR}/derivatives/resampled

if [[ ! -d $OUT_DIR ]]; then
  echo "Creating $OUT_DIR folder"
  mkdir -p $OUT_DIR
else
  echo "$OUT_DIR folder already exists."
fi

for denoising in nordic nordic_sm4
	do SOURCE_DIR=${PROJ_DIR}/derivatives/fmriprep/${subject}/ses-${session}/func     ########## TO RUN BASED ON FMRIPREP
	#do SOURCE_DIR=${PROJ_DIR}/${subject}/ses-${session}/func                        ########## TO RUN WITHOUT FMRIPREP
	if [[ ! -d $OUT_DIR/${subject}/ses-${session}/${denoising} ]]; then
	  echo "Creating $OUT_DIR${subject}/ses-${session}/${denoising} folder"
	  mkdir -p $OUT_DIR/${subject}/ses-${session}/${denoising}
	else
	  echo "$OUT_DIR/${subject}/ses-${session}/${denoising} folder already exists."
	fi
	for hemi in lh rh;
		do for run in $(seq "$nruns");
			do if [[ ${denoising} == "nordic" ]]; then
			filename=${subject}_ses-${session}_task-${task}_run-${run}_desc-preproc_bold     ########## TO RUN BASED ON FMRIPREP
			#filename=${subject}_ses-${session}_task-${task}_run-${run}_bold                ########## TO RUN WITHOUT FMRIPREP
			smoothing=0
			elif [[ ${denoising} == "nordic_sm4" ]]; then
			filename=${subject}_ses-${session}_task-${task}_run-${run}_desc-preproc_bold     ########## TO RUN BASED ON FMRIPREP
			#filename=${subject}_ses-${session}_task-${task}_run-${run}_bold                ########## TO RUN WITHOUT FMRIPREP
			smoothing=4
			fi
			if [ "$hemi" == "lh" ]; then h=L; else h=R; fi;
			mri_vol2surf --src ${SOURCE_DIR}/${filename}.nii.gz --out $OUT_DIR/${subject}/ses-${session}/${denoising}/${subject}_ses-02_task-RET_run-${run}_space-fsnative_hemi-${h}_desc-${denoising}_bold_GM.gii --hemi ${hemi} --out_type gii --projfrac-avg ${a} ${depth} 0.1 --interp "trilinear" --regheader ${subject} --surf-fwhm $smoothing --cortex;
			done;
	done;
done