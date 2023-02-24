# Imports
from utils.preproc.seg_utils import do_hdbet
import os
from utils.preproc.project_parameters import get_reference_list, declare_directories, get_bids_layout
from utils.preproc.propagate_contours import get_bids_relative
from utils.preproc.align_volumes import get_reference_fname
from os.path import basename, dirname

def extract_brain(dirs,subjects):
    '''Does brain extraction using HD-BET
    Parameters
        dirs: directories dictionary
        subjects: names of subjects
    '''

    # get parameters
    dirs = declare_directories()
    layout = get_bids_layout()
#    df = get_reference_list()

    # Loop subjects
    for subject in subjects:

        # Get subject and reference volume name
        t1_path = get_reference_fname(dirs,layout,subject)
        session = basename(dirname(dirname(t1_path))).replace('ses-','')

        # Create output directory
        out_dir = os.path.join(dirs['bids'],'derivatives','hdbet','sub-'+subject,'ses-'+session,'anat')
        if not os.path.isdir(out_dir):
            os.makedirs(out_dir)

        # Declare path to T1w volume
        if os.path.isfile(t1_path): 
            # Call HD-BET
            do_hdbet(t1_path,out_dir)
        else:
            print('%s: T1w file not found' %(subject))


def create_json(t1_path):
    """Creates the .json sidecar for the brain mask
    Args:
        t1_path: filename of T1w volume
    """

    data = {}
    t1_relative = get_bids_relative(t1_path)
    data['RawSources'] = [t1_relative]
    with open(fn,'w') as f:
        json.dump(data,f)

