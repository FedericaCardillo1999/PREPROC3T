#!/bin/bash
#SBATCH --job-name=pRF_mapping
#SBATCH --time=0X:00:00
#SBATCH --partition=regular
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=25
#SBATCH --profile=task
#SBATCH --mem=20GB
#SBATCH --output=/scratch/hb-EGRET-AAA/pRF_mapping.out

source /home2/p315561/venvs/preproc/bin/activate
source ~/.bash_profile

# Freesurfer directory of the project
export SUBJECTS_DIR=/scratch/hb-EGRET-AAA/projects/UMCG/derivatives/freesurfer
# Run the following command in the terminal to parallelize your subjects
# cd /scratch/hb-EGRET-AAA/projects/UMCG
# for_each sub-* : sbatch --output /scratch/hb-EGRET-AAA/projects/UMCG/preprocessing/pRF_mapping_UMCG_IN.out /scratch/hb-EGRET-AAA/pRF_mapping.sh IN
# For parallelization you need to uncomment this section here: 
# input="$1"
# input="${input#sub-}"
# subject_id="sub-$input"

# 1. Run the pRF mapping on the functional data.
python /Users/federicacardillo/Downloads/cflaminar/pRF_fitting/fit_pRFs.py "$subject_id" GM RET # Specify the subject with "$subject_id", the tissue type and the task.
