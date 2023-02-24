# initialize repository

set -x

# declare project directory
proj='..'

# symlink to bids-mrsim-glio
src=/laudata/llawrence/bids-mrsim-glio
dst=${proj}/data/bids-mrsim-glio
ln -sfn ${src} ${dst}

#dirs=${parent}/data/*
#for dir in ${dirs};
#do
#	name=$(basename ${dir})
#	cmd="ln -sfn ${dir} ${proj}/data/${name}"
#	echo $cmd
#	$cmd
#done

# symlink to interim subfolders
parent=/laudata/llawrence/mrsim_adc_response
dirs=${parent}/interim/*
for dir in ${dirs};
do
	name=$(basename ${dir})
	ln -sfn ${dir} ${proj}/interim/${name}
done

ln -sfn ${src}/derivatives ${proj}/interim/derivatives

# symlink to RT contours
ln -sfn /laudata/rchan/mrsim_gbm/RT_CONTOURS/CONTOURS_occ15T_nii_renamed ${proj}/data/RT_contours

# symlink to patient info spreadsheet
ln -sfn /home/llawrence/Documents/repositories/bids_mrsim_glio/doc/pt_info_GBM_spreadsheet.xlsx ${proj}/data/metadata/pt_info_GBM_spreadsheet.xlsx

# symlink to spreadsheet of patient outcomes
ln -sfn /home/llawrence/Documents/repositories/bids_mrsim_glio/doc/MRSIM_GBM_OCC15T.xlsx ${proj}/data/metadata/MRSIM_GBM_OCC15T.xlsx

# symlink to spreadsheet of patient metadata for MR-Linac
ln -sfn /home/llawrence/Documents/repositories/dwi_response/data/MRL_Brain_PatientCohort_20211024.xlsx ${proj}/data/metadata/MRL_Brain_PatientCohort_20211024.xlsx

# symlink to momentum tracker
ln -sfn /home/llawrence/Documents/repositories/dwi_response/data/momentum_tracker_full.xlsx ${proj}/data/metadata/momentum_tracker_full.xlsx

# symlink to extra resection status information
ln -sfn /home/llawrence/Documents/repositories/dwi_response/data/subjects_resection_status_AT.xlsx ${proj}/data/metadata/subjects_resection_status_AT.xlsx
