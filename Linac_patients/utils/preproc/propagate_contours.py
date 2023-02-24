# imports
from utils.preproc.project_parameters import get_bids_layout, get_reference_list
from utils.preproc.flirt_utils import flirt_volumes, flirt_propagate, declare_out_name, flirt_apply
from utils.preproc.io import func_msg
from utils.preproc.align_volumes import get_reference_fname, get_sessions
from os.path import join, isdir, basename, isfile, dirname
import os
import pandas as pd
from pathlib import Path
import json

def propagate_contours(dirs,subjects,source='manual'):
    '''Registers CT and T1w of reference space and propagate contours (GTV, CTV)
    Parameters:
        dirs (dict): dictionary of directories
        subjects (list): list of subjects
        source (str,optional): source of contours {manual=drawn by radoncs, aiaa=created by AIAA tool}
    '''

    # communicate with user
    func = 'propagate_contours (contour source = %s)' %(source)
    func_msg(func,'start')

    # declare parameters
    suffix = 'coreg'
    layout = get_bids_layout()
    layout_dv = get_bids_layout(include_derived=True)
    df_ref = get_reference_list()

    if source == 'manual':
        out_folder = 'coreg_contours'
    elif source == 'aiaa':
        out_folder = 'coreg_aiaa_seg'

    # declare list to hold reference name
    rows = []

    for subject in subjects:

        print('Processing: ' + subject)

        # get reference filename
        ref_fname = get_reference_fname(dirs,layout,subject)
        ref_session = basename(dirname(dirname(ref_fname))).replace('ses-','')
        
        # get all sessions
        sessions = get_sessions(layout,subject)

        for session in sessions:

            # get filenames of contours and post-ce T1w
            [t1w_coreg_fname,contour_fnames] = get_contour_fnames(dirs,layout_dv,subject,session,source=source)

            if not contour_fnames:
                print('There are no contours: sub-%s_ses-%s' %(subject,session))

            else:

                # create output directory
                out_dir = join(dirs['bids'],'derivatives',out_folder,'sub-'+subject,'ses-'+session,'anat')
                if not isdir(out_dir):
                    os.makedirs(out_dir)

                if (session == ref_session) and ('ce-gd' in ref_fname): # if reference volume is the post-Gd

                    # create symbolic links to contours
                    symlink_contours(contour_fnames,suffix,out_dir)

                else:

                    # get T1w-ce transformation matrix
                    in2ref_fname = t1w_coreg_fname.replace('.nii.gz','.mat')
                    t1w_fname = source_filename(dirs,t1w_coreg_fname)

                    # co-register T1w-ce and reference T1w and propagate contours
                    out_fnames = flirt_apply(contour_fnames,ref_fname,in2ref_fname,out_dir,suffix,overwrite=False,method='nearestneighbour')

                    # create .json sidecars
                    create_json_bids(t1w_fname,ref_fname,contour_fnames,out_fnames)

def get_contour_fnames(dirs,layout,subject,session,source='manual'):
    '''Returns the filename of the T1w scan and contours
    Parameters
        dirs: directories dictionary
        layout: BIDS layout
        subject: subject name
        session: session name
        source (str, optional): source of contours
    '''
    
    # get filename of T1w-ce
    t1w_fname = ''
    t1w_fnames = layout.get(scope='derivatives',subject=subject,session=session,suffix='T1w',extension='.nii.gz',return_type='filename')
    if t1w_fnames:
        for ce in ['ce-gd','']:
            for acq in ['fs','ip']:
                for tmp_fname in t1w_fnames:
                    if (ce in tmp_fname) and (acq in tmp_fname) and isfile(tmp_fname.replace('.nii.gz','.mat')):
                        t1w_fname = tmp_fname
                        break
                if t1w_fname: break
            if t1w_fname: break
    
    # declare names and folder for contours
    if source == 'manual':
        c_names = ['GTV','CTV']
        folder = 'contours'
    elif source == 'aiaa':
        c_names = ['enhancingtumour','tumourcore','wholetumour']
        folder = 'aiaa_seg'
    
    # contruct contour filenames and keep the existing ones
    names = ['sub-%s_ses-%s_label-%s_mask' %(subject,session,x) for x in c_names] 
    contour_fnames = [os.path.join(dirs['bids'],'derivatives',folder,'sub-'+subject,'ses-'+session,'anat',x+'.nii.gz') for x in names]
    contour_fnames = [x for x in contour_fnames if isfile(x)]

    return t1w_fname, contour_fnames

