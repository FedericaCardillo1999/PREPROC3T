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

# 1. Run the pRF mapping on the functional data using the Benson atlas labels.
python /home2/p315561/programs/cflaminar/pRF_fitting/fit_pRFs.py "$subject_id" GM RET

# 2. Merge the manual delineation labels across visual areas into a single label file.
python /home2/p315561/programs/cflaminar/shell/merge_labels.py "$subject_id" UMCG

# 3. Run the pRF mapping again using the Benson atlas (atlas = benson, line 48 of fit_pRFs.py).
python /home2/p315561/programs/cflaminar/pRF_fitting/fit_pRFs.py "$subject_id" GM RET

# 4. Manual delineation of visual areas using Freeview.
# This step runs locally (not on the cluster) — open Freeview with the pRF maps as overlays
# and manually draw the visual area labels on the inflated surface.
# The pRF maps are saved in: derivatives/pRFM/{subject}/{session}/{denoising}/pRF_maps/benson/
# Example command for sub-01 (run this in your local terminal, not on the cluster):
#
# MAP_DIR=/scratch/hb-EGRET-AAA/projects/UMCG/derivatives/pRFM/sub-01/ses-02/nordic/pRF_maps/benson
#
# Color scales for each overlay are stored in /home2/p315561/programs/cflaminar/pRF_fitting/colorscales/
# Load them in Freeview via: overlay_color=<colorscale_file> for each overlay.
#
# COLORSCALES_DIR=/home2/p315561/programs/cflaminar/pRF_fitting/colorscales

# freeview \
#   -f ${MAP_DIR}/lh.inflated:overlay=${MAP_DIR}/lh.pol:overlay_color=${COLORSCALES_DIR}/lh.pol.json:overlay=${MAP_DIR}/lh.ecc:overlay_color=${COLORSCALES_DIR}/lh.ecc.json:overlay=${MAP_DIR}/lh.r2:overlay_color=${COLORSCALES_DIR}/lh.r2.json \
#   -f ${MAP_DIR}/rh.inflated:overlay=${MAP_DIR}/rh.pol:overlay_color=${COLORSCALES_DIR}/rh.pol.json:overlay=${MAP_DIR}/rh.ecc:overlay_color=${COLORSCALES_DIR}/rh.ecc.json:overlay=${MAP_DIR}/rh.r2:overlay_color=${COLORSCALES_DIR}/rh.r2.json
