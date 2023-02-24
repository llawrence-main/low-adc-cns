function fit_adc_maps(root,subjects)
% Create ADC maps
% Arguments
%     root (str): root of project directory
%     subjects (cell): list of subjects

% declare directories
coreg_dir = fullfile(root,'interim','derivatives','coreg');
adc_dir = fullfile(root,'interim','derivatives','adc');

% declare diffusion fitting parameters
bvals = [0,500,1000]; % b-values, from protocol text file and DICOMs
bval_indices = true(1,3); % use b-values [0,500,1000]
nsa = [1,2,3]; % number of averages for option "average high b = yes" on Philips scanner
res = [1.14,1.45,5]; % resolution, from protocol text file and DICOMs

n_sub = length(subjects);
for ix_sub = 1:n_sub
    % get subject
    subject = subjects{ix_sub};
    
    % get brain mask filename
    fn_mask = get_fn_brainmask(root,subject);
    
    % get sessions
    sessions = get_sessions(fullfile(coreg_dir,['sub-',subject]));
    n_ses = length(sessions);
        
    for ix_ses = 1:n_ses
        session = sessions{ix_ses};
        
        % declare path to DWI
        dwi_dir = fullfile(coreg_dir,['sub-',subject],['ses-',session],'dwi');
        [fn_dwi,lab_dwi] = get_keyed_fn(dwi_dir,'dwi','.nii.gz');
        if length(fn_dwi)<1
            warning('The searched folder does not contain any DWI: %s\n',dwi_dir);
        else
            fn_dwi = fn_dwi{end};
            lab_dwi = lab_dwi{end};
            
            % declare path to output ADC map
            out_dir = fullfile(adc_dir,['sub-',subject],['ses-',session],'dwi');
            fn_out = fullfile(out_dir,strrep(lab_dwi,'dwi','adc.nii.gz'));
            
            % do ADC fit
            if exist(fn_out,'file')
                fprintf('ADC map already exists: %s\n',fn_out);
            else
                                                                   
                % create output directory
                if ~exist(out_dir,'dir')
                    mkdir(out_dir);
                end
                
                % declare fitting parameters
                if strcmp(subject,'GBM084')&&strcmp(session,'GLIO04')
                    bvals_use = [0,200,400,600,800,1000]; % from DICOM
                    bval_indices_use = true(1,6);
                    nsa_use = [1,1,1,2,2,3]; % Philips "average high b" option
                else
                    bvals_use = bvals;
                    bval_indices_use = bval_indices;
                    nsa_use = nsa;
                end
                
                % fit ADC and write
                create_adc_from_dwi(fn_dwi,bvals_use,bval_indices_use,fn_out,...
                    'Method','WLLS2',...               
                    'Average',nsa_use,...
                    'ResampleResolution',res,...
                    'MaskPath',fn_mask,...
                    'BIDSjson',true);
                                
                fprintf('ADC map created: %s\n',fn_out);
                                
            end            
        end
    end
end

end