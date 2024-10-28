#! /bin/sh
#$ -N spmMoCo_p2
#$ -S /bin/sh
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt
#$ -V


#Usage: qsub -V job_spmmoco.sh [Project_name]; will search for bold files in /Project/sub-xxx/func

subject=sub-$1
cd ${DERIVATIVES}/spm/${subject}/ses-1/func

ls | grep '^sub.*\.nii$' | grep -v '^rsub.*\.nii$' | xargs rm

for run in 1 2 3 4 5 6;
do
    mv ${DERIVATIVES}/spm/${subject}/ses-1/func/r${subject}_ses-1_task-ret_run-${run}_desc-preproc_bold.nii ${DERIVATIVES}/spm/${subject}/ses-1/func/${subject}_ses-1_task-ret_run-${run}_desc-preproc_bold.nii 
done

mv ${DERIVATIVES}/spm/${subject}/ses-1/func/mean${subject}_ses-1_task-ret_run-1_desc-preproc_bold.nii ${DERIVATIVES}/spm/${subject}/ses-1/func/${subject}_ses-1_task-ret_run-1_boldref.nii

gzip *.nii

cp ${DERIVATIVES}/spm/${subject}/ses-1/func/*.nii.gz ${DERIVATIVES}/fmriprep/${subject}/ses-1/func/