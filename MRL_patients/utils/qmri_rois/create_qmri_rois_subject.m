function create_qmri_rois_subject(work_dir,subject,adc_type)
% Creates the ROIs from quantitative MRI for a given subject
% Arguments
%     work_dir: working directory
%     subject: subject name
%     adc_type: original ADC maps or adjusted ADC maps?
% Returns
%     none

% declare parameters
validatestring(adc_type,{'original','adjusted'});
if strcmp(adc_type,'original')
    adc_dir = fullfile(work_dir,'results','mr_linac','adc');
    roi_dir = fullfile(work_dir,'results','mr_linac','qmri_rois');
elseif strcmp(adc_type,'adjusted')
    adc_dir = fullfile(work_dir,'results','mr_linac','adc_adjusted');
    roi_dir = fullfile(work_dir,'results','mr_linac','qmri_rois_adc_adjusted');
end
roi_name = 'low_adc';

% get MRL sessions
sessions = get_sessions(fullfile(adc_dir,['sub-',subject]));
n_ses = length(sessions);

% loop sessions
for ix_ses = 1:n_ses
    session = sessions{ix_ses};
    
    % declare output ROI filename
    out_dir = fullfile(roi_dir,['sub-',subject],['ses-',session]);
            
    % get ADC filename
    fn_adc = get_keyed_fn(fullfile(adc_dir,['sub-',subject],['ses-',session]),...
        'adc','.nii.gz');
    fn_adc = fn_adc{1};
    
    % create low-ADC ROI using each MR-sim contour
    sim_sessions = get_sessions(fullfile(work_dir,'results','mr_sim',...
    'glio_contours',['sub-',subject]));
    for ix_sim = 1:numel(sim_sessions)
        
        sim_session = sim_sessions{ix_sim};
        
        % declare output filename (encl-tc = enclosing tumour core/GTV)
        fn_out = fullfile(out_dir,...
            strcat(sprintf('sub-%s_ses-%s_encl-tc-%s_',subject,session,sim_session),roi_name,'.nii.gz'));
        
        if exist(fn_out,'file')
            
            fprintf('ROI already exists: %s\n',fn_out);
            
        else
            
            % get GTV or AIAA tumourcore contour
            if strcmp(subject,'M174')
                roi_names = {'GTV1','GTV2'};
            else
                roi_names = 'GTV';
            end
            [~,fn_contour] = load_rois(work_dir,subject,sim_session,...
                'definitive',...
                roi_names,...
                'FilenamesOnly',true);
            
            if (ischar(fn_contour)&&exist(fn_contour,'file'))||(iscell(fn_contour)&&all(cellfun(@(x)exist(x,'file')>0,fn_contour)))
                
                % create low-ADC ROI
                if ischar(fn_contour)
                    fprintf('creating low-ADC:\n\tadc: %s\n\tcontour: %s\n\tout: %s\n',fn_adc,fn_contour,fn_out);
                elseif iscell(fn_contour)
                    fprintf('creating low-ADC:\n\tadc: %s\n',fn_adc);
                    disp('contours:');
                    disp(fn_contour);
                    fprintf('\tout: %s\n',fn_out);
                end
                [nii_low_adc,params] = create_low_adc(fn_adc,fn_contour);
                
                % save ROI
                if ~exist(out_dir,'dir')
                    mkdir(out_dir);
                end
                nii_tool('save',nii_low_adc,fn_out);
                
                % save .json with parameters
                spm_jsonwrite(strrep(fn_out,'.nii.gz','.json'),params);
                
            end
        
        end
        
    end    
end