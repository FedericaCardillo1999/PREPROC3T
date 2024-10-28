#!/bin/bash
#$ -S /bin/bash
#$ -N fsups_all
#$ -wd /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/derivatives/freesurfer
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/freesurfer/CFLamUp/fsups_all.log
#$ -j Y
#$ -q long.q@jupiter
#$ -V

#usage:  qsub -V job_freesurferHires.sh -pe smp {#threads} xxx
subject=sub-${2}
session=1
threads=${1}
echo "${subject}"
echo "${threads}"

export SUBJECTS_DIR=/data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/derivatives/freesurfer
recon-all -subjid ${subject} -i /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/derivatives/masked_mp2rage/${subject}/ses-1/anat/${subject}_ses-1_acq-MP2RAGE_desc-masked_T1w.nii.gz -hires -parallel -skullstrip -wsthresh 25 -no-wsgcaatlas -clean-bm -openmp ${threads} -all -T2 /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/${subject}/ses-1/anat/${subject}_ses-1_acq-3DTSE_T2w.nii.gz -T2pial

#recon-all -skullstrip -wsthresh 25 -no-wsgcaatlas -clean-bm -subjid sub-001
#recon-all -subjid ${subject} -hires -parallel -openmp 15 -autorecon2 -autorecon3 -T2pial
