# imports
from utils.preproc.project_parameters import get_bids_layout, declare_subject_reference_dict, date_to_session, declare_protocol_names, session_to_date
from utils.preproc.flirt_utils import flirt_volumes
from utils.preproc.io import func_msg
from os.path import join, isdir, basename, isfile
import os
import pandas as pd
import nibabel as nib

def align_volumes(dirs,subjects,ref_names_only=False,align_sim=True,align_mrl=True,mrl_flair=False):
    '''Aligns MR-sim and MR-Linac scans to space of Pejman's necrosis ROIs
    Parameters:
        dirs: dictionary of directories
        subjects: list of subjects
        ref_names_only: if True, will only grab reference names and write to .csv file
        align_sim: if True, will align MR-sim volumes
        align_mrl: if True, will align MR-Linac volumes
        mrl_flair: if True, will align MR-Linac FLAIR volumes
    '''

    # communicate with user
    func = 'align_volumes'
    func_msg(func,'start')
    print('Collect reference names only = ' + str(ref_names_only))

    # declare parameters
    suffix = 'coreg'
    layout_sim = get_bids_layout('sim')
    layout_mrl = get_bids_layout('mrl')

    # declare list to hold reference name
    rows = []

    # loop subjects
    for subject in subjects:

        print('Processing: ' + subject)

        # get MR-sim sessions
        sessions_sim = get_sessions(layout_sim,subject)

        # get reference filename
        ref_fname = get_reference_fname(dirs,layout_mrl,subject)

        # append to rows
        ref_name = basename(ref_fname).replace('.nii.gz','')
        rows.append([subject,ref_name])

        # get reference session
        ref_session = ref_name.split('_')[1].replace('ses-','')

        if not ref_names_only:

            if align_sim:
                # loop MR-sim sessions
                for session in sessions_sim:

                    # create output directory
                    out_dir = join(dirs['mr_sim'],'coreg','sub-'+subject,'ses-'+session)
                    if not isdir(out_dir):
                       os.makedirs(out_dir)

                    # get source filenames, including T1w and DWI, and FLAIR
                    src_fnames = get_source_fnames(dirs,'sim',layout_sim,subject,session)

                    # register source volumes to reference volume one at a time
                    for src_fname in src_fnames:
                        flirt_volumes(src_fname,ref_fname,[],suffix,out_dir,other_qform=True,overwrite=False,resample=2)


            if align_mrl:

                # get MRL sessions
                sessions_mrl = get_sessions(layout_mrl,subject)

                # loop MR-Linac sessions
                for session in sessions_mrl:

                    # get filename of M0b map from quantitative magnetization transfer
                    m0b_fname = get_m0b_fname(dirs,layout_mrl,subject,session)
                    
                    # force get_source_filenames to return MRL T1w filename
                    if m0b_fname or mrl_flair: force_t1w = True
                    else: force_t1w = False

                    # get source filenames
                    fnames = get_source_fnames(dirs,'mrl',layout_mrl,subject,session,force_t1w=force_t1w,mrl_flair=mrl_flair)

                    if fnames:

                        # create output directory
                        out_dir = join(dirs['mr_linac'],'coreg','sub-'+subject,'ses-'+session)
                        if not isdir(out_dir):
                            os.makedirs(out_dir)
                        
                        if session == ref_session:
                            # create symbolic links if current session is reference session
                            for fname in fnames:
                                dst = join(out_dir,basename(fname).replace('.nii.gz','_coreg.nii.gz'))
                                if isfile(dst):
                                    print('Symlink already exists: ' + dst)
                                else:
                                    os.symlink(fname,dst)
                                    print('Created symlink: ' + dst)
                        else:

                            # get T1w filename as source
                            src_fname = fnames[0]
                            other_fnames = fnames[1:] # other volumes

                            # declare path to M0b
                            dst_dir = join(dirs['mr_linac'],'qmt','sub-'+subject,'ses-'+session)
                            m0b_fname_dst = join(dst_dir,'sub-%s_ses-%s_m0b.nii.gz'%(subject,session)) 
                            if m0b_fname and not isfile(m0b_fname_dst):
                                print('Appending M0b to list of volumes to co-register: ' + m0b_fname)
                                other_fnames.append(m0b_fname)

                            # register source volume to reference volume and co-register other volumes using same transformation
                            flirt_volumes(src_fname,ref_fname,other_fnames,suffix,out_dir,other_qform=True,overwrite=False,resample=2)

                            # move M0b to separate folder, if it exists
                            if m0b_fname and not isfile(m0b_fname_dst):
                                if not isdir(dst_dir):
                                    os.makedirs(dst_dir)
                                os.rename(join(out_dir,'m0b_'+suffix+'.nii.gz'),m0b_fname_dst)
                                print('M0b volume moved: ' + m0b_fname_dst)

                    else:
                        print('no DWI: %s_%s' %(subject,session))
        
    # write list of reference names
    filename = join(dirs['proj'],'results','subject_reference_list.csv')
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
    ref_dict = declare_subject_reference_dict()
    if subject in ref_dict.keys():
        # if subject is part of qMT cohort
        session = date_to_session(layout,subject,ref_dict[subject])
        if subject in ['M082','M089']: # override to make run-02 the T1w volume (space of Pejman's necrosis ROI for these subjects)
            t1w_fnames = layout.get(subject=subject,session=session,run='02',return_type='filename',suffix='T1w',extension='nii.gz')
        else:
            t1w_fnames = layout.get(subject=subject,session=session,return_type='filename',suffix='T1w',extension='nii.gz')
    else:
        session = 'MRL001'
        t1w_fnames = layout.get(subject=subject,session=session,return_type='filename',suffix='T1w',extension='nii.gz')
    
    # return last run (assumed that multiple runs done if the first few scans were unusable), if any T1w filenames exist
    if len(t1w_fnames)>0:
        ref_fname = t1w_fnames[-1]
    else:
        ref_fname = ''
    return ref_fname

