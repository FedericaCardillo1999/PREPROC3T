function main_spmmoco(project, subject)
%set(0, 'DefaultFigureVisible','off');
fig=figure;
addpath(genpath('/home2/p315561/programs/spm12'));
addpath(genpath('/home2/p315561/programs/cflaminar/shell'));

mybatchpath ='/home2/p315561/programs/cflaminar/shell/';
myfilespath =['/scratch/hb-EGRET-AAA/projects/' project '/derivatives/spm/'];
cd(myfilespath)
subjects=dir;
spm_jobman('initcfg');

cd(mybatchpath)
load('batch_spmmoco.mat');
%copy func files
cd ([myfilespath 'sub-' subject '/ses-02/no_moco']);     %%%%%% mudar ses 
niigzFiles=dir('*nii.gz')
for f=1:numel(niigzFiles)
    niigzFile=niigzFiles(f).name
    gunzip(niigzFile,[myfilespath 'sub-' subject '/ses-02/func'])   %%%%% mudar ses 
end
cd([myfilespath 'sub-' subject '/ses-02/func']);   %%%%% mudar ses 
functionals1 = spm_select('ExtFPListRec', pwd, '^*run-1_bold.nii',1:1000);
functionals2 = spm_select('ExtFPListRec', pwd, '^*run-2_bold.nii',1:1000);
functionals3 = spm_select('ExtFPListRec', pwd, '^*run-3_bold.nii',1:1000);
functionals4 = spm_select('ExtFPListRec', pwd, '^*run-4_bold.nii',1:1000);
  
matlabbatch{1}.spm.spatial.realign.estwrite.data = {
    cellstr(functionals1)
    cellstr(functionals2)
    cellstr(functionals3)
    cellstr(functionals4)
                                        }';

matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [2 1];

spm_jobman('run', matlabbatch)


end
