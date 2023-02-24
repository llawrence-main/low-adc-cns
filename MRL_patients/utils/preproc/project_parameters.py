# These functions declare project parameters (directories, etc.)

# imports
from bids import BIDSLayout
import pandas as pd
import os
from os.path import join, basename, dirname, isfile
import json

# functions
def declare_directories():
    ''' Declare the directories for this project '''
    dirs = {}
    dirs['proj'] = '/home/llawrence/Documents/repositories/dwi_response'
#    dirs['proj'] = '/home/llawrence/Documents/dwi_response'
    dirs['mr_sim'] = os.path.join(dirs['proj'],'results','mr_sim')
    dirs['mr_linac'] = os.path.join(dirs['proj'],'results','mr_linac')
    dirs['bids'] = os.path.join(dirs['proj'],'data','bids-cns-mrl')
    dirs['mt'] = os.path.join(dirs['proj'],'data','mrl_mt')
    dirs['contours'] = os.path.join(dirs['proj'],'data','mrl_contours')
    dirs['glio_t1c'] = os.path.join(dirs['proj'],'data','glio_t1c_contours')
    return dirs

def declare_protocol_names():
    ''' Declare the protocol names of scans '''
    names = {}
    names['mrl_dwi'] = ['DWI prebeam 4min40s 11b maxb800']
    return names

def get_bids_layout(scanner):
    ''' Return BIDS layout object
    Parameters:
        scanner: name of scanner (either 'mrl' or 'sim')
    ''' 
    # check params
    assert any([scanner==x for x in ['mrl','sim']]), 'scanner must be one of {mrl,sim}'

    # get BIDS layout
    dirs = declare_directories()
    layout = BIDSLayout(os.path.join(dirs['proj'],'data','bids-cns-mrl','dataset-'+scanner),database_path=os.path.join(dirs['proj'],'data','bids_layout',scanner))
    return layout

def declare_subject_reference_dict():
    '''Returns a dictionary containing the date of the reference session for each subject with CEST/MT scans
    Parameters:
        none
    '''
    reference_dict = {}

    # get list of CEST scan names
    scan_list = get_cest_scan_list()

    # get list of GBM patients that Pejman contoured
    gbm_list = get_gbm_list()

    # pull subject name and date from CEST scan names, subset to GBM patients
    for scan in scan_list:
        bits = scan.split('_')
        subject = bits[2]
        is_gbm = subject in gbm_list
        if is_gbm and (subject not in reference_dict):
            date = bits[3]
            reference_dict[subject] = date

    # get list of MT scans
    scan_list = get_mt_scan_list()

    # get list of high-grade glioma patients
    hgg_list = declare_subjects_by_grade(['IV'])

    # pull subject name and date from MT scan names, subset to HGG patients, add if subject is not already present
    for scan in scan_list:
        bits = scan.split('_')
        subject = bits[4]
        is_hgg = subject in hgg_list
        if is_hgg and (subject not in reference_dict):
            date = bits[5]
            reference_dict[subject] = date

    return reference_dict

def declare_subject_list():
    '''Returns a list of subjects with high-grade gliomas and with DWI scans
    Parameters
        none
    '''
    
    # use subjects from reference session list, if it exists
    dirs = declare_directories()
    fname_ref = join(dirs['proj'],'data','subject_list_dwi_response.xlsx')
    df = pd.read_excel(fname_ref)
    subject_list = df['ID'].to_list()


        # get list of subjects for paper

#        # search for all HGG subjects with DWI
#
#        # get grade IV glioma subjects
#        subjects = declare_subjects_by_grade('IV')
#        #subjects = declare_hgg_subjects()
#
#        # search subjects for those with DWI
#        ly = get_bids_layout('mrl')
#        subject_list = []
#        for subject in subjects:
#            if 'dwi' in ly.get(subject=subject,target='suffix',return_type='id'):
#                subject_list.append(subject)

    return subject_list
        

def declare_subjects_by_grade(grades):
    '''Returns a list of subjects with gliomas of (a) given grade(s)
    Parameters:
        grades (list): list of grades to match
    '''

    dirs = declare_directories()

    # read MOMENTUM spreadsheet
    df = get_momentum_tracker(dirs['proj'])

    # subset to high-grade gliomas
    loc_gr = df['Grade'].isin(grades)
    df_gr = df[loc_gr]

    # convert to list
    subjects = df_gr['Study ID'].tolist()

#    # omit subjects that do not have contours
#    subjects_with_contours = os.listdir(dirs['contours'])
#    subjects = [x for x in subjects if x in subjects_with_contours]

    return subjects

