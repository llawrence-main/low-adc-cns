function adjust_mrl_adc(work_dir,subjects)
% Adjusts the MR-Linac ADC values to MR-sim ADC values
% Arguments
%     work_dir: working directory
%     subject: subject name
% Returns
%     none
% Notes
%     - The target ADC values (Ingenia or Achieva) are determined by the
%     MR-sim scanner at treatment planning

% declare parameters
adc_dir = fullfile(work_dir,'results','mr_linac','adc');
adj_dir = fullfile(work_dir,'results','mr_linac','adc_adjusted');

% get polynomial coefficients for ADC adjustment model
p = get_model_coeffs(work_dir);

for ix_sub = 1:numel(subjects)
    
    subject = subjects{ix_sub};
    
    % get MRL sessions
    sessions = get_sessions(fullfile(adc_dir,['sub-',subject]));
    n_ses = length(sessions);
    
    % get name of MR-sim scanner at treatment planning
    mrsim_name = get_mrsim_name_baseline(work_dir,subject);
    validatestring(mrsim_name,{'Ingenia','Achieva'});
    
    % loop sessions
    for ix_ses = 1:n_ses
        session = sessions{ix_ses};
        
        % get ADC filename
        fn_adc = get_keyed_fn(fullfile(adc_dir,['sub-',subject],['ses-',session]),...
            'adc','.nii.gz');
        fn_adc = fn_adc{1};
        [~,name,ext] = fileparts(fn_adc);
        name = [name,ext];
        
        % declare output ADC filename
        out_dir = fullfile(adj_dir,['sub-',subject],['ses-',session]);
        fn_out  = fullfile(out_dir,...
            strrep(name,'adc','desc-adjusted_adc'));
        
        if exist(fn_out,'file')
            fprintf('Adjusted ADC map already exists: %s\n',fn_out);
        else                        
            
            if ~exist(out_dir,'dir')
                mkdir(out_dir);
            end
            
            % adjust ADC values using either Ingenia or Achieva model
            adjust_adc(fn_adc,p.(mrsim_name),fn_out);
            fprintf('Adjusted ADC map written: %s\n',fn_out);
            
        end
        
    end
end

end
