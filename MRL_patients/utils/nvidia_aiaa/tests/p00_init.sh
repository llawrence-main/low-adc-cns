#!/bin/bash

set -x

# symlink to directory of anatomical images
parent=/home/llawrence/Documents/mrsim_adc_response/data/bids-mrsim-glio
sub=sub-GBM084
ses=ses-GLIO01
anat=${parent}/${sub}/${ses}/anat
in=inputs
ln -sfn ${anat} ${in}

# create output directory
out=outputs
mkdir ${out}




