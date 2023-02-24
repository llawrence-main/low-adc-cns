'''
This script overlays ROIs onto a base image and saves a lightbox view (multiple axial slices) as an image, using fsleyes.

Call:
python3 render_rois.py -base base_filename -main main_filename -extra extra_filename_1 extra_filename_2 ... -out out_filename

Parameters:
base_filename: base nifti to show ROIs on
main_filename: main ROI nifti to overlay, which determines the z-range
extra_filename_X: additional ROI niftis to overlay
out_filename: output .jpg or .png

Notes:
* the order of the parameters does not matter
'''

import subprocess as sp
from os.path import join,isfile,splitext
import nibabel as nib
import numpy as np
import sys

def render_lightbox(base_fname,overlay_fnames,zrange,lightbox_shape,out_fname):
    '''
    Renders lightbox scene in axial view with specificed z-range and semitransparent overlays.
    Parameters:
        base_fname: filename for base volume
        overlay_fnames: list of filenames for overlays
        zrange: z-position range as a 2-vector
        lightbox_shape: shape of lightbox [nrows,ncols]
        out_fname: output filename
    Returns:
        None
    '''

    # check inputs
    assert isfile(base_fname), 'base_fname does not exist'
    assert isinstance(overlay_fnames,list), 'overlay_fnames must be a list'
    assert all([isfile(x) for x in overlay_fnames]), 'one or more overlays does not exist'
    assert all([isinstance(x,float) for x in zrange]) and (len(zrange)==2), 'zrange must be a list of 2 floats'
    assert all([isinstance(x,int) for x in lightbox_shape]) and (len(lightbox_shape)==2), 'lightbox_shape must be a list of 2 integers'
    foo,out_ext = splitext(out_fname)
    assert any([out_ext == x for x in ['.jpg','.png']]), 'out_fname must have extension .jpg or .png'

    # create command for fsleyes
    zrange_opts = '%f %f' %(zrange[0],zrange[1])
    overlay_opts = ''
    cmap_names = define_cmap_names()
    for overlay,cmap in zip(overlay_fnames,cmap_names):
        overlay_opts = overlay_opts + '%s --cmap %s --alpha 30' %(overlay,cmap) # custom colormap, 30% opacity
        overlay_opts = overlay_opts + ' '
    cmd = "fsleyes render --scene lightbox -hc --zrange %s --nrows %d --ncols %d --outfile %s %s %s" %(zrange_opts,lightbox_shape[0],lightbox_shape[1],out_fname,base_fname,overlay_opts)

    # call fsleyes
    print(cmd)
    sp.call(cmd,shell=True)

def define_cmap_names():
    '''
    Defines the colormap names for the overlays in a call to fsleyes
    Parameters:
        None
    Returns:
        cmap_names: list of colormap names
    '''
    cmap_names = ['red','blue','green','yellow']
    return cmap_names

def get_zrange(nii):
    '''
    Calculates the z-range over which the image of a nifti is nonzero
    Parameters:
        nii: nifti object
    Returns:
        zrange: z-range over which image is nonzero
        lightbox_shape: shape [nrows,ncols] of lightbox view to encompass all slices
    '''
    # check inputs
    assert isinstance(nii,nib.nifti1.Nifti1Image), 'nii must be a nifti loaded with nibabel'
    dim = nii.header['dim']
    assert dim[0]==3, 'nifti is not a 3D array'

    # determine range of slices over which image is nonzero
    srange = [0,dim[3]-1]
    data = nii.get_fdata()
    sz = data.shape
    data_flat = np.reshape(data,(sz[0]*sz[1],sz[2]))
    loc_slice = np.any(data_flat,axis=0)
    slices, = np.nonzero(loc_slice)
    srange = np.array([slices[0]-0.5,slices[-1]+0.5])

    # convert slice range to z-position range
    srow_z = nii.header['srow_z']
    zrange = srow_z[2]*srange # range of z-positions (mm) relative to origin of array, NOT scanner coordinates origin

    # compute required number of rows and columns
    n_slice = len(slices)
    n_rows = np.floor(np.sqrt(n_slice))
    n_cols = np.ceil(float(n_slice)/float(n_rows))
    lightbox_shape = [int(n_rows),int(n_cols)]
    return zrange, lightbox_shape

