#!/bin/bash
#SBATCH --job-name=UMCG
#SBATCH --time=0X:00:00
#SBATCH --partition=regular
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=25
#SBATCH --profile=task
#SBATCH --mem=20GB
#SBATCH --output=/scratch/hb-EGRET-AAA/UMCG_preprocessing.out

source /home2/p315561/venvs/preproc/bin/activate
source ~/.bash_profile

# Freesurfer directory of the project
export SUBJECTS_DIR=/scratch/hb-EGRET-AAA/projects/UMCG/derivatives/freesurfer
# Run the following command in the terminal to parallelize your subjects
# cd /scratch/hb-EGRET-AAA/projects/UMCG
# for_each sub-* : sbatch --output /scratch/hb-EGRET-AAA/projects/UMCG/preprocessing/UMCG_IN.out /scratch/hb-EGRET-AAA/preprocessing.sh IN
# For parallelization you need to uncomment this section here: 
# input="$1"
# input="${input#sub-}"
# subject_id="sub-$input"

# A. Anatomical preprocessing: 
# 1. From the linescanning repository denoise anatomical images.
master -m 08 -s "$input" -n 01 --ow # Specify the subject and the session with -s and -n. The --ow flag allows overwriting existing files.
# 2. Run Freesurfer to reconstruct the cortical surface.
master -m 14 -s 01 -n 01 --ow # Specify the subject and the session with -s and -n. The --ow flag allows overwriting existing files.
# 3. Apply the Benson atlas to the subject's anatomical data.
# You also have the option to use the Bayesian Benson atlas but you need to have already run the pRF mapping to use that.
# this is the command to run the Bayesian Benson atlas: source /home2/p315561/programs/cflaminar/shell/atlas/bayesian_benson.sh "$input" 
source /home2/p315561/programs/cflaminar/shell/atlas/standard_benson.sh "$input" UMCG # Specify the subject with "$input" and the project name. 
# 4. Reconstruct the cortical surface using pycortex.
python /home2/p315561/programs/cflaminar/shell/pycortex.py "$input" # Specify the subject with "$input".
# 5. Preprocess the fMRI data using fMRIprep.
python /home2/p315561/programs/cflaminar/shell/fmriprep.py "$input" # Specify the subject with "$input".

# B. Functional preprocessing:
# 6. From the linescanning repository denoise the functional data using NORDIC
master -m 10 -s "$input" -n 02 --ow # Specify the subject and the session with -s and -n. The --ow flag allows overwriting existing files.
# 7. Apply motion correction to the functional data using SPM. 
source /home2/p315561/programs/cflaminar/shell/motion_correction/moco.sh "$input" "$task" "$project" # Specify the subject with "$input", the task and the project name.
# 8. Apply coregistration to the functional data using ANTs.
source /home2/p315561/programs/cflaminar/shell/coregistration/coregistration.sh "$input" "$task" "$project" "$nruns" "$session" # Specify the subject with "$input", the task and the project name, the number of runs and the session.
# 9. Apply resampling to the functional data using freesufer. 
source /home2/p315561/programs/cflaminar/shell/resampling/ resampling.sh "$input"  "$task" "$project" # Specify the subject with "$input", the task and the project name.
# 10. Filtering the functional data using a bandpass filter.
python /home2/p315561/programs/cflaminar/shell/filtering.py "$input"  "$task" "$project" 
