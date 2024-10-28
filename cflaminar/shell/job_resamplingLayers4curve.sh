#! /bin/sh
#$ -N resample_layers
#$ -S /bin/sh
#$ -j y
#$ -q mayra.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt

# Usage: source script.sh xxx / qsub -V script.sh 001

subject=sub-$1
session=1
smoothing=0

PROJ_DIR=${DIR_DATA_HOME}
OUT_DIR=${PROJ_DIR}/derivatives/resampled4curve

if [[ ! -d $OUT_DIR ]]; then
  echo "Creating $OUT_DIR folder"
  mkdir -p $OUT_DIR
else
  echo "$OUT_DIR folder already exists."
fi

for denoising in nordic nordic_sm4
  do SOURCE_DIR=${PROJ_DIR}/derivatives/upsampling/${subject}/ses-${session}/func/${denoising}
  if [[ ! -d $OUT_DIR/${subject}/ses-${session}/${denoising} ]]; then
  	 echo "Creating $OUT_DIR${subject}/ses-${session}/${denoising} folder"
  	 mkdir -p $OUT_DIR/${subject}/ses-${session}/${denoising}
  else
  	 echo "$OUT_DIR/${subject}/ses-${session}/${denoising} folder already exists."
  fi
  for hemi in lh rh;
    do for depth in 0.0 0.88; #0.12 0.25 0.38 0.5 0.62 0.75 
    	do for run in 1 2 3 4 5 6;
    		do if [[ ${denoising} == "no_denoising" ]]; then
    		    filename=${subject}_ses-${session}_task-ret_run-${run}_desc-preproc_bold
            smoothing=0
    		elif [[ ${denoising} == "nordic" ]]; then
    		    filename=${subject}_ses-${session}_task-ret_run-${run}_desc-preproc_bold
            smoothing=0
        elif [[ ${denoising} == "nordic_sm4" ]]; then
  			    filename=${subject}_ses-${session}_task-ret_run-${run}_desc-preproc_bold
            SOURCE_DIR=${PROJ_DIR}/derivatives/upsampling/${subject}/ses-${session}/func/nordic
            smoothing=4
  			fi
        if [ "$hemi" == "lh" ]; then h=L; else h=R; fi;
            a=$(echo "${depth:-0.00}" | bc)
            echo ${a}
            inc=0.125
            b=$(echo "$a + $inc" | bc)
            echo ${b}
            echo "Surface-smoothing: ${smoothing} FWHM"
    		mri_vol2surf --src ${SOURCE_DIR}/${filename}.nii.gz --out $OUT_DIR/${subject}/ses-${session}/${denoising}/${subject}_ses-1_task-ret_run-${run}_space-fsnative_hemi-${h}_desc-${denoising}_bold_${depth}.gii --surf equi${depth}.pial --hemi ${hemi} --out_type gii --projfrac-avg ${a} ${b} 0.05 --interp "trilinear" --regheader ${subject} --surf-fwhm ${smoothing};
        done;
      done;
  	 done;
   done
