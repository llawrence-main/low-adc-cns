# Imports
from utils.preproc.seg_utils import do_hdbet
import os
from utils.preproc.project_parameters import get_reference_list, declare_directories

def extract_brain(dirs,subjects):
    '''Does brain extraction using HD-BET
    Parameters
        dirs: directories dictionary
        subjects: names of subjects
    '''

    # get parameters
    dirs = declare_directories()
    coreg_suffix = 'coreg' # suffix for coregistered volumes
    df = get_reference_list()

    # Loop subjects
    for subject in subjects:

        # Get subject and reference volume name
        name_ref = df['ReferenceVolume'][df['Subject']==subject].iloc[0]

        # get session from reference volume name
        session = name_ref.split('_')[1].replace('ses-','')

        # Create output directory
        out_dir = os.path.join(dirs['mr_linac'],'seg','sub-'+subject,'ses-'+session)
        if not os.path.isdir(out_dir):
            os.makedirs(out_dir)

        # Declare path to T1w volume
        t1_path = os.path.join(dirs['bids'],'dataset-mrl','sub-'+subject,'ses-'+session,'anat',name_ref + '.nii.gz')
        if os.path.isfile(t1_path): 
            # Call HD-BET
            do_hdbet(t1_path,out_dir)
        else:
            print('%s: T1w file not found' %(subject))
