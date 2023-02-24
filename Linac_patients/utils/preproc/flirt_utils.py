import nipype.interfaces.fsl as fsl
from os import remove
import os
from os.path import basename, join, isfile
import subprocess

def flirt_apply(in_fnames,ref_fname,in2ref_fname,out_dir,suffix,overwrite=True,method='trilinear'):
    """Applies saved transformation from input to reference space
    Args:
        in_fnames (list): filenames to transform
        ref_fname (str): filename of reference
        in2ref_fname (str): filename of transformation matrix
        out_dir (str): output directory
        suffix (str): suffix for desc- entity
        overwrite (bool): overwrite an existing volume?
        method (str, optional): interpolation method
    Returns:
        out_fnames (list): output filenames
    """
    out_fnames = []
    for in_fname in in_fnames:
        # declare output name
        in_name = basename(in_fname).split('.')[0]
        out_name = declare_out_name(in_name,suffix)
        out_fname = os.path.join(out_dir,out_name+'.nii.gz')
        out_fnames.append(out_fname)
        if isfile(out_fname) and not overwrite:
            print('File already exists: ' + out_fname)
        else:
            # apply transformation to ROI
            applyxfm = fsl.preprocess.ApplyXFM()
            applyxfm.inputs.in_file = in_fname
            applyxfm.inputs.uses_qform = False
            applyxfm.inputs.in_matrix_file = in2ref_fname
            applyxfm.inputs.out_matrix_file = '/tmp/temp_matrix_can_delete.mat'
            applyxfm.inputs.reference = ref_fname
            applyxfm.inputs.out_file = out_fname
            applyxfm.inputs.interp = method
            print(applyxfm.cmdline)
            print()
            applyxfm.run()

    return out_fnames