def get_source_fnames(dirs,dataset,layout,subject,session,force_t1w=False,mrl_flair=False):
    '''Returns list of source names to register to reference for given subject and session
    Parameters
        dirs: dictionary of directories
        dataset: dataset (one of 'mrl' or 'sim')
        layout: BIDS layout
        subject: subject name
        session: session name
        force_t1w: If True, will return the MRL T1w even if no DWI exists for session
        mrl_flair: If True, will append MRL FLAIR filename
    '''
    # check inputs
    assert any([x == dataset for x in ['mrl','sim']]), 'dataset must be one of {mrl,sim}'

    if dataset == 'sim':

        # get source filenames for MR-sim

        # get pre- and post-Gd T1w filenames; search for fatsat first, then inphase if one of the fatsat scans does not exist
        acqs = ['fatsat','inphase']
        for acq in acqs:
            fnames = layout.get(subject=subject,session=session,suffix='T1w',extension='nii.gz',acquisition=acq,return_type='filename')
            pre = any(['acq-'+acq+'_T1w' in x for x in fnames])
            post = any(['acq-'+acq+'_ce-GADOLINIUM_T1w' in x for x in fnames])
            if pre and post:
                break

        # get DWI filenames and append to list of filenames
        dwi_filenames = layout.get(subject=subject,session=session,suffix='dwi',extension='nii.gz',return_type='filename')
        fnames = fnames + dwi_filenames

        # get FLAIR filename and append to list of filenames
        flair_filenames = layout.get(subject=subject,session=session,suffix='FLAIR',extension='nii.gz',return_type='filename')
        for test_filename in reversed(flair_filenames): # find greatest run that is not an RGB image
            img = nib.load(test_filename)
            if img.header['datatype'] != 128:
                flair_filename = test_filename
                break

#        if subject == 'M083' and session == 'sim004':
#            flair_filenames = layout.get(subject=subject,session=session,run='01',suffix='FLAIR',extension='nii.gz',return_type='filename')
#        else:
#
        fnames = fnames + [flair_filename] 

    elif dataset == 'mrl':

       # get source filenames for MR-Linac 
       protocols = declare_protocol_names()

       # search for DWI filenames
       dwi_fnames = layout.get(subject=subject,session=session,suffix='dwi',extension='nii.gz',return_type='filename')

       if (len(dwi_fnames)==0) and (not force_t1w):
           fnames = []
       else:

           # get T1w filename
           t1_fnames = layout.get(subject=subject,session=session,suffix='T1w',extension='nii.gz',return_type='filename')
           assert len(t1_fnames)>0, 'no T1w found: %s_%s' %(subject,session)
            
           # get FLAIR filenames
           if mrl_flair:
               flair_fnames = layout.get(subject=subject,session=session,suffix='FLAIR',extension='nii.gz',return_type='filename')

           # create list of filenames
           if subject == 'M125' and session == 'MRL017':
               fnames = [t1_fnames[1]] # select run-02 because run-01 has bad FOV
           else:
               fnames = [t1_fnames[0]]

           if len(dwi_fnames)>0:
               if subject == 'M029' and session == 'MRL009':
                   fnames.append(dwi_fnames[1]) # use run-02 (beam-on) DWI because run-01 (pre-beam) DWI has singular matrix
               else:
                   fnames.append(dwi_fnames[0])

           if len(flair_fnames)>0:
               fnames.append(flair_fnames[0])

    return fnames

def get_m0b_fname(dirs,layout,subject,session):
    '''Returns the filenames of the M0b map for a given subject and session, if it exists
    Parameters
        dirs: directories dictionary
        layout: layout of BIDS directory
        subject: subject name
        session: session
    '''
    
    # convert session to date
    date = session_to_date(layout,subject,session)

    # determine whether qMT was acquired on date
    m0b_fname = join(dirs['mt'],'nii','MRL_BRAIN_%s_%s'%(subject,date),'m0b.nii.gz')
    if not isfile(m0b_fname):
        m0b_fname = ''

    return m0b_fname

