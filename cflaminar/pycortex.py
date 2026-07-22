import os
import sys
import shutil
import subprocess
import nibabel as nib
import numpy as np

# usage: home2/p315561/programs/cflaminar/shell/pycortex/pycortex.py <subject_id>
if len(sys.argv) != 2:
    print("Usage: python gii_files.py <subject_id>")
    sys.exit(1)

subject_id = sys.argv[1]  # e.g., "01"
subject = f"sub-{subject_id}"
suffix = "ses-01_acq-MPRAGE"

if "SUBJECTS_DIR" not in os.environ:
    print("SUBJECTS_DIR environment variable is not set. Please export it before running.")
    sys.exit(1)

freesurfer_base = os.environ["SUBJECTS_DIR"]         # .../derivatives/freesurfer
derivatives_dir = os.path.dirname(freesurfer_base)   # .../derivatives
base_dir = os.path.dirname(derivatives_dir)           # .../projects/PROJECT_NAME
project = os.path.basename(base_dir)

print(f"Using SUBJECTS_DIR: {freesurfer_base}")
print(f"Using derivatives_dir: {derivatives_dir}")
print(f"Detected project: {project}")

freesurfer_dir = os.path.join(derivatives_dir, "freesurfer", subject)
anat_dir = os.path.join(derivatives_dir, "fmriprep", subject, "ses-01", "anat")
temp_dir = os.path.join(derivatives_dir, "fmriprep", subject, "anat")
os.makedirs(anat_dir, exist_ok=True)
os.makedirs(temp_dir, exist_ok=True)

# pycortex setup
pycortex_db = os.path.join(derivatives_dir, "pycortex")
os.makedirs(pycortex_db, exist_ok=True)
os.environ["PYCOCORTEX_DB"] = pycortex_db

import cortex
cortex.database.default_filestore = pycortex_db

pycortex_dir = os.path.join(pycortex_db, subject)
anatomicals_dir = os.path.join(pycortex_dir, "anatomicals")
surfaces_dir = os.path.join(pycortex_dir, "surfaces")
surfaceinfo_dir = os.path.join(pycortex_dir, "surface-info")
for d in [pycortex_dir, anatomicals_dir, surfaces_dir, surfaceinfo_dir]:
    os.makedirs(d, exist_ok=True)


# small helpers
def convert_mgz_to_nii(mgz_path, out_path):
    subprocess.run(["mri_convert", mgz_path, out_path], check=True)

def convert_surf_to_gii(surf_path, out_path):
    subprocess.run(["mris_convert", surf_path, out_path], check=True)

def safe_copy(src, dst, label=""):
    if os.path.exists(src):
        shutil.copyfile(src, dst)
        print(f"Copied {label}: {os.path.basename(src)} -> {os.path.basename(dst)}")
    else:
        print(f"Missing {label}: {src}")

def generate_midthickness_in_python(hemi):
    # freesurfer doesn't give us midthickness directly, so average white + pial
    print(f"Generating midthickness for {hemi}...")
    hemi_letter = 'L' if hemi == 'lh' else 'R'
    white_path = os.path.join(temp_dir, f"{subject}_{suffix}_hemi-{hemi_letter}_smoothwm.surf.gii")
    pial_path = os.path.join(temp_dir, f"{subject}_{suffix}_hemi-{hemi_letter}_pial.surf.gii")
    midthick_path = os.path.join(temp_dir, f"{subject}_{suffix}_hemi-{hemi_letter}_midthickness.surf.gii")

    white = nib.load(white_path)
    pial = nib.load(pial_path)
    mid_coords = (white.darrays[0].data + pial.darrays[0].data) / 2.0
    faces = white.darrays[1].data

    midthick_gii = nib.gifti.GiftiImage(darrays=[
        nib.gifti.GiftiDataArray(mid_coords, intent='NIFTI_INTENT_POINTSET'),
        nib.gifti.GiftiDataArray(faces.astype(np.int32), intent='NIFTI_INTENT_TRIANGLE')
    ])
    nib.save(midthick_gii, midthick_path)
    print(f"Saved: {midthick_path}")
    return midthick_path


