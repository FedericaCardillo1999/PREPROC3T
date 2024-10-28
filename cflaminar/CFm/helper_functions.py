# helper_functions.py
import numpy as np
import cortex

# %%
def readVerts(roi, hemi, subject='fsaverage', atlas='benson', fs_dirPATH='/Volumes/May_fMRI/Inzicht_CFM/derivatives/freesurfer'):

    # In order to get the number of vertices in this subject's cortical surface
    # we have to load in their surfaces and get the number of points in each
    surfs = [cortex.polyutils.Surface(*d)
             for d in cortex.db.get_surf(subject, "fiducial")]

    # First we need to import the surfaces for this subject
    numel_left = surfs[0].pts.shape[0]
    numel_right = surfs[1].pts.shape[0]

    if atlas=='inkscape':
        # find vertices within ROI/ICN
        roi_verts = cortex.get_roi_verts(subject)
        # roi_verts is a dictionary (in this case with two entries)
        roi_verts = roi_verts[roi]

    elif atlas=='benson':
        #Import ROIs form Benson's atlas        # => pmap({1:  'V1',   2: 'V2',  3: 'V3',  4: 'hV4',  5: 'VO1',
        # =>       6:  'VO2',  7: 'LO1', 8: 'LO2', 9: 'TO1', 10: 'TO2',
        # =>       11: 'V3b', 12: 'V3a'})
        idx_rois4, idx_vls4 = cortex.freesurfer.get_label(subject, label='benson14_varea-0001',
                                                          fs_dir=fs_dirPATH,
                                                          hemisphere=('lh', 'rh'),
                                                          verbose=True)
        rois_list=[]
        rois_list= np.array([['V1', 'V2', 'V3', 'V3a', 'V3b', 'V4', 'LO1', 'LO2'],[1, 2, 3, 12, 11, 4, 7, 8]])

        roi_idx=np.where(roi == rois_list[0,:] )
        roi_verts = np.array(np.where(idx_vls4 == int(rois_list[1, roi_idx])))[0]

    elif atlas=='manual':
        #Import ROIs form Benson's atlas        # => pmap({1:  'V1',   2: 'V2',  3: 'V3',  4: 'hV4',  5: 'VO1',
        # =>       6:  'VO2',  7: 'LO1', 8: 'LO2', 9: 'TO1', 10: 'TO2',
        # =>       11: 'V3b', 12: 'V3a'})
        idx_rois4, idx_vls4 = cortex.freesurfer.get_label(subject, label='benson14_varea-0001',
                                                          fs_dir=fs_dirPATH,
                                                          hemisphere=('lh', 'rh'),
                                                          verbose=True)

        idx_rois5, idx_vls5 = cortex.freesurfer.get_label(subject, label='manualdelin',
                                                          fs_dir=fs_dirPATH,
                                                          hemisphere=('lh', 'rh'),
                                                          verbose=True)
        idx_vls4[idx_rois5] = idx_vls5
        rois_list=[]
        rois_list= np.array([['V1', 'V2', 'V3', 'V3a', 'V3b', 'V4', 'LO1', 'LO2'],[1, 2, 3, 12, 11, 4, 7, 8]])

        roi_idx=np.where(roi == rois_list[0,:] )
        roi_verts = np.array(np.where(idx_vls4 == int(rois_list[1, roi_idx])))[0]

    if hemi == "RH":
        roi_verts = roi_verts[roi_verts > numel_left] #or >=?

    elif hemi=="LH":
        roi_verts = roi_verts[roi_verts <= numel_left]

    else:
        pass

    return roi_verts
# %%
def loadSurface(subject):
    """
    Function to get the number of vertices in a subjects cortical surface
    Parameters
    ----------
    subject: str
             String to indicate which subject to use in pycortex database (e.g. sub-001, fsaverage)
    Returns:
    int, int, int
    number of vertices in left hem, right hem and both hems combined
    """

    # In order to get the number of vertices in this subject's cortical surface
    # we have to load in their surfaces and get the number of points in each
    surfs = [cortex.polyutils.Surface(*d)
             for d in cortex.db.get_surf(subject, "fiducial")]

    # First we need to import the surfaces for this subject
    numel_left = surfs[0].pts.shape[0]
    numel_right = surfs[1].pts.shape[0]
    numel = numel_left + numel_right

    return numel_left, numel_right, numel, surfs

# %%
def read_RTfile(rtfile, nmov, subjectid, idx_con, idx_noise):
    RT=np.array (nmov)
    RT=getattr(rtfile, subjectid[-5:])
    RT[idx_con]=-1 #code control movies as -1
    RT[idx_noise]=-2 #code noise movies as -2
    RT
    return RT
