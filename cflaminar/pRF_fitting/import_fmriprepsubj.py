# %%
import cortex
from cortex import fmriprep
import os
from os import path as op
import shutil
import sys

# Location of the downloaded openfmri dataset
DERIV_PATH = os.getenv('DERIVATIVES')
# fmriprep subject name (without "sub-")
subject_id = sys.argv[1:][0]
subject=f'sub-{subject_id}'

# %%
# export FREESURFER_HOME=/Applications/freesurfer/7.2.0
# export SUBJECTS_DIR=/Users/mayra/Library/CloudStorage/OneDrive-UMCG/Postdoc/CFLamUp/derivatives/freesurfer
# export FS_LICENSE=/Applications/freesurfer/7.2.0/license.txt
# source $FREESURFER_HOME/SetUpFreeSurfer.sh

# %%
def copy_files(file_list, source_dir, destination_dir):
    for file_name in file_list:
        source_file = os.path.join(source_dir, file_name)
        destination_file = os.path.join(destination_dir, file_name)
        shutil.copyfile(source_file, destination_file)
        print(f"Copied {file_name} to {destination_dir}")


suffix=f'ses-01_acq-MPRAGE'
#suffix=f'acq-MPRAGE'
file_list = [f'{subject}_{suffix}_desc-preproc_T1w.nii.gz', f'{subject}_{suffix}_desc-aseg_dseg.nii.gz', 
             f'{subject}_{suffix}_hemi-R_inflated.surf.gii',f'{subject}_{suffix}_hemi-R_midthickness.surf.gii',
            f'{subject}_{suffix}_hemi-R_pial.surf.gii',f'{subject}_{suffix}_hemi-R_smoothwm.surf.gii',
            f'{subject}_{suffix}_hemi-L_inflated.surf.gii',f'{subject}_{suffix}_hemi-L_midthickness.surf.gii',
            f'{subject}_{suffix}_hemi-L_pial.surf.gii',f'{subject}_{suffix}_hemi-L_smoothwm.surf.gii']
new_file_list = [f'{subject}_desc-preproc_T1w.nii.gz', f'{subject}_desc-aseg_dseg.nii.gz', 
             f'{subject}_hemi-R_inflated.surf.gii',f'{subject}_hemi-R_midthickness.surf.gii',
            f'{subject}_hemi-R_pial.surf.gii',f'{subject}_hemi-R_smoothwm.surf.gii',
            f'{subject}_hemi-L_inflated.surf.gii',f'{subject}_hemi-L_midthickness.surf.gii',
            f'{subject}_hemi-L_pial.surf.gii',f'{subject}_hemi-L_smoothwm.surf.gii']
source_dir = f'{DERIV_PATH}/fmriprep/{subject}/ses-01/anat' 
temp_dir=f'{DERIV_PATH}/fmriprep/{subject}/anat'
os.makedirs(temp_dir, exist_ok=True)

copy_files(file_list, source_dir, temp_dir)
  
for i in range(len(file_list)):
    try:
        os.rename(os.path.join(temp_dir,file_list[i]), os.path.join(temp_dir,new_file_list[i]))
        print(f"Renamed {file_list[i]} to {new_file_list[i]}")
    except FileNotFoundError:
        print(f"Error: File {file_list[i]} not found.")
    except FileExistsError:
        print(f"Error: File {new_file_list[i]} already exists.")

# %%l
# import subject into pycortex database
fmriprep.import_subj(subject_id, f'{DERIV_PATH}')

# %%
# We can visualize the imported subject's T1-weighted image
# anat_nifti = f'{subject}_{suffix}_desc-preproc_T1w.nii.gz'
# t1_image_path = op.join(source_dir, anat_nifti)

# Now we can make a volume using the built-in identity transform
# t1w_volume = cortex.Volume(t1_image_path, subject_id, 'identity')

# And show the result.
# ds = cortex.Dataset(t1w=t1w_volume)
# cortex.webgl.show(ds)

# %%
cortex.freesurfer.import_subj(f'sub-{subject_id}',freesurfer_subject_dir=f'/scratch/hb-EGRET-AAA/projects/EGRET+/derivatives/freesurfer')

# %%
import cortex.database
pycortex_db=cortex.database.default_filestore
import shutil
shutil.copyfile(f'{pycortex_db}/{subject_id}/surfaces/fiducial_lh.gii', f'{pycortex_db}/sub-{subject_id}/surfaces/fiducial_lh.gii')
shutil.copyfile(f'{pycortex_db}/{subject_id}/surfaces/fiducial_rh.gii', f'{pycortex_db}/sub-{subject_id}/surfaces/fiducial_rh.gii')

# %%
#shutil.rmtree(f'/home/bittencourt/.conda/envs/mypy311/share/pycortex/db/{subject_id}',ignore_errors=True)
# shutil.rmtree(temp_dir)

# %%

