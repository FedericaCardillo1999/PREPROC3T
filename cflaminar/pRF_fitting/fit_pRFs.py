#!/usr/bin/env python
# coding: utf-8

# LOAD LIBRARIRES 
import numpy as np
import matplotlib.pyplot as plt
from prfpy.stimulus import PRFStimulus2D
from prfpy.model import Iso2DGaussianModel
from prfpy.fit import Iso2DGaussianFitter, Fitter, Extend_Iso2DGaussianFitter
from prfpy.rf import gauss2D_iso_cart
import os
import yaml
import scipy.io
import sys
import shutil
from marcus_prf_eg.utils import *
from marcus_prf_eg.plot_functions import *
import cortex
import cortex.polyutils
import pickle
from os.path import join as opj
from nibabel.freesurfer.io import read_morph_data, write_morph_data

# LOAD VARIABLES AND DIRECTORIES 
subject = f"sub-{sys.argv[1]}"  # first arg = subject number, e.g. "05" -> sub-05
space = "fsnative"
depth = sys.argv[2]  # second arg = depth (e.g. GM)
ncores = 65  # number of cores for the fitter, adjust based on what I actually requested on the cluster
task = sys.argv[3]  # third arg = task name, e.g. RET

if "SUBJECTS_DIR" not in os.environ:
    print("Please export SUBJECTS_DIR before running.")
    sys.exit(1)

freesurfer_base = os.environ["SUBJECTS_DIR"]                     
derivatives_dir = os.path.dirname(freesurfer_base)             
project = os.path.basename(os.path.dirname(derivatives_dir))    
MAIN_PATH = os.path.join("/scratch/hb-EGRET-AAA/projects", project, "derivatives")
fs_dirPATH=f'{MAIN_PATH}/freesurfer'
# DESIGN MATRIX AND GENERAL SETTINGS 
dm =scipy.io.loadmat(f'{MAIN_PATH}/pRFM/sub-01/ses-01/design_task-ret.mat')['stimulus'] #same design matrix for all subjects
prf_settings_file = f'{MAIN_PATH}/pRFM/sub-01/ses-01/fit_settings_prf_pilot1.yml' #same prf settings for all subjects
with open(prf_settings_file) as f:
    prf_settings = yaml.safe_load(f)
prf_stim = PRFStimulus2D(screen_size_cm=prf_settings['screen_size_cm'], screen_distance_cm=prf_settings['screen_distance_cm'], design_matrix=dm, TR=prf_settings['TR'])