def flirt_propagate(in_fname,ref_fname,roi_fnames,suffix,out_dir,overwrite=True,resample=0,inverse=False,in2ref_matrix_fname=''):
    '''Registers input to reference and applies the same transformation to ROIs in the same space as the input
    Parameters:
        in_fname: input filename
        ref_fname: reference filename
        roi_fnames: list of ROI filenames
        suffix: suffix for entity desc-
        out_dir: output directory
        overwrite: overwrite existing files?
        resample: if nonzero, resamples source and reference to 2 mm voxels before registration
        inverse: if true, will register reference to source then invert the transformation
        in2ref_matrix_fname: if nonempty, will use this matrix to transform contours
    '''

    # check inputs
    assert resample>=0, 'resample must be non-negative'
    
    if not in2ref_matrix_fname:
        # register input to reference
        in_name = basename(in_fname).split('.')[0]
        out_name = declare_out_name(in_name,suffix)
        out_basename = join(out_dir,out_name)
    #    out_basename = join(out_dir,in_name + '_' + suffix)
        out_fname = out_basename + '.nii.gz'
        in2ref_matrix_fname = out_basename + '.mat'
        if isfile(in2ref_matrix_fname) and not overwrite:
            print('skipping input-to-reference registration since output matrix exists: ' + in2ref_matrix_fname)
            print()
        else:
            if resample:
                # resample source and reference
                resample_fnames = [in_fname,ref_fname]
                new_fnames = []
                for fname in resample_fnames:
                    name = basename(fname)
                    iso_fname = join(out_dir,name.replace('.nii.gz','_iso'+str(resample)+'.nii.gz'))
                    new_fnames.append(iso_fname)
                    if isfile(out_fname) and not overwrite:
                        print('skipping resampling since iso volume already exists: ' + iso_fname)
                    else:
                        # split volume
                        spl = fsl.utils.Split()
                        spl.inputs.in_file = fname
                        spl.inputs.out_base_name = join(out_dir,name.replace('.nii.gz','_')) 
                        spl.inputs.dimension = 't'
                        print(spl.cmdline)
                        spl_res = spl.run()
                        if isinstance(spl_res.outputs.out_files,list):
                            spl_fnames = spl_res.outputs.out_files
                        else:
                            spl_fnames = [spl_res.outputs.out_files]

                        # resample
                        iso = fsl.preprocess.FLIRT()
                        iso.inputs.in_file = spl_fnames[0]
                        iso.inputs.reference = iso.inputs.in_file
                        iso.inputs.apply_isoxfm = 2
                        iso.inputs.out_file = iso_fname
                        iso.inputs.out_matrix_file = iso_fname.replace('.nii.gz','.mat')
                        print(iso.cmdline)
                        iso.run()

                        # delete split volume files
                        for spl_fname in spl_fnames:
                            remove(spl_fname)
            
                # update source and reference names for registration
                in_fname_reg = new_fnames[0]
                ref_fname_reg = new_fnames[1]
            else:
                # use passed source and reference
                in_fname_reg = in_fname
                ref_fname_reg = ref_fname

            if inverse:
                # if inverting transformation, swap input and reference
                in_temp = in_fname_reg
                ref_temp = ref_fname_reg
                in_fname_reg = ref_temp
                ref_fname_reg = in_temp
                trans_matrix_fname = out_basename + '_inverse.mat'
            else:
                trans_matrix_fname = in2ref_matrix_fname

            # estimate transformation
            flt = fsl.FLIRT(cost='mutualinfo')
            flt.inputs.in_file = in_fname_reg
            flt.inputs.reference = ref_fname_reg
            flt.inputs.dof = 6
            flt.inputs.out_file = ''
            flt.inputs.out_matrix_file = trans_matrix_fname
            flt.inputs.no_search = True
            cmd = flt.cmdline.replace('-out . ','')
            print(cmd)
            print()
            subprocess.call(cmd,shell=True)

            if resample:
                # remove resampled volumes
                for new_fname in new_fnames:
                    print('removing resampled volumes and mat file: ' + new_fname)
                    remove(new_fname)
                    remove(new_fname.replace('.nii.gz','.mat'))

            if inverse:
                # invert transformation
                invt = fsl.ConvertXFM()
                invt.inputs.in_file = trans_matrix_fname
                invt.inputs.invert_xfm = True
                invt.inputs.out_file = in2ref_matrix_fname
                print(invt.cmdline)
                print()
                invt.run()

    # apply transformation to ROIs
    for roi_fname in roi_fnames:
        roi_name = basename(roi_fname).split('.')[0]
        out_basename = join(out_dir,roi_name + '_' + suffix)
        out_fname = out_basename + '.nii.gz'

        if isfile(out_fname) and not overwrite:
            print('skipping registration of other volume since output files exist:')
            print(out_fname)
            print()
        else:

            # apply transformation to ROI
            applyxfm = fsl.preprocess.ApplyXFM()
            applyxfm.inputs.in_file = roi_fname
            applyxfm.inputs.uses_qform = False
            applyxfm.inputs.in_matrix_file = in2ref_matrix_fname
            applyxfm.inputs.out_matrix_file = '/tmp/temp_matrix_can_delete.mat'
            applyxfm.inputs.reference = ref_fname
            applyxfm.inputs.out_file = out_fname
            applyxfm.inputs.interp = 'nearestneighbour'
            print(applyxfm.cmdline)
            print()
            applyxfm.run()

    # symlink to reference
    dst = join(out_dir,'reference.nii.gz')
    if not os.path.exists(dst):
        os.symlink(ref_fname,dst)
        print('Created symbolic link to reference: ' + dst)
    else:
        print('Symbolic link to reference already exists: ' + dst)
        
def flirt_volumes(in_fname,ref_fname,other_fnames,suffix,out_dir,other_qform=True,overwrite=True,create_intermediate=False,resample=0):
    '''Registers input to reference and uses same transformation for other volumes
    Parameters:
        in_fname: input filename
        ref_fname: reference filename
        other_fnames: list of other filenames to which src-> ref transformation should be applied
        suffix: suffix for entity desc-
        out_dir: output directory
        other_sqform: if True, use qform for other->in transformation; if False, estimates transformation through registration
        create_intermediate: if True, creates intermediate other->in registered volume
        overwrite: overwrite existing files?
        resample: if nonzero, resamples source and reference to 2 mm voxels before registration
    Returns:
        out_fname: filename of input registered to reference
    Notes:
        - if the input or reference is a 4D volume, "resample" must be non-zero
    '''

    # check inputs
    assert resample>=0, 'resample must be non-negative'
        
    # register input to reference
    in_name = basename(in_fname).split('.')[0]
    out_name = declare_out_name(in_name,suffix)
    out_basename = join(out_dir,out_name)
