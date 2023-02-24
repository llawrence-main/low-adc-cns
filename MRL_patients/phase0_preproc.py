#!/usr/bin/env python3

# This script does pre-processing (co-registration and segmentation) for dwi_response

# imports
#from utils.preproc.project_parameters import declare_directories, get_bids_layout, declare_subject_reference_dict, declare_subject_list
#from utils.preproc.align_volumes import align_volumes
#from utils.preproc.session_day_table import make_session_day_table
#from utils.preproc.propagate_contours import propagate_contours
#from utils.preproc.extract_brain import extract_brain
#from utils.nvidia_aiaa.create_aiaa_seg import create_aiaa_seg
import argparse

parser = argparse.ArgumentParser()

parser.add_argument('--subjects',dest='subjects_arg',nargs='+',help='if nonempty, runs code on specified subjects only (default = [])')
parser.set_defaults(subjects_arg=[])

parser.add_argument('--start-from',dest='start_from',help='if nonempty, starts processing from given subject (default = "")')
parser.set_defaults(start_from='')

parser.add_argument('--align',dest='do_align',action='store_true',default=False,help='align volumes (default = False)')
parser.add_argument('--refnames',dest='ref_names_only',action='store_true',default=False,help='if running align_volumes, generate table of reference names only? (default = False)')
parser.add_argument('--align-sim',dest='align_sim',action='store_true',default=False,help='align MR-sim volumes (default = False)')
parser.add_argument('--align-mrl',dest='align_mrl',action='store_true',default=False,help='align MR-Linac volumes (default = False)')

parser.add_argument('--session-table',dest='do_session_day',action='store_true',default=False,help='create table of session-day correspondence (default = False)')

parser.add_argument('--prop-contours',dest='do_propagate_contours',action='store_true',default=False,help='propagate contours (default = False)')
parser.add_argument('--contour-source',dest='contour_source',help='source of contours to propagate ("ct" or "glio_t1c"; default = "ct")')
parser.set_defaults(contour_source='ct')

parser.add_argument('--do-bet',dest='do_extract_brain',action='store_true',default=False,help='extract brain with HD-BET (default = False)')

parser.add_argument('--run-aiaa',dest='run_aiaa',action='store_true',default=False,help='Run NVIDIA AIAA to create tumour segmentation (default = False)')
parser.add_argument('--num-outputs',dest='num_outputs',help='number of outputs for AIAA segmentation (1 or 3)',default=3,type=int)

parser.add_argument('--mrl-flair',dest='mrl_flair',action='store_true',default=False,help='align MR-Linac FLAIR volumes (default = False)')

args = parser.parse_args()

subjects_arg = args.subjects_arg
start_from = args.start_from

do_align = args.do_align
ref_names_only = args.ref_names_only

do_propagate_contours = args.do_propagate_contours
contour_source = args.contour_source

do_extract_brain = args.do_extract_brain

align_sim = args.align_sim
align_mrl = args.align_mrl

do_session_day = args.do_session_day 

do_propagate_contours = args.do_propagate_contours 

do_extract_brain = args.do_extract_brain

run_aiaa = args.run_aiaa
num_outputs = args.num_outputs

mrl_flair = args.mrl_flair

### do imports after argument parser to speed up printing of help info
from utils.preproc.project_parameters import declare_directories, get_bids_layout, declare_subject_reference_dict, declare_subject_list
from utils.preproc.align_volumes import align_volumes
from utils.preproc.session_day_table import make_session_day_table
from utils.preproc.propagate_contours import propagate_contours, propagate_contours_glio
from utils.preproc.extract_brain import extract_brain
from utils.nvidia_aiaa.create_aiaa_seg import create_aiaa_seg
from os.path import isfile
from pandas import read_csv
###

# declare parameters
dirs = declare_directories()
if subjects_arg:
    try:
        if isfile(subjects_arg[0]):
            subjects = read_csv(subjects_arg[0])['Subject'].to_list()
        else:
            subjects = subjects_arg
    except:
        raise ValueError('subjects must be a list of subjects or a .csv filename')
else:
    subjects = declare_subject_list()
    subjects_rm = ['M183'] # only DWI is a single session with Elekta protocol
    for subject in subjects_rm:
        if subject in subjects:
            subjects.remove(subject)
if start_from:
    subjects = subjects[subjects.index(start_from):]

if do_align:
    # align MR-sim scans to space in which Pejman's necrosis ROI was defined
    align_volumes(dirs,subjects,ref_names_only=ref_names_only,align_sim=align_sim,align_mrl=align_mrl,mrl_flair=mrl_flair)

if do_session_day:
    # create table of session-treatment day correspondence
    make_session_day_table(dirs,subjects)

if do_propagate_contours:

    if contour_source == 'ct':
        # register CT to T1w of reference session and propagate contours (GTV, CTV)
        propagate_contours(dirs,subjects)

    elif contour_source == 'glio_t1c': 
        # register GLIO T1w to T1w of reference session and propagate contours (GTV, CTV)
        propagate_contours_glio(dirs,subjects)

if do_extract_brain:
    # call HD-BET to extract brain
    extract_brain(dirs,subjects)

if run_aiaa:
    # call NVIDIA AIAA to create tumour segmentation from MR-sim scans
    create_aiaa_seg(dirs,subjects,num_outputs=num_outputs)
