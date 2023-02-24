function create_verification_figures(root,subjects)
% creates figures to verify low-ADC regions
% args:
%     root (str): project root
%     subjects (cell): list of subject names

% get enclosing ROIs
[encl_list,suffix_list] = get_encl_list();
n_encl = numel(encl_list);

% declare directories
adc_dir = fullfile(root,'interim','derivatives','adc');
fig_dir = fullfile(root,'interim','verification');

for ix_encl = 1:n_encl
    
    encl = encl_list{ix_encl};  
    suffix = suffix_list{ix_encl};
    
    % declare directory with low-ADC ROIs
    roi_dir = fullfile(root,'interim','derivatives',sprintf('low_adc%s',suffix));
%     fig_dir = fullfile(root,'interim',sprintf('verification%s',suffix));

    % initialize figure
    fno = 1;
    figure(fno);
    set(fno,'color','w',...
        'position',[455,430,950,400]);
    
    % create figures
    n_sub = length(subjects);
    for ix_sub = 1:n_sub
        
        subject = subjects{ix_sub};
        
        sessions = get_sessions(fullfile(roi_dir,['sub-',subject]));
        n_ses = length(sessions);
        
        % declare output filename
        fn_out = fullfile(fig_dir,...
            sprintf('sub-%s_ADCmap_with_lowADC-1p25_enclosing-%s.jpg',subject,encl));
        
        if exist(fn_out,'file')
            fprintf('Image already exists: %s\n',fn_out);
        else
            
            % initalize figure
            clf(fno);
            n_row = 1;
            n_col = n_ses;
            
            
            % initialize slice to show
            slice = [];
            
            for ix_ses = 1:n_ses
                
                session = sessions{ix_ses};
                
                % get filenames
                dir_search = fullfile(adc_dir,['sub-',subject],['ses-',session],'dwi');
                fns_adc = get_keyed_fn(dir_search,'adc','.nii.gz');
                fn_adc = fns_adc{1};
                
                fn_low = fullfile(roi_dir,['sub-',subject],['ses-',session],'dwi',...
                    sprintf('sub-%s_ses-%s_label-lowADC_desc-coreg_mask.nii.gz',subject,session));
                fn_thresh = strrep(fn_low,'.nii.gz','.thresh');
                
                % get enclosing ROI
                fn_encl = get_fn_encl_roi(root,subject,session,encl);
                
                
                % load ADC map and low-ADC ROI for threshold of 1.25 and
                % enclosing ROI
                nii_adc = nii_tool('load',fn_adc);
                nii_roi = nii_tool('load',fn_low);
                nii_encl = nii_xform(fn_encl,fn_adc);
                roi_encl = nii_encl.img>0.9;
                
                adc_thresh = dlmread(fn_thresh);
                loc_1_25 = abs(adc_thresh-1.25)<eps;
                roi_adc = nii_roi.img(:,:,:,loc_1_25)>0.9;
                
                rois = cat(4,roi_encl,roi_adc);
                
                % get slice
                if isempty(slice)
                    slice = max_roi_slice(roi_encl,3);
                end
                
                % create figure
                subtightplot(n_row,n_col,ix_ses);
                view_slice(nii_adc,'axial',slice,...
                    'Contours',rois,...
                    'ContourType',{'curve','wash'},...
                    'ContourLineWidths',[0.5,1],...
                    'ContourColors',[0,0,1;1,0,0]);
                title(sprintf('ses-%s',session),...
                    'fontsize',16);
            end
            
            if n_ses>0
                export_fig(fno,fn_out);
                fprintf('Figure created: %s\n',fn_out);
            end
        end
        
    end

end


end