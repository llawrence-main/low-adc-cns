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
    dirs['proj'] = '/home/llawrence/Documents/repositories/mrsim_adc_response'
#    dirs['bids'] = '/home/llawrence/Documents/repositories/bids_mrsim_glio/bids-mrsim-glio'
    dirs['bids'] = os.path.join('/laudata','llawrence','bids-mrsim-glio')
    return dirs

def get_bids_layout(include_derived=False):
    ''' Return BIDS layout object
    Args:
        include_derived: include derivatives in layout?
    ''' 
    # get BIDS layout
    dirs = declare_directories()
    if include_derived:
        layout = BIDSLayout(dirs['bids'],database_path=os.path.join(dirs['bids'],'derivatives','BIDSLayoutWithDerivatives'))
    else:
        layout = BIDSLayout(dirs['bids'],database_path=os.path.join(dirs['bids'],'derivatives','BIDSLayout'))
    return layout

def declare_subject_list():
    '''Returns a list of subjects
    '''
    
    ly = get_bids_layout()
    subject_list = ly.get(return_type='id',target='subject')
    subject_list = sorted(subject_list)

    return subject_list
        

def get_reference_list():
    '''Returns the list of reference volumes per subject
    Parameters
        none
    '''

    dirs = declare_directories()
    fn = join(dirs['proj'],'interim','subject_reference_list.csv')
    df = pd.read_csv(fn)
    return df

if __name__ == '__main__':

    # test get_bids_layout()
    ly = get_bids_layout()

    ## test declare_subject_list
    #print('testing: declare_subject_list')
    #subjects = declare_subject_list()
    #print(subjects)

    ## test get_reference_list
    #print('testing: get_reference_list')
    #df = get_reference_list()
    #print(df)