def create_json_bids(source_fname,ref_fname,contour_fnames,out_fnames):
    """Creates .json sidecar for propagated contour
    Args:
        source_fname: source filename used to define contours
        ref_fname: filename of reference volume
        contour_fnames: original contour filenames
        out_fnames: co-registered contour filenames
    """
    
    ref_relative = get_bids_relative(ref_fname)
    source_relative = get_bids_relative(source_fname)
    for (contour_fname,out_fname) in zip(contour_fnames,out_fnames):
        data = {}
        contour_relative = get_bids_relative(contour_fname,derived=True)
        data['RawSources'] = [source_relative]
        data['Sources'] = [contour_relative]
        data['SpatialReference'] = ref_relative
        fn_json = out_fname.replace('.nii.gz','.json')
        with open(fn_json,'w') as f:
            json.dump(data,f)

def get_bids_relative(fname,derived=False):
    """Get filename relative to BIDS dataset from absolute path
    Args:
        fname (str): absolute path to file
        derived (bool): set to True when file is derived; will go up two extra folders
    Returns:
        fname_rel: filename relative to BIDS root
    """
    if derived:
        n = 5
    else:
        n = 3
    fname_rel = fname.replace(str(Path(fname).parents[n])+'/','')
    return fname_rel

def get_in2ref_filename(dirs,t1w_fname,suffix):
    """Returns the filename of the transformation matrix to the reference volume
    Args:
        dirs: directories dictionary
        t1w_fname: filename of T1w volume
        suffix: suffix used for desc- entity in co-registration
    Returns:
        in2ref_filename: filename of matrix
    """
    t1w_stem = Path(t1w_fname).stem.split('.')[0]
    t1w_coreg_name = declare_out_name(t1w_stem,suffix)
    data = t1w_stem.split('_')
    subject_entity = data[0]
    session_entity = data[1]
    in2ref_filename = os.path.join(dirs['bids'],'derivatives','coreg',subject_entity,session_entity,'anat',t1w_coreg_name+'.mat')
    return in2ref_filename

def source_filename(dirs,coreg_fname):
    """Converts a filename in the coreg/ directory to the source filename in the raw BIDS dataset
    Args:
        dirs: dictionary of directories
        coreg_fname: filename of co-registered volume
    Returns:
        fname: filename in raw dataset
    """
    coreg_name = Path(coreg_fname).stem.split('.')[0]
    f_name = coreg_name.replace('desc-coreg_','')
    data = f_name.split('_')
    subject_entity = data[0]
    session_entity = data[1]
    fname = os.path.join(dirs['bids'],subject_entity,session_entity,'anat',f_name+'.nii.gz')
    return fname

def symlink_contours(contour_fnames,suffix,out_dir):
    """Creates symbolic links to contours
    Args:
        contour_fnames (list): filenames of contours
        suffix (str): suffix for desc- entity
        out_dir (str): output directory
    """

    for contour_fname in contour_fnames:
        contour_bits = Path(contour_fname).stem.split('.')[0].split('_')
        contour_bits.insert(len(contour_bits)-1,'desc-'+suffix)
        out_name = '_'.join(contour_bits)
        out_fname = os.path.join(out_dir,out_name+'.nii.gz')
        if isfile(out_fname):
            print('Symlink already exists: ' + out_fname)
        else:
            os.symlink(contour_fname,out_fname)
            print('Symlink created: ' + out_fname)