def load_nifti_union(nii_fnames):
    nii = nib.load(nii_fnames[0])
    im_un = nii.get_fdata()
    for fname in nii_fnames[1:]:
        nii = nib.load(fname)
        data = nii.get_fdata()
        im_un = np.logical_or(im_un,data)
    nii_un = nib.Nifti1Image(im_un,nii.affine,nii.header)
    return nii_un 

def test_filenames():
    folder="/scratch/llawrence/bids-cns-mrl/derivatives/mrl_dwi/longitudinal_dwi/contours/sub-M001/ses-MRL001"
    t1w_filename = join(folder,'t1w_reference.nii.gz')
    gtv_filename = join(folder,'rGTV.nii.gz')
    ctv_filename = join(folder,'rCTV.nii.gz')
    return t1w_filename,gtv_filename,ctv_filename 

def test_render_lightbox():
    t1w_filename, gtv_filename, ctv_filename = test_filenames()
    overlays = [gtv_filename,ctv_filename]
    nii_un = load_nifti_union(overlays)
    zrange,lightbox_shape = get_zrange(nii_un)
    out_filename = "render_rois_test_rGTV_rCTV.jpg"
    render_lightbox(t1w_filename,overlays,zrange,lightbox_shape,out_filename)

def test_zrange():
    folder="/scratch/llawrence/bids-cns-mrl/derivatives/mrl_dwi/longitudinal_dwi/contours/sub-M001/ses-MRL001"
    gtv_filename = join(folder,'rGTV.nii.gz')
    nii = nib.load(gtv_filename)
    zrange,lightbox_shape = get_zrange(nii)
    print('zrange:')
    print(zrange)
    print('lightbox_shape:')
    print(lightbox_shape) 

def test_load_nifti_union():
    t1w_fname, gtv_fname, ctv_fname = test_filenames()
    nii_un = load_nifti_union([gtv_fname,ctv_fname])
    nib.save(nii_un,'test_union.nii') 

def proc_input(s):
    '''
    Processes the command-line inputs
    Parameters:
        s: command-line input string
    Returns:
        params: dictionary of parameters
    Notes:
        - the following are possible keys of params:
            base: filename of base volume
            main: filename of ROI that determines the z-range
            extra: filenames of additional ROIs
            out: filename of output image
    '''

    # initialize dictionary of parameters
    params = {}
    # split command-line string
    sbits = s.split(' -')[1:]

    # search through split string
    for bit in sbits:
        # split by space
        b = bit.split()
        param = b[0]
        arg = b[1]
        params[b[0]] = b[1:]

    # validate parameters
    required = ['base','main','out']
    for req in required:
        assert req in params.keys(), 'required parameter has no argument: ' + req
        assert len(params[req]) == 1, 'multiple arguments passed for parameter: ' + req

    optional = ['extra']
    all_params = required + optional
    for x in params.keys():
        assert x in all_params, 'unrecognized parameter: ' + x 
        
    return params

def test_proc_input():
    ss = ['-base t1w.nii.gz -main roi.nii.gz -out out.jpg','-base t1w.nii.gz -main roi.nii.gz -extra roi2.nii.gz roi3.nii.gz -out out.jpg']
    for s in ss:
        print(s)
        params = proc_input(s)
        print(params)
 
if __name__ == '__main__':
    # declare parameters
    s = ' '+' '.join(sys.argv[1:])
    params = proc_input(s)
    base_fname = params['base'][0]
    overlay_fnames = params['main']
    if 'extra' in params.keys(): overlay_fnames = overlay_fnames + params['extra']
    out_fname = params['out'][0]

    # compute z-range, render lightbox view in fsleyes
    nii = nib.load(params['main'][0])
    zrange, lightbox_shape = get_zrange(nii)

    # call render
    render_lightbox(base_fname,overlay_fnames,zrange,lightbox_shape,out_fname) 
