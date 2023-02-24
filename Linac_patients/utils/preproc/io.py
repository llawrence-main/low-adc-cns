# input-output functions

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
