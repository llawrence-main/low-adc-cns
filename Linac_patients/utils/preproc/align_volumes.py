# imports
from utils.preproc.project_parameters import get_bids_layout, declare_directories
from utils.preproc.flirt_utils import flirt_volumes
from utils.preproc.io import func_msg
from os.path import join, isdir, basename, isfile
import os
import pandas as pd
from pathlib import Path
import json

def align_volumes(dirs,subjects,ref_names_only=False):
    '''Aligns scans for each patient over sessions
    Parameters:
        dirs: dictionary of directories
        subjects: list of subjects
        ref_names_only: if True, will only grab reference names and write to .csv file
    '''

    # communicate with user
    func = 'align_volumes'
    func_msg(func,'start')
    print('Collect reference names only = ' + str(ref_names_only))

    # declare parameters
    suffix = 'coreg'
    layout_sim = get_bids_layout()

    # declare list to hold reference name
    rows = []

    # loop subjects
    for subject in subjects:

        print('Processing: ' + subject)

        # get MR-sim sessions
        sessions_sim = get_sessions(layout_sim,subject)

        # get reference filename
        ref_fname = get_reference_fname(dirs,layout_sim,subject)

        # append to rows
        ref_name = basename(ref_fname).replace('.nii.gz','')
        rows.append([subject,ref_name])

        # get reference session
        ref_session = ref_name.split('_')[1].replace('ses-','')

        if not ref_names_only:

            # loop MR-sim sessions
            for session in sessions_sim:

                    # create output directory
                    out_parent = join(dirs['bids'],'derivatives','coreg','sub-'+subject,'ses-'+session)
                    if not isdir(out_parent):
                       os.makedirs(out_parent)

                    # get source filenames, including T1w and DWI
                    fname_dict = get_source_fnames(dirs,layout_sim,subject,session)
                    src_fnames = [fname_dict[key] for key in fname_dict if not (key=='dwi')]
                    if 'dwi' in fname_dict:
                        src_fnames = src_fnames + fname_dict['dwi']

                    if session == ref_session:
                        out_dir = join(out_parent,'anat')
                        if not isdir(out_dir):
                            os.mkdir(out_dir)
                        # symlink to reference volume and remove from list of volumes to register
                        ref_bits = ref_name.split('_')
                        ref_bits.insert(len(ref_bits)-1,'desc-coreg')
                        tgt_fname = os.path.join(out_dir,'_'.join(ref_bits)+'.nii.gz')
                        if not isfile(tgt_fname):
                            os.symlink(ref_fname,tgt_fname)
                        src_fnames.remove(ref_fname)

                        create_coreg_json(tgt_fname,ref_fname)

                        # rename volume and create .json sidecar
#                        proc_coreg_for_bids(ref_fname,ref_fname,tgt_fname)

                    for src_fname in src_fnames:
                        # get datatype and create output directory
                        datatype = Path(src_fname).parts[-2]
                        out_dir = join(out_parent,datatype)
                        if not isdir(out_dir):
                            os.mkdir(out_dir)

                        # register source volumes to reference volume one at a time
                        coreg_fname = flirt_volumes(src_fname,ref_fname,[],suffix,out_dir,other_qform=True,overwrite=False,resample=2)

                        create_coreg_json(coreg_fname,ref_fname)

                        # rename co-registered volumes and create sidecar .json file, for BIDS convention
                        #kproc_coreg_for_bids(src_fname,ref_fname,reg_fname)


        
    # write list of reference names
    filename = join(dirs['proj'],'interim','subject_reference_list.csv')
    if isfile(filename):
        print('List of reference volumes already exists: ' + filename)
    else:
        df = pd.DataFrame(rows,columns=['Subject','ReferenceVolume'])
        df.to_csv(filename,index=False)
        print('List of reference volumes written: ' + filename)
    func_msg(func,'end')

def get_sessions(layout,subject):
    '''Returns a list of sessions for a given subject
    Parameters:
        layout: BIDS layout
        subject: subject
    '''

    sessions = layout.get(return_type='id',subject=subject,target='session')
    sessions.sort()
    return sessions

def get_reference_fname(dirs,layout,subject):
    '''Returns the filename of the reference T1w in the space where Pejman defined the necrosis ROIs
    Parameters
        dirs: dictionary of directories
        layout: BIDS layout
        subject: subject
    '''

    # search for T1w filename in reference session
    session = 'GLIO01'
    fnames = get_source_fnames(dirs,layout,subject,session)
    key_list = ['t1w_pre','t1w_post']
    for key in key_list:
        if key in fnames:
            ref_fname = fnames[key]
            break
    return ref_fname

