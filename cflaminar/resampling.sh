#!/bin/bash

#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --mem=20GB

# Usage: python /home2/p315561/programs/cflaminar/shell/resampling/resampling.sh [subject] [task] [project]
#
# UMCG uses trimmed (_new) bold files with a fixed run count and writes to a
# trimmed_runs subfolder, sessions ses-01/ses-02 only. Everything else uses
# the original bold files with a dynamic run count, standard output path,
# and includes ses-03. Always runs both nordic and nordic_sm4.

subject=sub-$1
task=$2
project=$3
depth=1.0
a=0

PROJ_DIR="/scratch/hb-EGRET-AAA/projects/${project}"
export SUBJECTS_DIR="${PROJ_DIR}/derivatives/freesurfer"
OUT_DIR="${PROJ_DIR}/derivatives/resampled"
mkdir -p "${OUT_DIR}"

if [[ "${project}" == "OVGU" ]]; then
  sessions=(ses-01 ses-02 ses-03)
else
  sessions=(ses-01 ses-02)
fi

for session in "${sessions[@]}"; do
  FUNC_DIR="${PROJ_DIR}/${subject}/${session}/func"
  [[ -d "${FUNC_DIR}" ]] || continue

  # project-specific settings, worked out once per session instead of
  # repeated inside every loop below
  if [[ "${project}" == "UMCG" ]]; then
    src_suffix="_new"
    out_tag="_trimmed_runs"
    subdir="trimmed_runs/"
    [[ "${task}" == "RestingState" ]] && nruns=2 || nruns=4
  else
    src_suffix=""
    out_tag=""
    subdir=""
    nruns=$(ls "${FUNC_DIR}/${subject}_${session}_task-${task}_run-"*"_bold.nii.gz" 2>/dev/null | wc -l)
  fi
  [[ "${nruns}" -eq 0 ]] && continue

  echo "  ${session}: ${nruns} runs"

  for denoising in nordic nordic_sm4; do
    smoothing=0
    [[ "${denoising}" == "nordic_sm4" ]] && smoothing=4
    denoise_out_dir="${OUT_DIR}/${subject}/${subdir}${session}/${denoising}"
    mkdir -p "${denoise_out_dir}"

    for hemi_pair in "lh L" "rh R"; do
      read -r hemi H <<< "${hemi_pair}"

      for run in $(seq "${nruns}"); do
        filename="${subject}_${session}_task-${task}_run-${run}_bold"
        src_path="${FUNC_DIR}/${filename}${src_suffix}.nii.gz"
        out_name="${subject}_${session}_task-${task}_run-${run}_space-fsnative_hemi-${H}_desc-${denoising}${out_tag}_bold_GM.gii"

        # UMCG's run count is fixed rather than counted, so make sure the
        # file actually exists before handing it to mri_vol2surf
        if [[ ! -f "${src_path}" ]]; then
          echo "    WARNING: missing ${src_path}, skipping"
          continue
        fi

        echo "    mri_vol2surf: run-${run} hemi-${hemi} smooth-${smoothing}"
        mri_vol2surf \
          --src "${src_path}" \
          --out "${denoise_out_dir}/${out_name}" \
          --hemi "${hemi}" \
          --out_type gii \
          --projfrac-avg "${a}" "${depth}" 0.1 \
          --interp trilinear \
          --regheader "${subject}" \
          --surf-fwhm "${smoothing}" \
          --cortex
      done
    done
  done
done

echo "Done: ${subject}, task=${task}, project=${project}."