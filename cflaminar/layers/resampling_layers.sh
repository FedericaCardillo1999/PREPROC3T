#!/bin/sh
#SBATCH --output=/scratch/hb-EGRET-AAA/resampling.out

# Usage: /home2/p315561/programs/cflaminar/shell/layers/resampling_layers.sh <subject_number>

subject=sub-$1
session=01
PROJ_DIR=/scratch/hb-EGRET-AAA/projects/7T
OUT_DIR=${PROJ_DIR}/derivatives/resampled

# equal-volume cortical depths for a 3-layer split (deep, middle, superficial)
depths="0.3333333333333333 0.5555555555555556 0.7777777777777778"

# which denoising version(s) to run - add "nordic_sm4" or "no_denoising" here
# later if I need them, the case statement below already knows what to do
denoisings="nordic"

mkdir -p "$OUT_DIR"

for denoising in $denoisings; do
  # where the source functional data lives and how much smoothing to apply
  # depends on which denoising version this is
  case $denoising in
    nordic)
      SOURCE_DIR=${PROJ_DIR}/derivatives/spm/${subject}/ses-${session}/func
      smoothing=0
      ;;
    nordic_sm4)
      SOURCE_DIR=${PROJ_DIR}/${subject}/ses-${session}/func
      smoothing=4
      ;;
    no_denoising)
      SOURCE_DIR=${PROJ_DIR}/${subject}/ses-${session}/no_nordic
      smoothing=0
      ;;
  esac

  denoise_out_dir=${OUT_DIR}/${subject}/ses-${session}/${denoising}
  mkdir -p "$denoise_out_dir"

  for hemi_pair in "lh L" "rh R"; do
    read -r hemi h <<< "$hemi_pair"

    for depth in $depths; do
      # sample a thin band centered on this depth (+/- 0.125) and average across it,
      # this replaces each equi-volume depth's "layer" with a small window around it
      a=$(awk "BEGIN{print $depth - 0.125}")
      b=$(awk "BEGIN{print $depth + 0.125}")

      for run in 1 2 3; do
        filename=${subject}_ses-${session}_task-RestingState_run-${run}_bold_transformed
        out_name=${subject}_ses-${session}_task-RestingState_run-${run}_space-fsnative_hemi-${h}_desc-${denoising}_bold_${depth}.gii

        echo "Resampling run-${run} hemi-${hemi} depth-${depth} (smoothing ${smoothing} FWHM)"
        mri_vol2surf \
          --src "${SOURCE_DIR}/${filename}.nii.gz" \
          --out "${denoise_out_dir}/${out_name}" \
          --surf "equi${depth}.pial" \
          --hemi "$hemi" \
          --out_type gii \
          --projfrac-avg "$a" "$b" 0.05 \
          --interp trilinear \
          --regheader "$subject" \
          --surf-fwhm "$smoothing" \
          --cortex
      done
    done
  done
done

echo "Done resampling layers for ${subject}."
