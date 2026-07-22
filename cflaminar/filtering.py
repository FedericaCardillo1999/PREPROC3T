#!/usr/bin/env python
"""
Filters resampled pRF/RestingState time series (percent signal change + a
task-appropriate temporal filter) for a single subject/task/site.

Combine-mode is fixed by task and site, not a runtime CLI choice - this matches
how each was actually being analyzed across the old scripts:
  - UMCG, RET/RET2      -> average (median) across runs, saved to avg/
  - UMCG, RestingState  -> runs kept separate only, saved to run-1/, run-2/
  - OVGU, RET/RET2      -> average (median) across runs, saved to avg/
  - OVGU, RestingState  -> BOTH kept separate (run-1/, run-2/, ...) AND
                            concatenated across runs, saved to concat/

Depth is GM only. filtering_7T.py separately supports multi-depth
(equivolumetric layer) processing plus nuisance regression / motion scrubbing
for the 7T project specifically - that's a different pipeline stage serving
layer-resolved analysis and was deliberately NOT folded in here.

No missing-file handling - if an expected resampled .gii or source .nii is
missing, this crashes with the underlying error rather than skipping quietly.
"""
import os
import sys
import argparse
from glob import glob

import numpy as np
import nibabel as nib
from scipy import signal

parser = argparse.ArgumentParser(description="Filter pRF/RestingState data for a subject, task, and site.")
parser.add_argument("subject_id", help="Subject ID (e.g., 01)")
parser.add_argument("task", help="Task name (e.g., RET, RET2, RestingState)")
parser.add_argument("site", choices=["UMCG", "OVGU"], help="Site: UMCG or OVGU")
args = parser.parse_args()

subject = f"sub-{args.subject_id}"
task = args.task
site = args.site
depth = "GM"
denoisings = ["nordic", "nordic_sm4"]

# project path comes from the site argument, overwriting whatever might
# already be exported, so this always points at the right project
PROJ_DIR = f"/scratch/hb-EGRET-AAA/projects/{site}"
os.environ["SUBJECTS_DIR"] = f"{PROJ_DIR}/derivatives/freesurfer"
MAIN_PATH = f"{PROJ_DIR}/derivatives"

# UMCG resampled output lives under a trimmed_runs subfolder with a
# _trimmed_runs filename tag; OVGU doesn't have either - confirmed against
# resampling_GM_merged.sh, which only adds these for UMCG
if site == "UMCG":
    resampled_subdir = "trimmed_runs"
    resampled_tag = "_trimmed_runs"
    sessions = ["ses-01", "ses-02"]
    src_suffix = "_new"  # trimmed source nifti, used only to read TR from
else:
    resampled_subdir = ""
    resampled_tag = ""
    sessions = ["ses-01", "ses-02", "ses-03"]
    src_suffix = ""

print(f"Site: {site} | Subject: {subject} | Task: {task}")


def get_tr_from_nifti(session, run=1):
    """Read TR straight from the source functional NIfTI header, instead of
    relying on someone remembering to pass the right --tr value.

    Checks the header's time unit explicitly rather than assuming seconds -
    UMCG's trimmed (_new) source files were found to report an 'unknown'
    time unit, so the raw zoom value alone isn't fully trustworthy there."""
    nii_path = os.path.join(
        PROJ_DIR, subject, session, "func",
        f"{subject}_{session}_task-{task}_run-{run}_bold{src_suffix}.nii.gz"
    )
    img = nib.load(nii_path)
    tr_raw = float(img.header.get_zooms()[3])
    _, t_unit = img.header.get_xyzt_units()

    if t_unit == "sec":
        tr = tr_raw
    elif t_unit == "msec":
        tr = tr_raw / 1000.0
    else:
        tr = tr_raw
        print(f"WARNING: {nii_path} has an '{t_unit}' time unit in its header "
              f"(not explicitly sec or msec). Using the raw value ({tr_raw}) as "
              f"seconds, but this hasn't been independently confirmed - double "
              f"check against known acquisition parameters before trusting results.")

    return tr


def normalize(tc):
    """Convert time course to percent signal change."""
    mean = np.nanmean(tc, axis=0)
    mean[mean == 0] = np.nan
    scale = 100 / mean
    scale = np.nan_to_num(scale, nan=0.0, posinf=0.0, neginf=0.0)
    return np.nan_to_num(tc * scale[np.newaxis, :], nan=0.0, posinf=0.0, neginf=0.0)


def highpass(tc, tr, task):
    """RestingState: bandpass 0.01-0.1 Hz. Everything else: highpass at 0.006 Hz."""
    fs = 1 / tr
    nyquist = 0.5 * fs
    mean = np.mean(tc, axis=0)
    tc = signal.detrend(tc, axis=0) + mean

    if task == "RestingState":
        lowcut, highcut = 0.01, 0.1
        sos = signal.butter(4, [lowcut / nyquist, highcut / nyquist], btype="bandpass", output="sos")
    else:
        lowcut = 0.006
        sos = signal.butter(8, lowcut / nyquist, btype="highpass", output="sos")

    return signal.sosfiltfilt(sos, tc, axis=0)


