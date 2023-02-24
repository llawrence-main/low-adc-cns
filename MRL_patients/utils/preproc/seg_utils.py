import os
import numpy as np
import subprocess
import nibabel as nib
from os.path import isfile, isdir, join
from scipy import ndimage
os.environ['MKL_THREADING_LAYER'] = 'GNU' # to fix issue with hd-bet: Error: mkl-service + Intel(R) MKL: MKL_THREADING_LAYER=INTEL is incompatible with libgomp-a34b3233.so.1 library. 

def erode_mask(img):
    '''Computes the binary erosion of a 3D image slice-by-slice
    Parameters:
        img: 3D image
    Returns:
        image after erosion
    '''
    # check inputs
    assert np.ndim(img)==3, 'img must be a 3D array'
#    assert isinstance(r,int) and r>0, 'r must be a positive integer'

    # create structuring element
    el = ndimage.generate_binary_structure(2,1)

    # erode image slice-by-slice
    img = np.transpose(img,(2,0,1))
    ns = img.shape[0]
    for ix in range(ns):
        s = img[ix,:,:]
        img[ix,:,:] = ndimage.binary_erosion(s,el)
    img = np.transpose(img,(1,2,0))

    return img

def contralateral_rois(seg_filename,c_filename,ven_filename,out_dir,ctv_filename='',overwrite=True):
    '''Intersects contralateral region with WM, GM masks, and ventricles with CSF, from FSL FAST. Also excludes CTV. Saves ROIs.
    Parameters:
        seg_filename: path to _seg.nii.gz from FSL FAST
        c_filename: path to contralateral nifti
        ven_filename: path to ventricle nifti
        out_dir: directory to save outputs
        ctv_filename: filename of CTV, to exclude from contralteral regions
        overwrite: overwrite existing files?
    '''
    # check inputs
    assert isfile(seg_filename), 'seg_filename does not exist: ' + seg_filename
    assert isfile(c_filename), 'c_filename does not exist: ' + c_filename
    assert isfile(ven_filename), 'ven_filename does not exist: ' + ven_filename
    assert (not ctv_filename) or isfile(ctv_filename), 'ctv_filename does not exist: ' + ctv_filename
    assert isdir(out_dir), 'out_dir does not exist: ' + out_dir

    # declare options
    erode_csf = False

    # declare output names
    seg_name = os.path.basename(seg_filename).split('.')[0]
    out_filenames = [join(out_dir,seg_name.replace('_seg','_'+x+'.nii.gz')) for x in ['csf','gm','wm']]

    # loop ROIs
    volumes_loaded = False # have volumes been loaded already?
    for ix,out_filename in zip(range(3),out_filenames):
        if isfile(out_filename) and (not overwrite):
            print('ROI already exists: ' + out_filename)
        else:
            if not volumes_loaded:
                # load segmentation and contralateral mask and ventricle mask and CTV mask if requested
                nii_seg = nib.load(seg_filename)
                seg = nii_seg.get_fdata()
                nii_c = nib.load(c_filename)
                c = nii_c.get_fdata() 
                nii_ven = nib.load(ven_filename)
                ven = nii_ven.get_fdata()
                if ctv_filename:
                    nii_ctv = nib.load(ctv_filename)
                    ctv = nii_ctv.get_fdata()

                # repeat contralateral mask axially
                c_slice = np.any(c,axis=2)
                c = np.transpose(np.tile(c_slice,(c.shape[2],1,1)),(1,2,0))

                # set flag to skip loading on next iteration 
                volumes_loaded = True

            # get channel
            channel = seg == ix+1
            # intersect channel with contralateral 
            c_channel = np.logical_and(channel,c)
            if ix == 0:
                # intersect CSF with ventricles
                c_channel = np.logical_and(c_channel,ven)
                if erode_csf:
                    # erode CSF 
                    c_channel = erode_mask(c_channel)
            
            # exclude CTV
            if ctv_filename:
                c_channel = np.logical_and(c_channel,np.logical_not(ctv))

            # save nifti
            nii_o = nib.Nifti1Image(c_channel,nii_c.affine,nii_c.header) 
            nib.save(nii_o,out_filename)
            print('ROI created: ' + out_filename)

def do_hdbet(t1w_path,output_folder):
	'''Applies HD-BET to extract brain from a T1w volume and saves to desired folder.
	IN
	t1w_path: full path to T1w volume.
	output_folder: folder in which to save brain.
	OUT
	output_path: full path to output volume
	'''
	# Check if volume exists
	if not os.path.exists(t1w_path):
		raise ValueError('T1w volume %s does not exist.' % (t1w_path))

	# Create output folder if it does not exist
	if not os.path.exists(output_folder):
		print('Creating output folder.')
		command = 'mkdir -p %s' % (output_folder)
		print(command)
		subprocess.call(command,shell=True)

	# Define output path
	t1w_name = os.path.basename(t1w_path).split('.')[0]
	output_name = '%s_brain.nii.gz' % (t1w_name)
	output_path = os.path.join(output_folder,output_name)

	# Check if output path exists
	if os.path.exists(output_path):
		print('Brain volume %s already exists.' % (output_path))
	else:
		# Call HD-BET
		command = 'hd-bet -i %s -o %s -device cpu -mode fast -tta 0' % (t1w_path,output_path)
		print('Calling HD-BET for brain extraction.')
		print(command)
		subprocess.call(command,shell=True)
	return output_path

def do_fast(brain_path,output_folder):
	'''Applies FSL FAST to a T1w brain volume and saves results in desired folder.
	IN
	brain_path: full path to T1w brain volume.
	output_folder: folder in which to save FAST segmentation.
	OUT
	'''
	# Check if brain volume exists
	if not os.path.exists(brain_path):
		raise ValueError('Brain volume %s does not exist.' % (brain_path))

	# Create output folder if it does not exist
	if not os.path.exists(output_folder):
		print('Creating output folder.')
		command = 'mkdir -p %s' % (output_folder)
		print(command)
		subprocess.call(command,shell=True)

	# Define output path
	brain_name = os.path.basename(brain_path).split('.')[0]
	output_name = brain_name
	output_path = os.path.join(output_folder,output_name)

	# Check if output path already exists
	output_seg_path = output_path+'_seg.nii.gz'
	if os.path.exists(output_seg_path):
		print('Segmentation volume %s already exists.' % (output_seg_path))
	else:
		# Call FSL FAST
		command = '/usr/local/fsl/bin/fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -o %s %s' % (output_path,brain_path)
		print('Calling FSL FAST for segmentation.')
		print(command)
		subprocess.call(command,shell=True)

if __name__ == '__main__':
    
    img = np.zeros((10,10,5),dtype=np.int)
    img[2:7,2:7,:] = 1
    affine = np.identity(4)
    nii = nib.Nifti1Image(img,affine)
    print('img')
    print(nii.get_fdata())
    print()

    enii = erode_mask(nii)

    print('img after erosion')
    print(enii.get_fdata())
    print()