def get_source_fnames(dirs,layout,subject,session):
    '''Returns list of source names to register to reference for given subject and session
    Parameters
        dirs: dictionary of directories
        layout: BIDS layout
        subject: subject name
        session: session name
    '''
    
    if subject == 'GBM024' and session == 'GLIO01': # special case
        parent = os.path.join(dirs['bids'],'sub-'+subject,'ses-'+session,'anat')
        pre = [os.path.join(parent,'sub-GBM024_ses-GLIO01_acq-fs_T1w.nii.gz')]
        post = [os.path.join(parent,'sub-GBM024_ses-GLIO01_acq-fs_ce-gd_run-02_T1w.nii.gz')]
    else:
        # get pre- and post-Gd T1w filenames; search for fatsat first, then inphase if one of the fatsat scans does not exist
        acqs = ['fs','ip']
        for acq in acqs:
            fnames = layout.get(subject=subject,session=session,suffix='T1w',extension='.nii.gz',acquisition=acq,return_type='filename')
            pre = [x for x in fnames if ('ce-gd' not in x)]
            post = [x for x in fnames if ('ce-gd' in x)]
            if pre and post:
                break

    # get DWI filenames and append to list of filenames
    dwi = layout.get(subject=subject,session=session,suffix='dwi',extension='nii.gz',return_type='filename')
    
    fnames = {}
    if pre:
        fnames['t1w_pre'] = pre[-1]
    if post:
        fnames['t1w_post'] = post[-1]
    if dwi:
        fnames['dwi'] = dwi

    return fnames

def proc_coreg_for_bids(src_fname,ref_fname,reg_fname):
    """Rename co-registered volume and create .json sidecar, for BIDS convention
    Args:
        src_fname (str): source filename (BIDS)
        ref_fname (str): reference filename (BIDS)
        reg_fname (str): filename of source registered to reference
    """

    # declare target filename
    src_entities = Path(src_fname).name.split('_')
    src_entities.insert(len(src_entities)-1,'desc-coreg')
    tgt_name = '_'.join(src_entities)
    tgt_dir = Path(reg_fname).parent
    tgt_fname = join(tgt_dir,tgt_name)

    # move registered volume to target filename
    os.rename(reg_fname,tgt_fname)

    # move .mat file to target .mat, if it exists
    reg_mat_fname = reg_fname.replace('.nii.gz','.mat')
    tgt_mat_fname = tgt_fname.replace('.nii.gz','.mat')
    if isfile(reg_mat_fname):
        os.rename(reg_mat_fname,tgt_mat_fname)

    # create .json sidecar to declare SpatialReference
    dataset_dir = str(Path(ref_fname).parents[3])
    ref_relative = ref_fname.replace(dataset_dir+'/','')
    data = {}
    data['SpatialReference'] = ref_relative
    json_fname = tgt_fname.replace('.nii.gz','.json')
    with open(json_fname,'w') as f:
        json.dump(data,f)

def create_coreg_json(coreg_fname,ref_fname):
    """Create the .json sidecar indicating the spatial reference
    Args:
        coreg_fname (str): filename of co-registered volume
        ref_fname (str): filename of reference volume
    """

    # create .json sidecar to declare SpatialReference
    dataset_dir = str(Path(ref_fname).parents[3])
    ref_relative = ref_fname.replace(dataset_dir+'/','')
    data = {}
    data['SpatialReference'] = ref_relative
    json_fname = coreg_fname.replace('.nii.gz','.json')
    with open(json_fname,'w') as f:
        json.dump(data,f)



if __name__ == '__main__':

    # get directories and layout
    dirs = declare_directories()
    layout = get_bids_layout()

    # get source and reference filenames
    subject = 'GBM021'
    session = 'GLIO01'
    fnames = get_source_fnames(dirs,layout,subject,session)
    ref_fname = get_reference_fname(dirs,layout,subject)

    # process registered volume for BIDS derivatives
    subject = 'GBM021'
    session = 'GLIO02'
    ref_session = 'GLIO01'
    sub_dir = join('/laudata','llawrence','bids-mrsim-glio','sub-'+subject)
    src_fname = join(sub_dir,'ses-'+session,'anat','sub-%s_ses-%s_T1w.nii.gz'%(subject,session))
    ref_fname = join(sub_dir,'ses-'+ref_session,'anat','sub-%s_ses-%s_T1w.nii.gz'%(subject,ref_session))
    work_dir = join('..','interim','test','coreg')
    reg_fname = join(work_dir,'sub-'+subject,'ses-'+session,'anat','sub-%s_ses-%s_T1w_coreg.nii.gz'%(subject,session))
    proc_coreg_for_bids(src_fname,ref_fname,reg_fname)
