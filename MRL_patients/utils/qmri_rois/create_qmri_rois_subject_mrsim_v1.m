function create_qmri_rois_subject_mrsim_v1(work_dir,subject)
% Creates the ROIs from quantitative MRI for a given subject for the MR-sim
% Arguments
%     work_dir: working directory
%     subject: subject name
% Returns
%     none

% declare parameters
adc_dir = fullfile(work_dir,'results','mr_sim','adc');

% boundary ROIs
bound_rois = declare_boundary_rois();
n_bounds = length(bound_rois.names);

roi_name = 'low_adc';

% get sessions
sessions = get_sessions(fullfile(adc_dir,['sub-',subject]));
n_ses = length(sessions);

% get reference session
ref_session = get_reference_session(work_dir,subject);

% loop sessions
for ix_ses = 1:n_ses
    
    session = sessions{ix_ses};        
        
    % get ADC filename
    fn_adc = get_keyed_fn(fullfile(adc_dir,['sub-',subject],['ses-',session]),...
        'adc','.nii.gz');
    fn_adc = fn_adc{1};
        
    % loop boundary ROIs
    for ix_bound = 1:n_bounds
        
        % declare all output ROI filenames
        roi_dir = fullfile(work_dir,'results','mr_sim',['qmri_rois',bound_rois.onames{ix_bound}]);
        out_dir = fullfile(roi_dir,['sub-',subject],['ses-',session]);
        fn_out = fullfile(out_dir,...
            strcat(sprintf('sub-%s_ses-%s_',subject,session),roi_name,'.nii.gz'));
        
        if exist(fn_out,'file')
            fprintf('ROI already exists: %s\n',fn_out);
        else                                    
            
            % get boundary ROI filename
            switch bound_rois.names{ix_bound}
                case 'GTV'
                    bound_session = ref_session;
                case 'tumourcore'
                    bound_session = session;
            end
            [~,fns_contour] = load_rois(work_dir,subject,bound_session,...
                bound_rois.types{ix_bound},...
                bound_rois.names(ix_bound),...
                'FilenamesOnly',true);
            fn_contour = fns_contour{1};
            
            if exist(fn_contour,'file')
            
                % create low-ADC ROI
                nii_low_adc = create_low_adc(fn_adc,fn_contour);
                
                % save ROI
                if ~exist(out_dir,'dir')
                    mkdir(out_dir);
                end
                nii_tool('save',nii_low_adc,fn_out);
                fprintf('ROI created: %s\n',fn_out);
                
            else
                warning('Boundary contour does not exist: %s\n',fn_contour);
            end
        end
    end
end
end