# LOOP OVER ATLASES
for atlas in ['benson']:  # only running manual delineation for now, benson is commented out below
#for atlas in ['benson']:
        # point pycortex to a valid directory (must exist and contain subject folders or be initialized)
    cortex.db.filestore = "/scratch/hb-EGRET-AAA/projects/UMCG/derivatives/pycortex"
    print("Pycortex filestore:", cortex.db.filestore)
    try:
        if atlas == 'benson':
            rois = ['V1', 'V2', 'V3', 'V4', 'LO1', 'LO2', 'V3a', 'V3b']  # benson atlas roi names
        elif atlas == 'manual':
            rois = ['V1', 'V2', 'V3', 'V4', 'LO']  # manual delineation roi names

        # load benson eccentricity labels (needed later to threshold eccen < 15)
        idx_rois1, idx_vls1 = cortex.freesurfer.get_label(subject, label='benson14_eccen-0001',
                                                          fs_dir=fs_dirPATH, hemisphere=('lh', 'rh'))
        # load benson visual area labels, this is the base map we start from
        idx_rois4, idx_vls4 = cortex.freesurfer.get_label(subject, label='benson14_varea-0001',
                                                          fs_dir=fs_dirPATH, hemisphere=('lh', 'rh'))
        if atlas == 'manual':
            # load my manual delineation label
            idx_rois5, idx_vls5 = cortex.freesurfer.get_label(subject, label='manualdelin',
                                                              fs_dir=fs_dirPATH, hemisphere=('lh', 'rh'))
            # overwrite benson values with manual ones wherever I actually drew the manual label
            idx_vls4[idx_rois5] = idx_vls5
    except Exception as e:
        print(f"[SKIPPED] Could not load labels for atlas '{atlas}': {e}")
        continue

    
    for denoising in ["nordic", "nordic_sm4"]:
        # LOAD THE TIME COURSE 
        # data is trimmed, so I need to point to the trimmed subfolder, not the regular one
        base_path_02_trimmed = f'{MAIN_PATH}/pRFM/{subject}/ses-02/{denoising}/avg/{subject}_ses-02_task-{task}_hemi-LR_desc-avg_bold_{depth}.npy'
        base_path_01_trimmed = f'{MAIN_PATH}/pRFM/{subject}/ses-01/{denoising}/avg/{subject}_ses-01_task-{task}_hemi-LR_desc-avg_bold_{depth}.npy'

        # check ses-02 first since that's where most of my RET data actually lives, fall back to ses-01
        if os.path.exists(base_path_02_trimmed):
            file_path = base_path_02_trimmed
        elif os.path.exists(base_path_01_trimmed):
            file_path = base_path_01_trimmed
        else:
            raise FileNotFoundError("No trimmed averaged bold file found (checked ses-01 and ses-02).")
        
        psc_avg_ts_full = np.load(file_path).T[:, 8:]  # drop the first 8 volumes (dummy scans)
        
        # LOAD THE SURFACE 
        cortex.db.default_path = f'{MAIN_PATH}'  
        
        
        surfs = [cortex.polyutils.Surface(*d) for d in cortex.db.get_surf(subject, "fiducial")]
        numel_left = surfs[0].pts.shape[0]
        numel_right = surfs[1].pts.shape[0]
        numel = numel_left + numel_right
        
        # NOTE: idx_rois1/idx_vls1, idx_rois4/idx_vls4, idx_rois5/idx_vls5 were already
        # loaded once above (outer atlas loop) and don't change across denoising types,
        # so the redundant re-load here has been removed.
        rois_list = []
        if atlas=='benson':
          rois_list = np.array([['V1', 'V2', 'V3', 'V4', 'LO1', 'LO2', 'V3a', 'V3b'], [1, 2, 3, 4, 7, 8, 11, 12]])  # benson roi codes
        elif atlas =='manual':
          rois_list = np.array([['V1', 'V2', 'V3', 'V4', 'LO'], [1, 2, 3, 4, 5]])  # manual roi codes
        
        rois_mask=cortex.Vertex.empty(subject)  # empty vertex map, will fill in with 1s for roi vertices
        rois_idx=cortex.Vertex.empty(subject)   # same but stores the actual vertex index instead of just 1/0

        # Restrict to manually-delineated vertices only (when atlas == 'manual'),
        # so Benson-atlas fallback values can't leak into V1-V4/LO ROI selection.
        # (this fixes the bug where non-delineated vertices were sneaking into the manual ROI
        # just because they happened to share the same benson code)
        if atlas == 'manual':
            manual_only_mask = np.zeros(idx_vls4.shape, dtype=bool)
            manual_only_mask[idx_rois5] = True  # only vertices inside my actual manual label count

        for r in range(rois.__len__()):
            roi_idx = np.where(rois[r] == rois_list[0, :])
            if atlas == 'manual':
                # vertex has to match the roi code, be within eccen<15, AND be inside my manual label
                roi_verts = np.where(np.logical_and.reduce((
                    idx_vls4 == int(rois_list[1, roi_idx][0][0]),
                    idx_vls1 < 15,
                    manual_only_mask
                )))[0]
            else:
                # benson atlas doesn't need the extra manual mask check
                roi_verts = np.where(np.logical_and(idx_vls4 == int(rois_list[1, roi_idx][0][0]),idx_vls1<15))[0]
            rois_mask.data[roi_verts]=1
            rois_idx.data[roi_verts]=roi_verts
        
        # only keep the timecourses for vertices inside my roi mask
        psc_avg_ts=psc_avg_ts_full[rois_mask.data==1]
        psc_avg_ts_vx=rois_idx.data[rois_mask.data==1]
        psc_avg_ts.shape
        
        # PRF COARSE FIT
        
        gauss_model = Iso2DGaussianModel(stimulus=prf_stim, hrf=prf_settings['hrf']['pars'], filter_predictions = prf_settings['filter_predictions'], normalize_RFs= prf_settings['normalize_RFs'])
        gauss_fitter=Iso2DGaussianFitter(data=psc_avg_ts[:,:], model=gauss_model, n_jobs=ncores)
        max_eccentricity = round(prf_stim.screen_size_degrees/2)   # half the screen size in degrees
        grid_nr = prf_settings['grid_nr']
        # random grid points to search over before the finer iterative fit
        eccs = np.random.uniform(0.1, max_eccentricity * 1.1, 30)
        sizes = np.random.uniform(0.1, max_eccentricity, 30) 
        polars = np.random.uniform(0, 2 * np.pi, 30)
        hrf_1_grid = np.linspace(prf_settings['hrf']['deriv_bound'][0], prf_settings['hrf']['deriv_bound'][1], 10)
        hrf_2_grid = np.array([0.0])  # keeping this fixed at 0 for now
        
        gauss_grid_bounds = [[prf_settings['prf_ampl'][0],prf_settings['prf_ampl'][1]]]
        gauss_fitter.grid_fit(ecc_grid=eccs, polar_grid=polars, size_grid=sizes, hrf_1_grid=hrf_1_grid, hrf_2_grid=hrf_2_grid, verbose=False, n_batches=prf_settings['n_batches'], fixed_grid_baseline=prf_settings['fixed_grid_baseline'],  grid_bounds=gauss_grid_bounds)
        
        
        # PRF FINER FIT
        
        if prf_settings['constraints']==True:
            g_constraints = []
        else:
            g_constraints = None
        
        # bounds for x, y, size, amplitude, baseline, hrf1, hrf2
        gauss_iter_bounds = [(-1.1 * max_eccentricity, 1.1 * max_eccentricity), (-1.1 * max_eccentricity, 1.1 * max_eccentricity), (0.1, 1 * max_eccentricity),                    
            (prf_settings['prf_ampl'][0], prf_settings['prf_ampl'][1]), (prf_settings['bold_bsl'][0], prf_settings['bold_bsl'][1]), 
            (prf_settings['hrf']['deriv_bound'][0], prf_settings['hrf']['deriv_bound'][1]),(prf_settings['hrf']['pars'][2], prf_settings['hrf']['pars'][2])]
        gauss_fitter.iterative_fit( rsq_threshold=prf_settings['rsq_threshold'], verbose=False, bounds=gauss_iter_bounds,constraints=g_constraints, xtol=float(prf_settings['xtol']), ftol=float(prf_settings['ftol']))
        rsq_mask=np.ones(gauss_fitter.rsq_mask.shape) 
        rsq_mask[gauss_fitter.iterative_search_params[:,7]<prf_settings["rsq_threshold"]]=False
        # sometimes the iterative fit does worse than the grid fit, so check for that and use the grid result instead
        checkrsq=np.where(np.logical_and(gauss_fitter.gridsearch_params[:,-1]>gauss_fitter.iterative_search_params[:,-1],gauss_fitter.iterative_search_params[:,-1]!=0))
        gauss_fitter.iterative_search_params[checkrsq,:]=gauss_fitter.gridsearch_params[checkrsq,:]
        
        prf_params = gauss_fitter.iterative_search_params
        pred_tc=gauss_model.return_prediction(
            mu_x = prf_params[:,0], # x position
            mu_y = prf_params[:,1], # y position
            size = prf_params[:,2], # prf size
            beta = prf_params[:,3], baseline = prf_params[:,4], hrf_1 = prf_params[:,5], hrf_2 = prf_params[:,6])
        
        
        # SAVE THE RESULTS
        session = "ses-01" if "ses-01" in file_path else "ses-02"  # figure out which session the data came from so I can save it in the right place
        
        def save_params(model, model_name):
            if len(rois) == 1:
                pkl_file = opj(MAIN_PATH, 'pRFM', subject, session, denoising, f'roi-{rois[0]}_model-{atlas}-{model_name}-{depth}_desc-prf_params_{task}.pkl')
            else:
                pkl_file = opj(MAIN_PATH, 'pRFM', subject, session, denoising, f'model-{atlas}-{model_name}-{depth}_desc-prf_params_{task}.pkl')
        
            prf_params = model.iterative_search_params
            pred_tc = gauss_model.return_prediction(mu_x=prf_params[:,0], mu_y=prf_params[:,1], size=prf_params[:,2], beta=prf_params[:,3], baseline=prf_params[:,4], hrf_1=prf_params[:,5], hrf_2=prf_params[:,6])
            out_dict = {'model': model, 'settings': prf_settings, 'pred_tc': pred_tc, 'rois_mask': rois_mask.data}
            if len(rois) == 1:
                out_dict['roi_verts'] = roi_verts
        
            os.makedirs(os.path.dirname(pkl_file), exist_ok=True)
            with open(pkl_file, "wb") as f:
                pickle.dump(out_dict, f)
            print(f"Saved PRF params to {pkl_file}")
        
        save_params(gauss_fitter, 'nelder-mead')  # save with nelder-mead as the model name tag

        # MAKE THE PRF MAPS
        # doing this right here instead of a separate script, since I already have
        # everything I need in memory (prf_params, rois_mask) from the fit above

        roi_verts_all = np.where(rois_mask.data == 1)  # same as roi_verts but full array not tuple slice per roi

        mu_x, mu_y = prf_params[:, 0], prf_params[:, 1]
        size_vals = prf_params[:, 2]
        eccentricity = np.sqrt(mu_x**2 + mu_y**2)
        polar_angle = (np.degrees(np.arctan2(mu_y, mu_x)) + 360) % 360  # convert to degrees, wrap to 0-360
        r2_vals = prf_params[:, -1]

        # only keep vertices that pass a basic quality threshold
        mask = (r2_vals > 0.01) & (eccentricity < 20)

        polar_angle_masked = polar_angle.copy()
        eccentricity_masked = eccentricity.copy()
        size_masked = size_vals.copy()
        r2_masked = r2_vals.copy()

        polar_angle_masked[~mask] = 50   # sentinel value for vertices that didn't pass the mask
        eccentricity_masked[~mask] = 50
        size_masked[~mask] = 50
        r2_masked[~mask] = 0

        nverts = cortex.db.get_surf(subject, "fiducial")[0][0].shape[0] + cortex.db.get_surf(subject, "fiducial")[1][0].shape[0]

        pol_map = np.full(nverts, 50)
        ecc_map = np.full(nverts, 50)
        r2_map = np.full(nverts, 0.05)
        sigma_map = np.full(nverts, 50)

        pol_map[roi_verts_all] = polar_angle_masked
        ecc_map[roi_verts_all] = eccentricity_masked
        r2_map[roi_verts_all] = r2_masked
        sigma_map[roi_verts_all] = size_masked

        # split into left and right hemisphere
        fs_subject_dir = os.path.join(MAIN_PATH, "freesurfer", subject, "surf")
        lh_nverts = read_morph_data(os.path.join(fs_subject_dir, "lh.curv")).shape[0]

        lh_pol, rh_pol = pol_map[:lh_nverts], pol_map[lh_nverts:]
        lh_ecc, rh_ecc = ecc_map[:lh_nverts], ecc_map[lh_nverts:]
        lh_r2, rh_r2 = r2_map[:lh_nverts], r2_map[lh_nverts:]
        lh_sigma, rh_sigma = sigma_map[:lh_nverts], sigma_map[lh_nverts:]

        # match benson convention, 0-180 per hemisphere instead of 0-360 overall
        lh_pol = lh_pol % 180
        rh_pol = (rh_pol - 180) % 180

        map_output_dir = os.path.join(MAIN_PATH, "pRFM", subject, session, denoising, "pRF_maps", atlas)
        os.makedirs(map_output_dir, exist_ok=True)

        write_morph_data(os.path.join(map_output_dir, "lh.pol"), lh_pol)
        write_morph_data(os.path.join(map_output_dir, "rh.pol"), rh_pol)
        write_morph_data(os.path.join(map_output_dir, "lh.ecc"), lh_ecc)
        write_morph_data(os.path.join(map_output_dir, "rh.ecc"), rh_ecc)
        write_morph_data(os.path.join(map_output_dir, "lh.r2"), lh_r2)
        write_morph_data(os.path.join(map_output_dir, "rh.r2"), rh_r2)
        write_morph_data(os.path.join(map_output_dir, "lh.sigma"), lh_sigma)
        write_morph_data(os.path.join(map_output_dir, "rh.sigma"), rh_sigma)
        print(f"[DONE] PRF maps saved to: {map_output_dir}")

        # copy over the inflated surfaces too, useful for viewing later
        surf_dir = os.path.join(MAIN_PATH, "freesurfer", subject, "surf")
        for hemi in ["lh", "rh"]:
            src = os.path.join(surf_dir, f"{hemi}.inflated")
            dst = os.path.join(map_output_dir, f"{hemi}.inflated")
            if os.path.exists(src):
                shutil.copy(src, dst)
