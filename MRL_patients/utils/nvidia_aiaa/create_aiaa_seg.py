#!/bin/python

import os
from os.path import join
import sys
from bids import BIDSLayout
from utils.nvidia_aiaa.aiaa_utils import seg_list_for_subject

def create_aiaa_seg(dirs,subjects,num_outputs=3):
    '''Creates AIAA segmentation for listed subjects using MR-sim scans
    args:
        dirs (dict): directories dictionary
        subjects (list): list of subject names
        num_outputs (int): number of segmentation outputs (1 = tumour core, 3 = {tumour core, enhancing tumour, whole tumour})
    '''

    # options
    if num_outputs==3:
        model = 'clara_pt_brain_mri_segmentation_inputs_t1ce_t1_flair'
    elif num_outputs==1:
        model = 'seg_tc_inputs_t1ce_t1_flair_v5'
    server =  'http://spinecho:5000'

    # directories
    data_root = os.path.join(dirs['proj'],'results','mr_sim','coreg')
    if num_outputs==3:
        folder = 'aiaa_seg'
    elif num_outputs==1:
        folder = 'aiaa_seg_tc'
    out_root = os.path.join(dirs['proj'],'results','mr_sim',folder)

    for subject in subjects:
        # get list of SegAI objects
        seg_list = seg_list_for_subject(data_root,subject,out_root,num_outputs=num_outputs)

        for seg in seg_list:
            seg.find_input_filenames()
            session = seg.get_session()
            print('processing: sub-%s_ses-%s'%(subject,session))    
            seg.print_input_filenames()
            try:
                seg.run(model,server)
            except:
                print('could not run preproc or segment')
        

