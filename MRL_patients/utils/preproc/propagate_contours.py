# imports
from utils.preproc.project_parameters import get_bids_layout, declare_subject_reference_dict, date_to_session, declare_protocol_names, get_t1w_reference
from utils.preproc.flirt_utils import flirt_volumes, flirt_propagate
from utils.preproc.io import func_msg, select_filenames
from utils.preproc.align_volumes import get_reference_fname
from os.path import join, isdir, basename, isfile
from glob import glob
import os
import pandas as pd
import re

def propagate_contours_glio(dirs,subjects):
    '''Registers the MR-sim T1w to the reference MRL T1w and propagates contours (GTV, CTV)
    params:
        dirs: dictionary of directories
        subjects: list of subjects
    '''

    # communicate with user
    func = 'propagate_contours_glio'
    func_msg(func,'start')

    # declare parameters
    suffix = 'coreg'
    debug = False

    # loop list of subjects
    for subject in subjects:

        dir_subject = join(dirs['glio_t1c'],'sub-' + subject)

        if not isdir(dir_subject):
            print(f"Directory of GLIO contours does not exist, skipping: {dir_subject}")
        else:

            # get T1w reference filename
            fname_ref = get_t1w_reference(subject)

            # loop sessions
            dirs_sessions = glob(join(dir_subject,'ses-*'))
            for dir_session in dirs_sessions:

                # get T1w, GTV, and CTV filenames
                [fname_t1,fnames_contours] = get_glio_contour_filenames(dir_session)

                if debug:
                    print(f"reference T1w filename: {fname_ref}")
                    print(f"source T1w filename: {fname_t1}")
                    for fname_contour in fnames_contours:
                        print(f"    Contour filename: {fname_contour}")

                # create output directory
                session = os.path.basename(dir_session).replace('ses-','')
                out_dir = join(dirs['mr_sim'],'glio_contours','sub-'+subject,'ses-'+session)
                if not isdir(out_dir):
                    os.makedirs(out_dir)

                # propagate contours
                remove_interim = not debug
                flirt_propagate(fname_t1,fname_ref,fnames_contours,suffix,out_dir,overwrite=False,resample=2,inverse=False,remove_interim=remove_interim)

    # communicate with user
    func = 'propagate_contours_glio'
    func_msg(func,'end')

def get_glio_contour_filenames(folder):
    '''returns the filenames for the T1w volume, GTV, and CTV (if they exist) for a given session
    params
        folder (str): path to folder with GLIO contours for a given session
    returns
        fname_t1 (str): path to T1w volume
        fnames_contours (str): paths to contours
    '''

    fname_t1 = join(folder,'reference.nii.gz')

    # search for GTV and CTV, case insensitive
    regexp_gtv = re.compile('gtv',re.IGNORECASE)
    gtv_fnames = select_filenames('FPList',folder,regexp_gtv)

    regexp_ctv = re.compile('ctv',re.IGNORECASE)
    ctv_fnames = select_filenames('FPList',folder,regexp_ctv)
    fnames_contours = gtv_fnames + ctv_fnames

    return fname_t1, fnames_contours

def propagate_contours(dirs,subjects):
    '''Registers CT and T1w of reference space and propagate contours (GTV, CTV)
    Parameters:
        dirs: dictionary of directories
        subjects: list of subjects
    '''

    # communicate with user
    func = 'propagate_contours'
    func_msg(func,'start')

    # declare parameters
    suffix = 'coreg'
    layout_mrl = get_bids_layout('mrl')

    # declare list to hold reference name
    rows = []

    # loop subjects
    for subject in subjects:

        print('Processing: ' + subject)

        # get reference filename
        ref_fname = get_reference_fname(dirs,layout_mrl,subject)
        
        # get reference name and session
        ref_name = basename(ref_fname).replace('.nii.gz','')
        session = ref_name.split('_')[1].replace('ses-','')

        # create output directory
        out_dir = join(dirs['mr_linac'],'contours','sub-'+subject,'ses-'+session)
        if not isdir(out_dir):
            os.makedirs(out_dir)

        # get CT and contour filenames
        [ct_fname,contour_fnames] = get_ct_fnames(dirs,subject)

        # co-register CT and T1w and propagate contours
        flirt_propagate(ct_fname,ref_fname,contour_fnames,suffix,out_dir,overwrite=False,resample=2,inverse=True)

def get_ct_fnames(dirs,subject):
    '''Returns the filename of the CT scan and contours
    Parameters
        dirs: directories dictionary
        subject: subject name
    '''

    # get CT filename
    if subject == 'M174' or subject == 'M178':
        ct_dir = join(dirs['proj'],'data','propagate_contours_M174_M178')
    else:
        ct_dir = join(dirs['proj'],'data','mrl_contours')
    ct_fname = join(ct_dir,subject,'REFERENCE.nii.gz')

    # read GTV and CTV name
    df = get_roi_name_df(dirs)
    loc = df['ID']==subject
    gtv_name = df['GTV'][loc].iloc[0]
    ctv_name = df['CTV'][loc].iloc[0]
    
    # declare contour filenames
    gtv_fname = join(ct_dir,subject,gtv_name + '.nii.gz')
    ctv_fname = join(ct_dir,subject,ctv_name + '.nii.gz')
    contour_fnames = [gtv_fname,ctv_fname]

    return ct_fname, contour_fnames

def get_roi_name_df(dirs):
    '''Returns the dataframe of the ROI name table
    Parameters
        dirs: directories dictionary
    '''

    fname = join(dirs['proj'],'data','roi_names.csv') 
    df = pd.read_csv(fname)
    return df

     
