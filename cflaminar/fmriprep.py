# %%
import cortex
from cortex import fmriprep
import os
import shutil
import sys
import numpy as np

# usage: /home2/p315561/programs/cflaminar/shell/pycortex/fmriprep.py <subject_id>
if len(sys.argv) != 2:
    print("Usage: python import_fmriprepsubj.py <subject_id>")
    sys.exit(1)

subject_id = sys.argv[1]
subject = f"sub-{subject_id}"

# only need this if my files have an extra tag like acq-MPRAGE in the name, leave blank otherwise
suffix = ""
suffix_str = f"_{suffix}" if suffix else ""

if "SUBJECTS_DIR" not in os.environ:
    print("Error: SUBJECTS_DIR environment variable is not set.")
    sys.exit(1)

# derivatives dir is one level up from freesurfer, project name is one level up from that
DERIV_PATH = os.path.dirname(os.environ["SUBJECTS_DIR"])
PROJECT_NAME = os.path.basename(os.path.dirname(DERIV_PATH))
print(f"Using derivatives path: {DERIV_PATH}")
print(f"Project: {PROJECT_NAME}")

source_dir = os.path.join(DERIV_PATH, "fmriprep", subject, "ses-01", "anat")
temp_dir = os.path.join(DERIV_PATH, "fmriprep", subject, "temp-anat")
anat_dir = os.path.join(DERIV_PATH, "fmriprep", subject, "anat")
pycortex_dir = os.path.join(DERIV_PATH, "pycortex", subject)
anatomicals_dir = os.path.join(pycortex_dir, "anatomicals")
surfaces_dir = os.path.join(pycortex_dir, "surfaces")
surfaceinfo_dir = os.path.join(pycortex_dir, "surface-info")

if source_dir == temp_dir:
    raise RuntimeError("source_dir and temp_dir must differ.")
for d in [temp_dir, anat_dir, pycortex_dir, anatomicals_dir, surfaces_dir, surfaceinfo_dir]:
    os.makedirs(d, exist_ok=True)


# quick helpers so I'm not copy pasting the same try/except a million times
def safe_copy(src, dst, label=""):
    if os.path.exists(src):
        shutil.copyfile(src, dst)
        print(f"Copied {label}: {os.path.basename(src)} -> {os.path.basename(dst)}")
    else:
        print(f"Missing {label}: {src}")

def safe_move(src, dst, label=""):
    if os.path.exists(src):
        shutil.move(src, dst)
        print(f"Moved {label}: {os.path.basename(dst)}")
    else:
        print(f"Missing {label}: {src}")


# Step 1: grab the fmriprep files I need and rename them into temp (dropping the suffix)
file_basenames = [
    "desc-preproc_T1w.nii.gz",
    "desc-aseg_dseg.nii.gz",
    "hemi-R_inflated.surf.gii", "hemi-R_midthickness.surf.gii",
    "hemi-R_pial.surf.gii", "hemi-R_smoothwm.surf.gii",
    "hemi-L_inflated.surf.gii", "hemi-L_midthickness.surf.gii",
    "hemi-L_pial.surf.gii", "hemi-L_smoothwm.surf.gii",
]
new_file_list = [f"{subject}_{name}" for name in file_basenames]
for name in file_basenames:
    safe_copy(os.path.join(source_dir, f"{subject}{suffix_str}_{name}"),
              os.path.join(temp_dir, f"{subject}_{name}"), label="fmriprep file")

# Step 2: move the renamed files from temp into anat/
for file_name in new_file_list:
    safe_move(os.path.join(temp_dir, file_name), os.path.join(anat_dir, file_name), label="renamed file")

# Step 3: copy everything into the pycortex/<subject> layout
# raw_wm is just pointing at the aseg file for now, fix this if I ever get a real wm mask
anat_files = {
    "raw.nii.gz": f"{subject}_desc-preproc_T1w.nii.gz",
    "aseg.nii.gz": f"{subject}_desc-aseg_dseg.nii.gz",
    "raw_wm.nii.gz": f"{subject}_desc-aseg_dseg.nii.gz",
}
for dst_name, src_name in anat_files.items():
    safe_copy(os.path.join(anat_dir, src_name), os.path.join(anatomicals_dir, dst_name), label="anatomical")

surf_map = {"fiducial": "midthickness", "inflated": "inflated", "pia": "pial", "wm": "smoothwm"}
for hemi, hemi_short in [("L", "lh"), ("R", "rh")]:
    for std_name, orig_name in surf_map.items():
        src_file = f"{subject}_hemi-{hemi}_{orig_name}.surf.gii"
        dst_file = f"{std_name}_{hemi_short}.gii"
        safe_copy(os.path.join(anat_dir, src_file), os.path.join(surfaces_dir, dst_file), label="surface")

# dummy surface-info files, just placeholders so pycortex doesn't complain about missing files
for name in ["curvature", "thickness", "sulcaldepth"]:
    np.savez_compressed(os.path.join(surfaceinfo_dir, f"{name}.npz"), data=np.random.rand(100))
print("Dummy surface-info files created.")

for folder in ["transforms", "views", "cache"]:
    os.makedirs(os.path.join(pycortex_dir, folder), exist_ok=True)
    print(f"Created folder: {folder}")

# Step 4: register the subject with pycortex, both via fmriprep and directly via freesurfer
fmriprep.import_subj(subject_id, DERIV_PATH)
cortex.freesurfer.import_subj(subject, freesurfer_subject_dir=os.path.join(DERIV_PATH, "freesurfer"))

# pycortex sometimes saves stuff under just the number instead of sub-XX, so copying
# the fiducial surfaces over to the sub-XX folder too just to be safe
pycortex_db = cortex.database.default_filestore
shutil.copyfile(f"{pycortex_db}/{subject_id}/surfaces/fiducial_lh.gii", f"{pycortex_db}/{subject}/surfaces/fiducial_lh.gii")
shutil.copyfile(f"{pycortex_db}/{subject_id}/surfaces/fiducial_rh.gii", f"{pycortex_db}/{subject}/surfaces/fiducial_rh.gii")

print(f"Pycortex subject {subject} setup complete.")