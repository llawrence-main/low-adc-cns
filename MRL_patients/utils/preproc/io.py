# input-output functions

import re
import os

def select_filenames(method,root,regexp):
    '''Returns a list of filenames matching a regular expression from a given directory
    params
        method (str): method for constructing filenames
        root (str): root directory 
        regexp (object): regular expression object from re.compile
    returns
        fnames (list): list of filenames
    '''

    assert method in ['List','FPList'], 'method is invalid'

    fnames = []
    fnames_search = [x for x in os.listdir(root) if os.path.isfile(os.path.join(root,x))]
    for fname in fnames_search:
        if regexp.search(fname):
            fnames.append(fname)

    if method == 'FPList':
        fnames = [os.path.join(root,x) for x in fnames]

    return fnames

def func_msg(name,opt):
    '''Prints the function name to the command line within a template for the message
    Parameters:
        name: function name
        opt: option that selects message template 
    '''

    # declare parameters of string
    n_hash = 10
    sur = '#'*n_hash
    bridge = '  '
    if opt == 'start':
        dec = 'Starting procedure'
    elif opt == 'end':
        dec = 'Finished procedure'
    else:
        raise ValueError('opt must be one of [start,end]')
    
    # create string
    s = sur + bridge + '%s: %s'%(dec,name) + bridge + sur

    # print string
    print(s)
