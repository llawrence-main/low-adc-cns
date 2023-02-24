function create_planning_gtv_comparison_figure(root,fig_dir)
% creates a figure to compare use of GTV of the day versus planning GTV

plan_gtv_vals = [false,true];
gtv_labels = {'daily','plan'};
subject = 'GBM068';

xlims = [121,183];
ylims = [24,98];

for ix_plan = 1:2
    plan_gtv = plan_gtv_vals(ix_plan);
    gtv_label = gtv_labels{ix_plan};
    
    % declare parameters
    adc_dir = fullfile(root,'interim','derivatives','adc');
    if plan_gtv
        roi_dir = fullfile(root,'interim','derivatives','low_adc_planning_gtv');
        
    else
        roi_dir = fullfile(root,'interim','derivatives','low_adc');
        
    end
    plan_session = 'GLIO01';
    
    % initialize figure
    fno = 1;
    figure(fno);
    set(fno,'color','w',...
        'position',[455,430,950,400]);
    
    % create figures
    
    
    
    
    
    sessions = get_sessions(fullfile(roi_dir,['sub-',subject]));
    n_ses = length(sessions);
    
    % declare output filename
    fn_out = fullfile(fig_dir,...
        sprintf('sub-%s_ADCmap_with_lowADC-1p25_GTV-%s.jpg',subject,gtv_label));
    
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
            
            if plan_gtv
                fn_gtv = get_fn_contour(root,subject,plan_session,'GTV');
            else
                fn_gtv = get_fn_contour(root,subject,session,'GTV');
            end
            
            
            % load ADC map and low-ADC ROI for threshold of 1.25 and GTV
            nii_adc = nii_tool('load',fn_adc);
            nii_roi = nii_tool('load',fn_low);
            nii_gtv = nii_xform(fn_gtv,fn_adc);
            roi_gtv = nii_gtv.img>0.9;
            
            adc_thresh = dlmread(fn_thresh);
            loc_1_25 = abs(adc_thresh-1.25)<eps;
            roi_adc = nii_roi.img(:,:,:,loc_1_25)>0.9;
            
            rois = cat(4,roi_gtv,roi_adc);
            
            % get slice
            if isempty(slice)
                slice = max_roi_slice(roi_gtv,3);
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
            xlim(xlims);
            ylim(ylims);
        end
        
        if n_ses>0
            export_fig(fno,fn_out);
            fprintf('Figure created: %s\n',fn_out);
        end
    end
    
end