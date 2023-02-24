# imports
import numpy as np
import pandas as pd
from utils.preproc.project_parameters import get_bids_layout
from utils.preproc.align_volumes import get_sessions
from utils.preproc.io import func_msg
from os.path import join, isfile, isdir
import json
import datetime

def make_session_day_table(dirs,subjects):
    '''Creates a table showing the correspondence between session and day of radiotherapy for each subject
    Parameters:
        dirs: directories
        subjects: subject list
    '''

    # communciate with user
    func = 'make_session_day_table'
    func_msg(func,'start')

    # get dataframe of treatment start date
    #fn_tracker = join(dirs['proj'],'data','momentum_tracker_full.xlsx')
    fn_tracker = join(dirs['proj'],'data','MOMENTUM_study_tracker_20220518.xlsx')
    df_tracker = pd.read_excel(fn_tracker,usecols="B,Z",header=3) # usecol: B=Study ID, Z=Tx start date
    
    # loop scanners
    scanners = ['mrl','sim']
    for scanner in scanners:

        # declare filename
        fn_table = join(dirs['proj'],'results','metadata','session_day_'+scanner+'.csv')
        if isfile(fn_table):
            print('Session-day table already exists: ' + fn_table)
        else:

            # get layout
            layout = get_bids_layout(scanner)

            # loop subjects
            rows = []
            rows_debug = []
            for subject in subjects:

                print('Processing: ' + subject)

                # find sessions
                sessions = get_sessions(layout,subject)

                # loop sessions
                for session in sessions:

                    # find date
                    date = session_to_date(layout,subject,session)

                    # convert date to day
                    day, start_date = date_2_day(df_tracker,subject,date)

                    # store date
                    if start_date:
                        rows.append([subject,session,start_date,date,day])

                    else:
                        rows_debug.append([subject])

            # write table to csv
            df_table = pd.DataFrame(rows,columns=['Subject','Session','TxStartDate','Date','TxDay'])
            df_table.to_csv(fn_table,index=False)
            print('Session-day table written: ' + fn_table)

            # write table of failure cases to csv
            df_debug = pd.DataFrame(rows_debug,columns=['Subject'])
            df_debug.to_csv(join(dirs['proj'],'results','metadata','debug_'+scanner+'.csv'),index=False)

    func_msg(func,'end')

def session_to_date(layout,subject,session):
    '''Returns the date of the session for a given subject
    Parameters:
        layout: bids layout
        subject: subject name
        session: session name
    '''
    fn_json = layout.get(subject=subject,session=session,suffix='T1w',extension='json',return_type='filename')[0]
#    if subject == 'M082' and session == 'MRL006':
#        import pdb; pdb.set_trace()
    with open(fn_json) as f:
        js = json.load(f)
    adt = js['AcquisitionDateTime']
    date = adt.split('T')[0].replace('-','')
    return date

def date_2_day(df_tracker,subject,date):
    '''Returns the start date and  treatment day for a given subject and date
    Parameters:
        df_tracker: pandas dataframe from momentum tracker
        subject: subject name
        date: date
    '''
    is_subject = df_tracker['Study ID']==subject
    if subject == 'M007':
        date_start = datetime.datetime(2019,9,25) # from fraction schedule spreadsheet; start date not listed in momentum tracker
    else:
        date_start = df_tracker[is_subject].iloc[0]['TX START DATE']
    date_now = datetime.date(int(date[0:4]),int(date[4:6]),int(date[6:8]))
    tdelta = date_now - date_start.date()
    day = tdelta.days
    start_date = str(date_start.year) + str(date_start.month) + str(date_start.day)

    return day, start_date
