function create_low_adc_table(root,subjects)
% creates a table of low-ADC volume
% args:
%     root (str): project root
%     subjects (cell): subject names

fn_out = fullfile(root,'interim','low_adc_volumes.csv');
if exist(fn_out,'file')
    fprintf('Low ADC table already exists: %s\n',fn_out);
else

    % get enclosing ROI names and suffixes
    [encl_list,suffix_list] = get_encl_list();
    n_encl = numel(encl_list);
    
    % initialize table
    T = table;
    
    for ix_encl = 1:n_encl
        
        encl = encl_list{ix_encl};
        
        % declare parameters
        roi_dir = fullfile(root,'interim','derivatives',sprintf('low_adc%s',suffix_list{ix_encl}));
        
        n_sub = length(subjects);
        for ix_sub = 1:n_sub
            
            subject = subjects{ix_sub};
            
            sessions = get_sessions(fullfile(roi_dir,['sub-',subject]));
            n_ses = length(sessions);
            
            for ix_ses = 1:n_ses
                
                session = sessions{ix_ses};
                
                % compute volume of low-ADC region
                fn_low = fullfile(roi_dir,['sub-',subject],['ses-',session],'dwi',...
                    sprintf('sub-%s_ses-%s_label-lowADC_desc-coreg_mask.nii.gz',subject,session));
                vol = reshape(compute_roi_volume(fn_low),[],1);
                
                % compute volume of enclosing ROI
                fn_encl = strrep(fn_low,'lowADC','enclosingROI');
                vol_encl = compute_roi_volume(fn_encl);                
                
                % create vector of ADC thresholds
                fn_thresh = strrep(fn_low,'.nii.gz','.thresh');
                adc_thresh = dlmread(fn_thresh);
                adc_col = split(num2str(adc_thresh));
                n_thresh = length(adc_col);
                
                t = table(repmat(subject,n_thresh,1),...
                    repmat(session,n_thresh,1),...
                    cellstr(repmat(encl,n_thresh,1)),...
                    repmat(vol_encl,n_thresh,1),...
                    adc_col,...
                    vol,...
                    'VariableNames',{'Subject','Session','EnclosingROI','VolumeEnclosingROI','ADCThreshold','Volume'});
                T = [T;t];
                fprintf('Added low-ADC data to table: %s\n',fn_low);
            end
        end
    end

    writetable(T,fn_out);
    fprintf('Table written: %s\n',fn_out);
    
end
end