# Step 1: convert T1 and aseg from mgz to nii
t1_out = os.path.join(temp_dir, f"{subject}_{suffix}_desc-preproc_T1w.nii.gz")
aseg_out = os.path.join(temp_dir, f"{subject}_{suffix}_desc-aseg_dseg.nii.gz")
convert_mgz_to_nii(os.path.join(freesurfer_dir, "mri", "T1.mgz"), t1_out)
convert_mgz_to_nii(os.path.join(freesurfer_dir, "mri", "aseg.mgz"), aseg_out)

# Step 2: convert surfaces to gii, midthickness gets generated instead of converted
surf_types = {'inflated': 'inflated', 'pial': 'pial', 'smoothwm': 'white', 'midthickness': 'mid'}
for hemi in ['lh', 'rh']:
    hemi_letter = 'L' if hemi == 'lh' else 'R'
    for surf_name, fs_file in surf_types.items():
        if surf_name == 'midthickness':
            fs_path = generate_midthickness_in_python(hemi)
        else:
            fs_path = os.path.join(freesurfer_dir, "surf", f"{hemi}.{fs_file}")
        out_path = os.path.join(temp_dir, f"{subject}_{suffix}_hemi-{hemi_letter}_{surf_name}.surf.gii")
        convert_surf_to_gii(fs_path, out_path)

# Step 3: drop the suffix from the filenames and move into anat_dir
file_list = [f'{subject}_{suffix}_desc-preproc_T1w.nii.gz', f'{subject}_{suffix}_desc-aseg_dseg.nii.gz'] + [
    f'{subject}_{suffix}_hemi-{hemi}_{surf}.surf.gii'
    for hemi in ['R', 'L']
    for surf in ['inflated', 'midthickness', 'pial', 'smoothwm']
]
for old in file_list:
    new = old.replace(f"_{suffix}", "")
    old_path = os.path.join(temp_dir, old)
    new_path = os.path.join(temp_dir, new)
    try:
        os.rename(old_path, new_path)
        print(f"Renamed {old} -> {new}")
        shutil.copyfile(new_path, os.path.join(anat_dir, new))
    except FileNotFoundError:
        print(f"Missing: {old_path}")
    except FileExistsError:
        print(f"Already exists: {new_path}")

# Step 4: copy anatomicals into pycortex, renamed to what pycortex expects
# raw_wm is just pointing at the aseg file for now since I don't have a separate wm mask
anat_files = {
    "raw.nii.gz": f"{subject}_desc-preproc_T1w.nii.gz",
    "aseg.nii.gz": f"{subject}_desc-aseg_dseg.nii.gz",
    "raw_wm.nii.gz": f"{subject}_desc-aseg_dseg.nii.gz",
}
for dst_name, src_name in anat_files.items():
    safe_copy(os.path.join(anat_dir, src_name), os.path.join(anatomicals_dir, dst_name), label="anatomical")

# Step 5: copy surfaces into pycortex, renamed to the fiducial/inflated/pia/wm convention
surf_map = {"fiducial": "midthickness", "inflated": "inflated", "pia": "pial", "wm": "smoothwm"}
for hemi, hemi_short in [("L", "lh"), ("R", "rh")]:
    for std_name, orig_name in surf_map.items():
        src_file = f"{subject}_hemi-{hemi}_{orig_name}.surf.gii"
        dst_file = f"{std_name}_{hemi_short}.gii"
        safe_copy(os.path.join(anat_dir, src_file), os.path.join(surfaces_dir, dst_file), label="surface")

# Step 6: dummy surface-info files, replace with real data later if I get it
for name in ["curvature", "thickness", "sulcaldepth"]:
    np.savez_compressed(os.path.join(surfaceinfo_dir, f"{name}.npz"), data=np.random.rand(100))
print("Dummy surface-info files written.")

print(f"Pycortex subject '{subject}' set up.")