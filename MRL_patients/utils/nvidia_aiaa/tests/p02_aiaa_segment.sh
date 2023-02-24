#!/bin/bash

set -x

# directories
out=outputs

# server
serv="http://spinecho:5000"

# call aiaa-segment
cmd="aiaa-segment -i ${out}/merged.nii.gz -m clara_pt_brain_mri_segmentation_inputs_t1ce_t1_flair -o segmentation.nii.gz -od ${out} -s ${serv}"
$cmd
