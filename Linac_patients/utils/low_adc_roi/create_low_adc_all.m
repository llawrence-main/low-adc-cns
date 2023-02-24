function create_low_adc_all(root,subjects)
% Creates low-ADC regions using variety of enclosing ROIs
% Arguments
%     root (str): project root
%     subjects (cell): subject names

% declare options
overwrite = 0;
parent = what('..');

% declare enclosing ROIs
[encl_list,suffix_list] = get_encl_list();
n_encl = numel(encl_list);

% declare directories
adc_dir = fullfile(root,'interim','derivatives','adc');

for ix_encl = 1:n_encl
    
    encl = encl_list{ix_encl};
    
    % declare output directory
    roi_dir = fullfile(root,'interim','derivatives',sprintf('low_adc%s',suffix_list{ix_encl}));    
    
    % upper threshold values
    adc_thresh = 0.25:0.25:1.5;
    
    n_sub = numel(subjects);
    for ix_sub = 1:n_sub
        
        subject = subjects{ix_sub};
        
        sessions = get_sessions(fullfile(adc_dir,['sub-',subject]));
        
        n_ses = length(sessions);
        for ix_ses = 1:n_ses
            
            session = sessions{ix_ses};
            
            % declare all output ROI filenames
            out_dir = fullfile(roi_dir,['sub-',subject],['ses-',session],'dwi');
            fn_out = fullfile(out_dir,...
                sprintf('sub-%s_ses-%s_label-lowADC_desc-coreg_mask.nii.gz',subject,session));
            
            % get ADC filename
            fn_adc = get_keyed_fn(fullfile(adc_dir,['sub-',subject],['ses-',session],'dwi'),...
                'adc','.nii.gz');
            fn_adc = fn_adc{1};
            
            % get filename of enclosing ROI
            fn_encl = get_fn_encl_roi(root,subject,session,encl);
            
            % create low-ADC ROIs and symlink to enclosing ROI
            if all(cellfun(@(x)exist(x,'file'),{fn_adc,fn_encl}))
                create_low_adc(fn_adc,fn_encl,adc_thresh,fn_out,overwrite);
                
                fn_encl_target = strrep(fn_out,'lowADC','enclosingROI');
                if exist(fn_encl_target,'file')
                    fprintf('Symlink to enclosing ROI already exists: %s\n',fn_encl_target);
                else
                    fn_encl_source = strrep(fn_encl,'..',parent.path);
                    create_symlink(fn_encl_source,fn_encl_target);
                    fprintf('Created symlink to enclosing ROI: %s\n',fn_encl_target);
                end
            else
                fprintf('Some files are missing for low-ADC region definition: sub-%s_ses-%s\n',subject,session);
            end
        end
    end
end