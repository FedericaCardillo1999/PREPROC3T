#! /bin/bash
#$ -N job_fmriprep
#$ -S /bin/bash
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/fmriprep/CFLamUp/
#$ -u bittencourt
#$ -V

export SUBJECTS_DIR=${SUBJECTS_DIR}

# Usage: source upsampling.sh sub-xxx
# Upsamples Nifti files

subject=sub-$1
session=1

singularity run --cleanenv -B /data1/projects:/data1/projects /packages/singularity_containers/containers_bids-fmriprep--20.2.7.simg /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/derivatives/masked_mp2rage /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/derivatives participant --participant-label $1 --skip-bids-validation --md-only-boilerplate --fs-license-file /data1/projects/dumoulinlab/Lab_members/Mayra/license.txt --output-spaces func fsnative --fs-subjects-dir /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/derivatives/freesurfer --stop-on-first-crash --bold2t1w-init header --anat-only --nthreads 16 -w /data1/projects/dumoulinlab/Lab_members/Mayra/fmriprep/CFLamUp
