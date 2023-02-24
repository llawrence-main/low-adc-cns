#!/bin/bash

set -x

# directories
in=inputs
out=outputs

# declare filenames
t1=${in}/sub-GBM084_ses-GLIO01_acq-fs_T1w.nii.gz
t1ce=${in}/sub-GBM084_ses-GLIO01_acq-fs_ce-gd_T1w.nii.gz
flair=${in}/sub-GBM084_ses-GLIO01_FLAIR.nii.gz

# run aiaa-preproc
cmd="aiaa-preproc -i ${t1ce} ${t1} ${flair} -od ${out} -r -vs 1 -register --fast-register --bet --merge"
$cmd



