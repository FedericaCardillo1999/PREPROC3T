#!/usr/bin/env python
# %%
import numpy as np
import matplotlib.pyplot as plt
import nibabel as nib
import os
import sys
# %%
#args: subject, session, task, nruns, denoising

subject=f'sub-{sys.argv[1:][0]}'
session=sys.argv[2:][0]
task=sys.argv[3:][0]
nruns=int(sys.argv[4:][0])
MAIN_PATH=os.getenv("DERIVATIVES")
project=os.getenv("PROJECT")
resampling='resampled'
denoising=sys.argv[5:][0]
filter=1
depth_list=['GM']

# Get pybest outputs as .npy files and calculate psc:
for depth in range(depth_list.__len__()):
    proc_tc_L = []
    proc_tc_R = []
    proc_tc = []
    for run in range(nruns):
        proc_tc_L = nib.load(
            f'{MAIN_PATH}/{resampling}/{subject}/ses-{session}/{denoising}/{subject}_ses-{session}_task-{task}_run-{run + 1}_space-fsnative_hemi-L_desc-{denoising}_bold_{depth_list[depth]}.gii')
        proc_tc_R = nib.load(
            f'{MAIN_PATH}/{resampling}/{subject}/ses-{session}/{denoising}/{subject}_ses-{session}_task-{task}_run-{run + 1}_space-fsnative_hemi-R_desc-{denoising}_bold_{depth_list[depth]}.gii')
        tc = np.vstack([proc_tc_L.agg_data(), proc_tc_R.agg_data()]).T
        if tc.shape[0]>136:
            tc=tc[:,:] 
        tc=tc[:,:]
        tc_m = tc * np.expand_dims(np.nan_to_num((100 / np.mean(tc, axis=0))), axis=0)
        
        # Baseline correction
        baseline = np.median(tc_m[:8], axis=0)
        tc_m = tc_m - baseline

        if filter==1:
            from scipy import signal
            mean=np.mean(tc_m, axis=0) # Remove linear trend without demeaning
            tc_m=signal.detrend(tc_m, axis=0)+mean
            # Highpass-filtering
            TR = 1.5                                                            ## TR is the time between successive MRI scans, measured in seconds.                              
            fs = 1 / TR  # Hz                                                   ## FS is the sampling frequency, which is the number of samples per second. It's the inverse of the TR.
            lowcut=0.001 # cut-off freq of the filter                            ## Lowcut and highcut define the frequency range for the high-pass filter. Only the lowcut frequency is used.
            highcut=0.015 # cut-off freq of the filter
            nyquist=0.5*fs                                                      ## Nyquist frequency is half the sampling frequency.
            f_low = lowcut/nyquist;                                             ## The cut-off frequencies are normalized. 
            f_high = highcut/nyquist;
            sos = signal.butter(8, [f_low],'highpass', fs=fs,output='sos')
            tc_m = signal.sosfiltfilt(sos, tc_m, axis=0)

        proc_tc.append(tc_m)
    mean_proc_tc = np.median(np.array(proc_tc), axis=0)
    psc = (mean_proc_tc)

    if resampling == 'resampled4curve':
        output_folder='pRFM4curve'
    else:
        output_folder='pRFM'
    path=f'{MAIN_PATH}/{output_folder}/{subject}/ses-{session}/{denoising}/'
    os.makedirs(path, exist_ok=True)
    np.save(f'{MAIN_PATH}/{output_folder}/{subject}/ses-{session}/{denoising}/{subject}_ses-{session}_task-{task}_hemi-LR_desc-avg_bold_{depth_list[depth]}.npy',psc)

# %%
f'{MAIN_PATH}/{resampling}/{subject}/ses-{session}/{denoising}/{subject}_ses-{session}_task-{task}_run-{run + 1}_space-fsnative_hemi-L_desc-{denoising}_bold_{depth_list[depth]}.gii'

# %%