#    in_bits = in_name.split('_')
#    in_bits.insert(len(in_bits)-1,'desc-'+suffix)
#    out_basename = join(out_dir,'_'.join(in_bits))
    out_fname = out_basename + '.nii.gz'
    in2ref_matrix_fname = out_basename + '.mat'
    if isfile(in2ref_matrix_fname) and not overwrite:
        print('skipping input-to-reference registration since output matrix exists: ' + in2ref_matrix_fname)
        print()
    else:
        if resample:
            # resample source and reference
            resample_fnames = [in_fname,ref_fname]
            new_fnames = []
            for fname in resample_fnames:
                name = basename(fname)
                iso_fname = join(out_dir,name.replace('.nii.gz','_iso'+str(resample)+'.nii.gz'))
                new_fnames.append(iso_fname)
                if isfile(out_fname) and not overwrite:
                    print('skipping resampling since iso volume already exists: ' + iso_fname)
                else:
                    # split volume
                    spl = fsl.utils.Split()
                    spl.inputs.in_file = fname
                    spl.inputs.out_base_name = join(out_dir,name.replace('.nii.gz','_')) 
                    spl.inputs.dimension = 't'
                    print(spl.cmdline)
                    spl_res = spl.run()
                    if isinstance(spl_res.outputs.out_files,list):
                        spl_fnames = spl_res.outputs.out_files
                    else:
                        spl_fnames = [spl_res.outputs.out_files]

                    # resample
                    iso = fsl.preprocess.FLIRT()
                    iso.inputs.in_file = spl_fnames[0]
                    iso.inputs.reference = iso.inputs.in_file
                    iso.inputs.apply_isoxfm = 2
                    iso.inputs.out_file = iso_fname
                    iso.inputs.out_matrix_file = iso_fname.replace('.nii.gz','.mat')
                    print(iso.cmdline)
                    iso.run()

                    # delete split volume files
                    for spl_fname in spl_fnames:
                        remove(spl_fname)
        
            # update source and reference names for registration
            in_fname_reg = new_fnames[0]
            ref_fname_reg = new_fnames[1]
        else:
            # use passed source and reference
            in_fname_reg = in_fname
            ref_fname_reg = ref_fname

        # estimate transformation
        flt = fsl.FLIRT(cost='mutualinfo')
        flt.inputs.in_file = in_fname_reg
        flt.inputs.reference = ref_fname_reg
        flt.inputs.dof = 6
        flt.inputs.out_file = ''
        flt.inputs.out_matrix_file = in2ref_matrix_fname
        flt.inputs.no_search = True
        cmd = flt.cmdline.replace('-out . ','')
        print(cmd)
        print()
        subprocess.call(cmd,shell=True)

        if resample:
            # remove resampled volumes
            for new_fname in new_fnames:
                print('removing resampled volumes and mat file: ' + new_fname)
                remove(new_fname)
                remove(new_fname.replace('.nii.gz','.mat'))

    if isfile(out_fname) and not overwrite:
        print('skipping input-to-reference applyxfm since output volume exists: ' + out_fname)
        print()
    else:
        # apply transformation
        applyxfm_in2ref = fsl.preprocess.ApplyXFM()
        applyxfm_in2ref.inputs.in_file = in_fname
        applyxfm_in2ref.inputs.reference = ref_fname
        applyxfm_in2ref.inputs.out_file = out_fname
        applyxfm_in2ref.inputs.in_matrix_file = in2ref_matrix_fname
        applyxfm_in2ref.inputs.out_matrix_file = in2ref_matrix_fname
        applyxfm_in2ref.inputs.apply_xfm = True
        print(applyxfm_in2ref.cmdline)
        print()
        applyxfm_in2ref.run() 

    # apply transformation to other volumes
    for other_fname in other_fnames:
        other_name = basename(other_fname).split('.')[0]
        out_basename = join(out_dir,other_name + '_' + suffix)
        out_fname = out_basename + '.nii.gz'
        out_matrix_fname = out_basename + '.mat'
        p1_matrix_fname = out_basename + '_phase1.mat'

        if isfile(out_fname) and isfile(out_matrix_fname) and not overwrite:
            print('skipping registration of other volume since output files exist:')
            print(out_fname)
            print(out_matrix_fname)
            print()
        else:
            # put volume into space of input file
            if isfile(p1_matrix_fname) and not overwrite:
                print('skipping registration of other volume to input volume since phase 1 matrix exists: ' + p1_matrix_fname)
            else:
                if other_qform:
                    # use qform
                    applyxfm = fsl.preprocess.ApplyXFM()
                    applyxfm.inputs.in_file = other_fname
                    applyxfm.inputs.reference = in_fname
                    applyxfm.inputs.out_file = ''
                    applyxfm.inputs.out_matrix_file = p1_matrix_fname 
                    applyxfm.inputs.apply_xfm = True
                    applyxfm.inputs.uses_qform = True
                    cmd = applyxfm.cmdline.replace('-out . ','')
                else:
                    # estimation transformation
                    flt_other = fsl.FLIRT(cost='mutualinfo')
                    flt_other.inputs.dof = 6
                    flt_other.inputs.no_search = True
                    flt_other.inputs.in_file = other_fname
                    flt_other.inputs.reference = in_fname
                    flt_other.inputs.out_file = ''
                    flt_other.inputs.out_matrix_file = p1_matrix_fname
                    cmd = flt_other.cmdline.replace('-out . ','')
                print(cmd)
                print()
                subprocess.call(cmd,shell=True)


            # concatenate matrices
            concat = fsl.ConvertXFM()
            concat.inputs.in_file2 = in2ref_matrix_fname
            concat.inputs.in_file = p1_matrix_fname
            concat.inputs.concat_xfm = True
            concat.inputs.out_file = out_matrix_fname
            print(concat.cmdline)
            print()
            concat.run() 

            # apply transformation to volume
            applyxfm = fsl.preprocess.ApplyXFM()
            applyxfm.inputs.in_file = other_fname
            applyxfm.inputs.uses_qform = False
            applyxfm.inputs.in_matrix_file = out_matrix_fname
            applyxfm.inputs.out_matrix_file = out_matrix_fname
            applyxfm.inputs.reference = ref_fname
            applyxfm.inputs.out_file = out_fname
            print(applyxfm.cmdline)
            print()
            applyxfm.run()
        
        # create intermediate other->in registered volume 
        if create_intermediate:
            # apply phase 1 transformation to other volume
            out_p1_fname = out_basename + '_phase1.nii.gz'
            if isfile(out_p1_fname) and not overwrite:
                print('phase 1 registered volume already exists: ' + out_p1_fname)
            else:
                applyxfm = fsl.preprocess.ApplyXFM()
                applyxfm.inputs.in_file = other_fname
                applyxfm.inputs.reference = in_fname
                applyxfm.inputs.out_file = out_p1_fname
                applyxfm.inputs.in_matrix_file = p1_matrix_fname 
                applyxfm.inputs.out_matrix_file = p1_matrix_fname
                applyxfm.inputs.apply_xfm = True
                print(applyxfm.cmdline)
                print()
                applyxfm.run()

    return out_fname

def declare_out_name(in_name,suffix):
    """Declares the output filename given an input filename in BIDS convention
    Args:
        in_name: input name
        suffix: suffix for entity desc-
    Returns:
        out_name: output name
    """

    in_bits = in_name.split('_')
    in_bits.insert(len(in_bits)-1,'desc-'+suffix)
    out_name = '_'.join(in_bits)
    return out_name