# find which session has this task, using the L-hemi nordic files to count runs
session = None
for sess in sessions:
    pattern = os.path.join(
        MAIN_PATH, "resampled", subject, resampled_subdir, sess, "nordic",
        f"{subject}_{sess}_task-{task}_run-*_space-fsnative_hemi-L_desc-nordic{resampled_tag}_bold_{depth}.gii"
    )
    if glob(pattern):
        session = sess
        break

if session is None:
    print(f"Task '{task}' not found for {subject} in any of {sessions}")
    sys.exit(1)

run_files = sorted(glob(os.path.join(
    MAIN_PATH, "resampled", subject, resampled_subdir, session, "nordic",
    f"{subject}_{session}_task-{task}_run-*_space-fsnative_hemi-L_desc-nordic{resampled_tag}_bold_{depth}.gii"
)))
nruns = len(run_files)
print(f"Found {nruns} run(s) for {subject}, task {task}, session {session}")

TR = get_tr_from_nifti(session)
print(f"TR read from source NIfTI: {TR}s")

for denoising in denoisings:
    proc_tc_LH = []
    proc_tc_RH = []

    for run in range(1, nruns + 1):
        path_L = os.path.join(
            MAIN_PATH, "resampled", subject, resampled_subdir, session, denoising,
            f"{subject}_{session}_task-{task}_run-{run}_space-fsnative_hemi-L_desc-{denoising}{resampled_tag}_bold_{depth}.gii"
        )
        path_R = os.path.join(
            MAIN_PATH, "resampled", subject, resampled_subdir, session, denoising,
            f"{subject}_{session}_task-{task}_run-{run}_space-fsnative_hemi-R_desc-{denoising}{resampled_tag}_bold_{depth}.gii"
        )

        tc_L = nib.load(path_L).agg_data().T
        tc_R = nib.load(path_R).agg_data().T

        if task != "RestingState":
            tc_L = tc_L[:136, :] if tc_L.shape[0] > 136 else tc_L
            tc_R = tc_R[:136, :] if tc_R.shape[0] > 136 else tc_R

        tc_L = normalize(tc_L)
        tc_R = normalize(tc_R)

        tc_L -= np.median(tc_L[:5], axis=0)
        tc_R -= np.median(tc_R[:5], axis=0)

        tc_L = highpass(tc_L, TR, task)
        tc_R = highpass(tc_R, TR, task)

        proc_tc_LH.append(tc_L)
        proc_tc_RH.append(tc_R)

    out_base = os.path.join(MAIN_PATH, "pRFM", subject, session, denoising)

    # combine mode is fixed by task+site, not a runtime choice - see docstring
    if task == "RestingState":
        # always keep runs separate...
        for run in range(1, nruns + 1):
            out_dir = os.path.join(out_base, f"run-{run}")
            os.makedirs(out_dir, exist_ok=True)
            np.save(os.path.join(out_dir, f"{subject}_{session}_task-{task}_run-{run}_hemi-lh_bold_{depth}.npy"), proc_tc_LH[run - 1])
            np.save(os.path.join(out_dir, f"{subject}_{session}_task-{task}_run-{run}_hemi-rh_bold_{depth}.npy"), proc_tc_RH[run - 1])
        print(f"  Saved {nruns} separate run(s): {denoising}")

        # ...and for OVGU only, also save a concatenated version
        if site == "OVGU":
            out_dir = os.path.join(out_base, "concat")
            os.makedirs(out_dir, exist_ok=True)
            cat_L = np.vstack(proc_tc_LH)
            cat_R = np.vstack(proc_tc_RH)
            np.save(os.path.join(out_dir, f"{subject}_{session}_task-{task}_hemi-lh_desc-conc_bold_{depth}.npy"), cat_L)
            np.save(os.path.join(out_dir, f"{subject}_{session}_task-{task}_hemi-rh_desc-conc_bold_{depth}.npy"), cat_R)
            np.save(os.path.join(out_dir, f"{subject}_{session}_task-{task}_hemi-LR_desc-conc_bold_{depth}.npy"), np.hstack([cat_L, cat_R]))
            print(f"  Saved concatenated runs: {denoising}")

    else:
        # RET/RET2 (and anything else that isn't RestingState): median across runs
        out_dir = os.path.join(out_base, "avg")
        os.makedirs(out_dir, exist_ok=True)
        avg_L = np.median(np.array(proc_tc_LH), axis=0)
        avg_R = np.median(np.array(proc_tc_RH), axis=0)
        np.save(os.path.join(out_dir, f"{subject}_{session}_task-{task}_hemi-lh_desc-avg_bold_{depth}.npy"), avg_L)
        np.save(os.path.join(out_dir, f"{subject}_{session}_task-{task}_hemi-rh_desc-avg_bold_{depth}.npy"), avg_R)
        np.save(os.path.join(out_dir, f"{subject}_{session}_task-{task}_hemi-LR_desc-avg_bold_{depth}.npy"), np.hstack([avg_L, avg_R]))
        print(f"  Saved averaged runs: {denoising}")

print("Done.")