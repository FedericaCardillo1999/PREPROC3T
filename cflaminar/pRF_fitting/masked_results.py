#!/usr/bin/env python
# coding: utf-8

import sys
import os
import numpy as np
import nibabel as nib
from nibabel.freesurfer.io import read_morph_data, write_morph_data
import cortex

subject = f'sub-{sys.argv[1:][0]}'
subject_id = sys.argv[1:][0]
print(subject)
denoising = sys.argv[2:][0]
print(denoising)
session = sys.argv[3:][0]
print(session)
atlas = sys.argv[4:][0]
print(atlas)

# e.g., python /home2/p315561/programs/cflaminar/pRF_fitting/masked_results.py 02 nordic 02 benson 

# Load the Population Receptive Field Mapping results 
try:
    prf_results = np.load(f'/scratch/hb-EGRET-AAA/projects/EGRET+/derivatives/pRFM/{subject}/ses-{session}/{denoising}/model-{atlas}-nelder-mead-GM_desc-prf_params_random.pkl', allow_pickle=True)
except FileNotFoundError:
    print(f"Error: PRF params file not found for subject {subject} and session {session}. Check your paths.")
    sys.exit(1)

roi_verts = np.where(prf_results['rois_mask'] == 1)
prf_results = prf_results['model'].iterative_search_params

# Extract the parameters 
prf_params_vx = roi_verts[0]
size = prf_results[:, 2]
angle_map = cortex.Vertex.empty(f'{subject}')

masked_polar_angle = np.zeros(angle_map.nverts)
masked_polar_angle[:] = 50
masked_eccentricity = np.zeros(angle_map.nverts)
masked_eccentricity[:] = 50
masked_r2 = np.zeros(angle_map.nverts)
masked_r2[:] = 0.05
masked_radius = np.zeros(angle_map.nverts)
masked_radius[:] = 50

# Extract the actual measurements
eccentricity = np.sqrt(prf_results[:, 0]**2 + prf_results[:, 1]**2)
polar_angle = np.arctan2(prf_results[:, 1], prf_results[:, 0])
r2 = prf_results[:, -1]

# Masking
r2_mask = r2 > 0.05
ecc_mask = eccentricity < 20
total_mask = r2_mask * ecc_mask 

polar_angle[total_mask == False] = 50
eccentricity[total_mask == False] = 50
r2[total_mask == False] = 0
size[total_mask == False] = 50

masked_polar_angle[roi_verts] = polar_angle
masked_eccentricity[roi_verts] = eccentricity
masked_r2[roi_verts] = r2
masked_radius[roi_verts] = size

# Create the necessary files for the visualization 
freesurfer_dir = f'/scratch/hb-EGRET-AAA/projects/EGRET+/derivatives/freesurfer/{subject}/surf'
lh_c = read_morph_data(f'{freesurfer_dir}/lh.curv')
lh_masked_pol = masked_polar_angle[:lh_c.shape[0]]
rh_masked_pol = masked_polar_angle[lh_c.shape[0]:]
lh_masked_ecc = masked_eccentricity[:lh_c.shape[0]]
rh_masked_ecc = masked_eccentricity[lh_c.shape[0]:]
lh_masked_r2 = masked_r2[:lh_c.shape[0]]
rh_masked_r2 = masked_r2[lh_c.shape[0]:]
lh_masked_radius = masked_radius[:lh_c.shape[0]]
rh_masked_radius = masked_radius[lh_c.shape[0]:]

# Conditional file naming based on the atlas type
if atlas == 'manual':
    write_morph_data(f'{freesurfer_dir}/lh.masked_pol_manual', lh_masked_pol)
    write_morph_data(f'{freesurfer_dir}/rh.masked_pol_manual', rh_masked_pol)
    write_morph_data(f'{freesurfer_dir}/lh.masked_ecc_manual', lh_masked_ecc)
    write_morph_data(f'{freesurfer_dir}/rh.masked_ecc_manual', rh_masked_ecc)
    write_morph_data(f'{freesurfer_dir}/lh.masked_r2_manual', lh_masked_r2)
    write_morph_data(f'{freesurfer_dir}/rh.masked_r2_manual', rh_masked_r2)
    write_morph_data(f'{freesurfer_dir}/lh.masked_radius_manual', lh_masked_radius)
    write_morph_data(f'{freesurfer_dir}/rh.masked_radius_manual', rh_masked_radius)
else:
    write_morph_data(f'{freesurfer_dir}/lh.masked_pol_{denoising}', lh_masked_pol)
    write_morph_data(f'{freesurfer_dir}/rh.masked_pol_{denoising}', rh_masked_pol)
    write_morph_data(f'{freesurfer_dir}/lh.masked_ecc_{denoising}', lh_masked_ecc)
    write_morph_data(f'{freesurfer_dir}/rh.masked_ecc_{denoising}', rh_masked_ecc)
    write_morph_data(f'{freesurfer_dir}/lh.masked_r2_{denoising}', lh_masked_r2)
    write_morph_data(f'{freesurfer_dir}/rh.masked_r2_{denoising}', rh_masked_r2)
    write_morph_data(f'{freesurfer_dir}/lh.masked_radius_{denoising}', lh_masked_radius)
    write_morph_data(f'{freesurfer_dir}/rh.masked_radius_{denoising}', rh_masked_radius)
