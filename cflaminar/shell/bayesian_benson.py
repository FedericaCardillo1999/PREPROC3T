#!/usr/bin/env python
# coding: utf-8

import sys
import os
import nibabel as nib
import numpy as np
from nibabel.freesurfer.io import read_morph_data

# Fetch the subject ID from command line arguments
subject = f'sub-{sys.argv[1:][0]}'
print(subject)
denoising = sys.argv[2:][0]
print(denoising)

# Set the freesurfer directory
freesurfer_dir = f'/scratch/hb-EGRET-AAA/projects/EGRET+/derivatives/freesurfer/{subject}/surf'

# File name mappings
files = [f'lh.masked_pol_{denoising}', f'rh.masked_pol_{denoising}', f'lh.masked_ecc_{denoising}', f'rh.masked_ecc_{denoising}', 
         f'lh.masked_r2_{denoising}', f'rh.masked_r2_{denoising}', f'lh.masked_radius_{denoising}', f'rh.masked_radius_{denoising}']
new_names = ['lh.all-angle', 'rh.all-angle', 'lh.all-eccen', 'rh.all-eccen',
             'lh.all-vexpl', 'rh.all-vexpl', 'lh.all-sigma', 'rh.all-sigma']

# Process each file, read the data, and save it under the new name
for old_file, new_file in zip(files, new_names):
    file_path = os.path.join(freesurfer_dir, old_file)
    if os.path.exists(file_path):
        # Read the data
        data = read_morph_data(file_path)
        
        # Create the new .mgz file
        mgz_file = os.path.join(freesurfer_dir, new_file + '.mgz')
        nib.save(nib.MGHImage(data.astype(np.float32), affine=np.eye(4)), mgz_file)
    else:
        print(f"File {file_path} does not exist.")

# Navigate into the freesurfer surfaces' directory
os.chdir(f'{freesurfer_dir}')

# Run the neuropythy command for the Bayesian Benson Atlas
neuropythy_command = f"""
python -m neuropythy register_retinotopy {subject} --verbose \
       --surf-outdir=. \
       --surf-format="mgz" \
       --no-volume-export \
       --lh-angle=lh.all-angle.mgz \
       --lh-eccen=lh.all-eccen.mgz \
       --lh-weight=lh.all-vexpl.mgz \
       --lh-radius=lh.all-sigma.mgz \
       --rh-angle=rh.all-angle.mgz \
       --rh-eccen=rh.all-eccen.mgz \
       --rh-weight=rh.all-vexpl.mgz \
       --rh-radius=rh.all-sigma.mgz
"""

try:
    os.system(neuropythy_command)
    print("Neuropythy command completed successfully.")
except Exception as e:
    print(f"Error running neuropythy command: {e}")

# Create the labels directory if it doesn't exist
labels_dir = os.path.join(freesurfer_dir, 'labels')
os.makedirs(labels_dir, exist_ok=True)

# Define the files to convert to labels
inferred_files = [
    'lh.inferred_eccen.mgz', 'rh.inferred_eccen.mgz',
    'lh.inferred_angle.mgz', 'rh.inferred_angle.mgz',
    'lh.inferred_varea.mgz', 'rh.inferred_varea.mgz',
    'lh.inferred_sigma.mgz', 'rh.inferred_sigma.mgz'
]

# Convert the inferred files to labels
for inferred_file in inferred_files:
    hemi, measure = inferred_file.split('.')[0], inferred_file.split('.')[1]
    label_file = os.path.join(labels_dir, f'{hemi}.{measure}.label')
    mri_cor2label_command = f"mri_cor2label --i {inferred_file} --id 1 --l {label_file}"
    
    try:
        os.system(mri_cor2label_command)
    except Exception as e:
        print(f"Error converting {inferred_file} to label: {e}")

# Check if all output files are created
output_files = [
    'lh.all-angle.mgz', 'rh.all-angle.mgz',
    'lh.all-eccen.mgz', 'rh.all-eccen.mgz',
    'lh.all-vexpl.mgz', 'rh.all-vexpl.mgz',
    'lh.all-sigma.mgz', 'rh.all-sigma.mgz'
]

all_files_exist = True
for file in output_files:
    if not os.path.exists(os.path.join(freesurfer_dir, file)):
        print(f"Error: Expected output file {file} was not created.")
        all_files_exist = False

if all_files_exist:
    print(f"Bayesian Benson Atlas run successfully for subject number {sys.argv[1:][0]}")
else:
    print(f"Some files were not created correctly for subject number {sys.argv[1:][0]}")
