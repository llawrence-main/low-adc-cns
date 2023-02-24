function list_missing(root,subjects)
% write list of missing files
% args:
%     root (str): project root
%     subjects (cell): array of subject names

% declare options
deriv_dir = fullfile(root,'interim','derivatives');
contour_dir = fullfile(deriv_dir,'contours');
roi_dir = fullfile(deriv_dir,'low_adc');
adc_dir = fullfile(deriv_dir,'adc');
bids_dir = fullfile(root,'data','bids-mrsim-glio');
rt_dir = fullfile(root,'data','RT_contours');

fn_out = fullfile(root,'interim','files_missing.tsv');
if exist(fn_out,'file')
    fprintf('Missing-file table already exists: %s\n',fn_out);
else

    % initialize table
    T = table;
    
    n_sub = numel(subjects);
    n_ses = 4;
    sessions = cellfun(@(x)sprintf('GLIO0%s',x),split(num2str(1:n_ses)),'UniformOutput',false);
    for ix_sub = 1:n_sub
        subject = subjects{ix_sub};
        
        for ix_ses = 1:n_ses
            session = sessions{ix_ses};
            
            key = sprintf('sub-%s_ses-%s',subject,session);
            
            % determine if low-ADC exists
            fn_low = fullfile(roi_dir,['sub-',subject],['ses-',session],'dwi',...
                sprintf('sub-%s_ses-%s_label-lowADC_desc-coreg_mask.nii.gz',subject,session));
            if exist(fn_low,'file')
                has_low_adc = 1;
            else
                has_low_adc = 0;
            end
            
            % determine if ADC volume exists
            dir_search = fullfile(adc_dir,['sub-',subject],['ses-',session],'dwi');
            fns_adc = get_keyed_fn(dir_search,'adc','.nii.gz');
            if isempty(fns_adc)
                has_adc = 0;
            else
                has_adc = 1;
            end
            
            % determine if DWI was acquired
            dir_dwi = fullfile(bids_dir,['sub-',subject],['ses-',session],'dwi');
            fns_dwi = get_keyed_fn(dir_dwi,'dwi','.nii.gz');
            if isempty(fns_dwi)
                has_dwi = 0;
            else
                has_dwi = 1;
            end
            
            % determine if co-registered GTV exists
            fn_gtv_coreg = get_fn_contour(root,subject,session,'GTV');
            if isempty(fn_gtv_coreg)
                has_coreg_gtv = 0;
            else
                has_coreg_gtv = 1;
            end
            
            % determine if GTV exists in BIDS dataset
            fn_gtv = fullfile(contour_dir,['sub-',subject],['ses-',session],'anat',...
                sprintf('sub-%s_ses-%s_label-GTV_mask.nii.gz',subject,session));
            if exist(fn_gtv,'file')
                has_gtv = 1;
            else
                has_gtv = 0;
            end
            
            % determine if contour folder exists in Rachel's dataset
            timepoint = convert_temporal_label(root,subject,'Session',session,'Timepoint');
            subject_no = erase(subject,'GBM0');
            dir_gtv_source = fullfile(rt_dir,subject_no,timepoint);
            fns_gtv_source = spm_select('List',dir_gtv_source,'(?i)gtv.*\.nii\.gz$');
            if ~isempty(fns_gtv_source)
                has_source_gtv = 1;
            else
                has_source_gtv = 0;
            end
            
            % determine if source imaging folder exists
            image_folder = get_image_folder(root,subject,timepoint);
            if isempty(image_folder)
                has_image_folder = 0;
            else
                has_image_folder = 1;
            end
            
            % add row to table if low-ADC volume missing
            if ~has_low_adc
                
                t = table({key},has_low_adc,has_adc,has_dwi,has_coreg_gtv,has_gtv,has_source_gtv,has_image_folder,...
                    'VariableNames',{'SubjectSession','HasLowADC','HasADCVolume','HasDWI','HasCoregGTV','HasGTV','HasSourceGTV','HasImageFolder'});
                T = [T;t];
            end
        end
    end
    
    writetable(T,fn_out,'delimiter','tab','fileType','text');
    fprintf('List of missing files written: %s\n',fn_out);
    
end

end