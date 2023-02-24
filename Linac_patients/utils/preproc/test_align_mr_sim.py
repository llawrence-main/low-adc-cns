# script to test align_mr_sim and associated functions

# imports
from project_parameters import get_bids_layout, declare_directories
from align_mr_sim import get_sessions, get_reference_fname, get_source_fnames

# parameters
dirs = declare_directories()

# import bids layout
layout_sim = get_bids_layout('sim')
layout_mrl = get_bids_layout('mrl')

# get sessions
subject = 'M009'
sessions = get_sessions(layout_sim,subject)
print(subject)
print(sessions)

# get reference filename
ref_fname = get_reference_fname(dirs,layout_mrl,subject)
print(ref_fname)

# get source filenames
for session in sessions:
    src_fnames = get_source_fnames(dirs,layout_sim,subject,session)
    print(session)
    print(src_fnames)
