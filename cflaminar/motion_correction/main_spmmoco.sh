function main_spmmoco(project, subject, session, task)
% Runs SPM realign+reslice motion correction for a subject/session/task.
% Automatically detects however many runs are present (2-6), so there's no
% need to call a different function per run count anymore.
%
% task must be specified explicitly (e.g. 'RestingState', 'RET', 'RET2') so
% that if a subject's func folder ever has more than one task's files in it,
% motion correction only ever picks up the runs for the task you asked for.
%
% rtm (register-to-mean) is fixed at 0 for everyone - see the note further
% down where it's set, next to roptions.interp, for why.
%
% Usage: main_spmmoco(project, subject, session, task)
% Example: main_spmmoco('EGRET+', 'sub-09', '02', 'RestingState')

fig = figure;

addpath(genpath('/home2/p315561/programs/spm12'));
addpath(genpath('/home2/p315561/programs/cflaminar/shell/motion_correction'));

mybatchpath = '/home2/p315561/programs/cflaminar/shell/motion_correction/';
myfilespath = ['/scratch/hb-EGRET-AAA/projects/' project '/derivatives/spm/'];

no_moco_path = [myfilespath subject '/ses-' session '/no_moco'];
func_path    = [myfilespath subject '/ses-' session '/func'];

cd(myfilespath)
spm_jobman('initcfg');

% figure out how many runs this subject/session/task actually has, instead
% of needing to be told - looks at the no_moco folder and counts distinct
% run-N numbers among this task's *_bold.nii.gz files specifically
niigzFiles = dir(fullfile(no_moco_path, ['*task-' task '_run-*_bold.nii.gz']));
run_nums = [];
for f = 1:numel(niigzFiles)
    tok = regexp(niigzFiles(f).name, 'run-(\d+)_bold\.nii\.gz$', 'tokens');
    if ~isempty(tok)
        run_nums(end+1) = str2double(tok{1}{1}); %#ok<AGROW>
    end
end
run_nums = unique(run_nums);
nruns = numel(run_nums);

if nruns == 0
    error('No task-%s run-*_bold.nii.gz files found in %s', task, no_moco_path);
end
if ~isequal(run_nums, 1:nruns)
    warning('Run numbers in %s for task-%s are not contiguous starting from 1 (found: %s). Proceeding anyway.', ...
        no_moco_path, task, mat2str(run_nums));
end
fprintf('Detected %d run(s) for %s ses-%s task-%s\n', nruns, subject, session, task);

% unzip the functional files from no_moco into func, same as before
cd(no_moco_path);
for f = 1:numel(niigzFiles)
    gunzip(niigzFiles(f).name, func_path);
end

% select the files for each run and build the data cell array SPM expects
cd(func_path);
functionals = cell(1, nruns);
for r = 1:nruns
    pattern = ['^' subject '_ses-' session '_task-' task '_run-' num2str(r) '_bold.nii$'];
    selected = cellstr(spm_select('ExtFPListRec', pwd, pattern, 1:1000));

    % catch the case where no_moco had this run but it didn't make it into
    % func after unzip (e.g. gunzip failed, or the file was actually missing)
    if isempty(selected) || (numel(selected) == 1 && isempty(selected{1}))
        error('No volumes found for run-%d in %s (pattern: %s). Check that unzip actually produced this run''s file.', ...
            r, func_path, pattern);
    end

    functionals{r} = selected;
end

% single shared batch template - same eoptions/roptions across all run
% counts (see note below), only .data changes per subject
cd(mybatchpath)
load('batch_spmmoco_template.mat');

matlabbatch{1}.spm.spatial.realign.estwrite.data = functionals;

% set explicitly rather than relying only on what's saved in the template,
% so these two settings are visible here and not hidden inside a .mat file:
%   - roptions.interp = 4 avoids a cropping issue seen with lower interpolation
%   - eoptions.rtm = 0 means register-to-first (not register-to-mean).
%     The old per-run-count .mat templates disagreed on this (2/3-run had
%     rtm=1, 4/5/6-run had rtm=0) with no real reason for the split - it
%     was decided to standardize on rtm=0 for everyone, and to set it here
%     explicitly so it can never silently change just because a different
%     .mat template gets loaded in the future.
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.interp = 4;
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [2 1];
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.rtm = 0;

spm_jobman('run', matlabbatch)

end
