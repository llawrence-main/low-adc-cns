folder="/scratch/llawrence/bids-cns-mrl/derivatives/mrl_dwi/longitudinal_dwi/contours/sub-M001/ses-MRL001"
t1w_filename=$folder/t1w_reference.nii.gz
gtv_filename=$folder/rGTV.nii.gz
ctv_filename=$folder/rCTV.nii.gz
out=test_render.jpg
cmd="python3 render_rois.py -out $out -base $t1w_filename -extra $gtv_filename -main $ctv_filename"
echo $cmd
$cmd
