#!/usr/bin/env python3

# This script does pre-processing (co-registration and segmentation) for dwi_response

# imports
from utils.preproc.project_parameters import declare_directories, get_bids_layout, declare_subject_list
from utils.preproc.align_volumes import align_volumes
from utils.preproc.extract_brain import extract_brain
from utils.preproc.propagate_contours import propagate_contours
from bids import BIDSLayout
import os
import argparse


parser = argparse.ArgumentParser()

parser.add_argument('--test-one',dest='test_one',help='if nonempty, runs code on specified subject only (default = "")')
parser.set_defaults(test_one='')

parser.add_argument('--start-from',dest='start_from',help='if nonempty, starts processing from given subject (default = "")')
parser.set_defaults(start_from='')

parser.add_argument('--align',dest='do_align',action='store_true',default=False,help='align volumes (default = False)')
parser.add_argument('--refnames',dest='ref_names_only',action='store_true',default=False,help='if running align_volumes, generate table of reference names only? (default = False)')

parser.add_argument('--prop-contours',dest='do_propagate_contours',action='store_true',default=False,help='propagate contours (default = False)')
parser.add_argument('--contour-source',dest='contour_source',help='source of contours to propagate (default = "manual")')
parser.set_defaults(contour_source='manual')

parser.add_argument('--do-bet',dest='do_extract_brain',action='store_true',default=False,help='extract brain with HD-BET (default = False)')

args = parser.parse_args()
test_one = args.test_one
start_from = args.start_from

do_align = args.do_align
ref_names_only = args.ref_names_only

do_propagate_contours = args.do_propagate_contours
contour_source = args.contour_source

do_extract_brain = args.do_extract_brain


## declare script options
##test_one = True # test one subject?
##start_from = 'GBM046'
#start_from = ''
#
## align volumes
#do_align = False # call align_volumes?
#ref_names_only = False # only generate table of reference volumes?
#
## propagate contours
#do_propagate_contours = True # call propagate_contours?
#contour_source = 'aiaa'
#
## extract brain
#do_extract_brain = False # call extract_brain?
#
# declare parameters
dirs = declare_directories()
if test_one:
    subjects = [test_one]
else:
    subjects = declare_subject_list()
    subjects_rm = []
    for subject in subjects_rm:
        if subject in subjects:
            subjects.remove(subject)
if start_from:
    subjects = subjects[subjects.index(start_from):]

if do_align:
    # align scans for each subject
    align_volumes(dirs,subjects,ref_names_only=ref_names_only)

if do_propagate_contours:
    # propagate contours to reference session for each subject
    propagate_contours(dirs,subjects,source=contour_source)

if do_extract_brain:
    # call HD-BET to extract brain
    extract_brain(dirs,subjects)