def get_momentum_tracker(proj):
    '''Returns the MOMENTUM tracker spreadsheet as a Pandas dataframe
    Parameters
        proj: project directory
    '''

    fn = join(proj,'data','momentum_tracker_full.xlsx')
    df = pd.read_excel(fn,header=2)
    return df 

def get_cest_scan_list():
    '''Returns a list of CEST scan names in the form MRL_BRAIN_M***_YYYYmmdd_nomoco
    Parameters:
        none
    '''
    dirs = declare_directories()
    fname = join(dirs['proj'],'data','patient_info','cest_fitted_scan_list.txt')
    with open(fname) as f:
        scan_list = f.readlines()
        scan_list = [line.strip() for line in scan_list]
    return scan_list

def get_mt_scan_list():
    '''Returns a list of MT scsan names in the form OUT_pixelwise_MRL_BRAIN_M***_YYYYmmdd.mat
    Parameters
        none
    '''
    dirs = declare_directories()
    fname = join(dirs['proj'],'data','patient_info','mt_fitted_list.txt')
    with open(fname) as f:
        scan_list = f.readlines()
        scan_list = [line.strip().strip('.mat') for line in scan_list]
    return scan_list

def get_gbm_list():
    '''Returns a list of the names of the GBM subjects that Pejman contoured
    Parameters:
        none
    '''

    # declare path to directory
    dirs = declare_directories()
    folder = join(dirs['proj'],'data','rchan_pjm_necrosis','20210503_forPejmanContouring','nii_for_contouring')
    flist = os.listdir(folder)
    gbm_list = [x for x in flist if 'M' in x]
    return gbm_list

def date_to_session(layout,subject,date):
    '''Returns the BIDS session associated with a given date
    Parameters:
        layout: BIDS layout object
        subject: subject name
        date: date
    '''
    fnames = layout.get(subject=subject,suffix='T1w',extension='json',return_type='filename')
    session = ''
    for fname in fnames:
        with open(fname) as f:
            data = json.load(f)
        bits = data['AcquisitionDateTime'].split('T')
        json_date = bits[0].replace('-','')
        if date == json_date:
            session = basename(dirname(dirname(fname))).replace('ses-','')
            break
    return session

def session_to_date(layout,subject,session):
    '''Returns the date associated with a BIDS session
    Parameters:
        layout: BIDS layout object
        subject: subject name
        session: session name
    '''
    fnames = layout.get(subject=subject,session=session,suffix='T1w',extension='json',return_type='filename')
    assert len(fnames)>0, 'no T1w .json file found: %s %s'%(subject,session)
    with open(fnames[0]) as f:
        data = json.load(f)
    bits = data['AcquisitionDateTime'].split('T')
    json_date = bits[0].replace('-','')
    return json_date

def get_reference_list():
    '''Returns the list of reference volumes per subject
    Parameters
        none
    '''

    dirs = declare_directories()
    fn = join(dirs['proj'],'results','subject_reference_list.csv')
    df = pd.read_csv(fn)
    return df

def get_t1w_reference(subject):
    ''' returns the filename of the T1w reference for a given subject
    params
        subject (str): subject name
    '''

    dirs = declare_directories()
    
    # get list of reference volumes
    df = get_reference_list()

    # Get subject and reference volume name
    name_ref = df['ReferenceVolume'][df['Subject']==subject].iloc[0]

    # get session from reference volume name
    session = name_ref.split('_')[1].replace('ses-','')

    # Declare path to reference T1w volume
    fname_ref = os.path.join(dirs['bids'],'dataset-mrl','sub-'+subject,'ses-'+session,'anat',name_ref + '.nii.gz')

    return fname_ref

if __name__ == '__main__':

    # test declare_subject_reference_dict
    print('testing: declare_subject_reference_dict')
    d = declare_subject_reference_dict()
    print(d)

    # test date_to_session
    print('testing: date_to_session')
    subject = 'M001'
    date = '20190719'
    print('subject: %s, date: %s'%(subject,date))
    layout = get_bids_layout('mrl')
    session = date_to_session(layout,subject,date)
    print(session)

    print('testing: session_to_date')
    session = 'MRL003'
    print('subject: %s, session: %s'%(subject,session))
    date = session_to_date(layout,subject,session)
    print(date)

    # test get_momentum_tracker
    print('testing: get_momentum_tracker')
    dirs = declare_directories()
    df = get_momentum_tracker(dirs['proj'])
    print(df)

    # test declare_hgg_subjects
    print('testing: declare_hgg_subjects')
    subjects = declare_hgg_subjects()
    print(subjects)

    # test declare_subject_list
    print('testing: declare_subject_list')
    subjects = declare_subject_list()
    print(subjects)

    # test get_reference_list
    print('testing: get_reference_list')
    df = get_reference_list()
    print(df)

