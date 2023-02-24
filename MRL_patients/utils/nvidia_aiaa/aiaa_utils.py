# utilities for aiaa

import bids
import os
from os.path import isfile, isdir, join
import subprocess

class SegAI(object):
    """
    Class for AIAA segmentation

    Args:
        data_root (str): root of dataset
        subject (str): subject name
        session (str): session name
        out_root (str): root of output directories
        num_outputs (int): number of segmentation outputs (1 = tumour core, 3 = {tumour core, enhancing tumour, whole tumour})
    """

    def __init__(self, data_root, subject, session, out_root, num_outputs=3):
        self.data_root = data_root
        self.subject = subject
        self.session = session
        self.t1ce = ''
        self.t1 = ''
        self.flair = ''
        self.out_root = out_root
        assert (num_outputs==1) or (num_outputs==3), 'num_outputs must be 1 or 3'
        self.num_outputs = num_outputs

    def get_subject(self):
        return self.subject

    def get_session(self):
        return self.session

    def find_input_filenames(self):
        '''finds T1ce, T1, FLAIR filenames'''
        
        t1ce = ''
        t1 = ''
        flair = ''

        # search for T1w-ce and T1w, with preference for fat-sat over in-phase
        search_dir = os.path.join(self.data_root,'sub-'+self.subject,'ses-'+self.session)
        filenames = [x for x in os.listdir(search_dir) if '.nii.gz' in x]

        for filename in filenames:
            if 'T1w' in filename:
                if (not t1ce) and ('ce-GADOLINIUM' in filename):
                    t1ce = filename
                elif (not t1) and ('ce-GADOLINIUM' not in filename):
                    t1 = filename
            elif (not flair) and ('FLAIR' in filename):
                flair = filename

        self.t1ce = os.path.join(search_dir,t1ce)
        self.t1 = os.path.join(search_dir,t1)
        self.flair = os.path.join(search_dir,flair)

    def get_input_filenames(self):
        d = {}
        d['t1ce'] = self.t1ce
        d['t1'] = self.t1
        d['flair'] = self.flair
        return d

    def set_input_filename(self,contrast,filename):
        if contrast == 't1ce':
            self.t1ce = filename
        elif contrast == 't1':
            self.t1 = filename
        elif contrast == 'flair':
            self.flair = filename
        else:
            raise ValueError('contrast is not one of {t1ce,t1,flair}')

    def print_input_filenames(self):
        print('sub-%s_ses-%s input filenames (valid=%s):' %(self.subject,self.session,self.is_valid()))
        d = self.get_input_filenames()
        for label in d.keys():
            print('    %s: %s' %(label,d[label]))

    def is_valid(self):
        d = self.get_input_filenames()
        return all([isfile(d[label]) for label in d.keys()])  

    def get_work(self):
        return join(self.out_root,'sub-'+self.subject,'ses-'+self.session)

    def get_merged_filename(self):
        work = self.get_work()
        merged_filename = join(work,'sub-%s_ses-%s_desc-merged_T1w.nii.gz' %(self.subject,self.session))
        return merged_filename

    def get_mask_filenames(self):
        labels = {}
        if self.num_outputs==3:
            labels['enhancing_tumor'] = 'enhancingtumour'
            labels['tumor_core'] = 'tumourcore'
            labels['whole_tumor'] = 'wholetumour'
        elif self.num_outputs==1:
            labels['tumor'] = 'tumourcore'
        work = self.get_work()
        mask_filenames = []
        for key in labels.keys():
            mask_filenames.append(join(work,'sub-%s_ses-%s_label-%s_mask.nii.gz' %(self.subject,self.session,labels[key])))
        return mask_filenames, labels

    def rename_seg(self):
        mask_filenames, labels = self.get_mask_filenames()
        work = self.get_work()
        for key, dst in zip(labels.keys(),mask_filenames):
            src = join(work,key+'.nii.gz')
            os.rename(src,dst)

    def get_seg_filename(self):
        work = self.get_work()
        seg_filename = join(work,'sub-%s_ses-%s_label-tumour_masks.nii.gz' %(self.subject,self.session))
        return seg_filename
        
    def preproc_done(self):
        merged_filename = self.get_merged_filename()
        return isfile(merged_filename)

    def seg_done(self):
        mask_filenames, labels = self.get_mask_filenames()
        return all([isfile(x) for x in mask_filenames])

    def rename_preproc(self):
        src = join(self.get_work(),'merged.nii.gz')
        dst = self.get_merged_filename()
        os.rename(src,dst)

    def run(self,model,server,overwrite=False):
        '''runs AIAA 
        args:
            model (str): name of CLARA model
            server (str): server URL
            overwrite (bool): overwrite existing files?
        '''

        # check if valid
        if not self.is_valid():
            print('sub-%s_ses-%s is not valid for AIAA segmentation' %(self.subject,self.session))
        else:
            
            # create working directory
            work = self.get_work() 
            if not isdir(work):
                os.makedirs(work)

            # call aiaa-preproc
            if self.preproc_done() and (not overwrite):
                print('sub-%s_ses-%s: aiaa-preproc already run' %(self.subject,self.session))
            else:
                d = self.get_input_filenames()
                inputs = ' '.join([d[x] for x in d.keys()])

                cmd="aiaa-preproc -i %s -od %s -r -vs 1 --bet --merge" %(inputs,work)
                print(cmd)
                subprocess.call(cmd,shell=True)

                self.rename_preproc()

            # call aiaa-segment
            if self.seg_done() and (not overwrite):
                print('sub-%s_ses-%s: aiaa-segment already run' %(self.subject,self.session))
            else:
                out_name = os.path.basename(self.get_seg_filename())
                cmd="aiaa-segment -i %s -m %s -o %s -od %s -s %s" %(self.get_merged_filename(),model,out_name,work,server)
                print(cmd)
                subprocess.call(cmd,shell=True)
                
                self.rename_seg()
                rm_filename = self.get_seg_filename()
                os.remove(rm_filename)        
                    

def seg_list_for_subject(data_root,subject,out_root,num_outputs=3):
    '''returns a list of SegAI objects given a BIDS layout
    args:
        data_root (str): root of dataset
        subject (list): subject name
        num_outputs (int): number of segmentation outputs (1 or 3)
    returns:
        seg_list (list): list of SegAI objects
    '''

    seg_list = [] 

    sessions = get_sessions(data_root,subject) 

    for session in sessions:

        seg = SegAI(data_root,subject,session,out_root,num_outputs=num_outputs)
        seg_list.append(seg)

    return seg_list

def get_sessions(data_root,subject):
    ''' returns list of sessions for subject'''

    search_dir = os.path.join(data_root,'sub-'+subject)
    sessions = [x.replace('ses-','') for x in os.listdir(search_dir)]
    sessions.sort()
    return sessions


    
