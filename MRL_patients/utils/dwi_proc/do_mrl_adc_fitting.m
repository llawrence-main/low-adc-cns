function do_mrl_adc_fitting(work_dir,subjects)
% Create ADC maps for dwi_response subjects
% Arguments
%     work_dir: working directory
%     subjects: list of subjects
% Returns
%     none

% declare parameters
sname = 'mr_linac';
coreg_dir = fullfile(work_dir,'results',sname,'coreg');
adc_dir = fullfile(work_dir,'results',sname,'adc');

all_bvals_11 = [0:10:50,75,100,200,400,800];
bval_indices_11 = [true(1,1), false(1,7),true(1,3)]; % b = 0, 200, 400, 800
nsa_11 = [4,1,1,1,1,1,1,1,2,3,8];

all_bvals_13 = [0:10:50,75,100,200:200:1000];
bval_indices_13 = [true, false(1,7),true,true,false,true,false]; % b = 0, 200, 400, 800
nsa_13 = [4,1,1,1,1,1,1,1,2,3,5,8,8];

% loop subjects
n_sub = length(subjects);
for ix_sub = 1:n_sub
    % get subject
    subject = subjects{ix_sub};
    
    % get brain mask filename
    fn_mask = get_fn_brainmask(work_dir,subject);
    
    % get sessions
    sessions = get_sessions(fullfile(coreg_dir,['sub-',subject]));
    n_ses = length(sessions);
    
    % loop sessions
    for ix_ses = 1:n_ses
        session = sessions{ix_ses};
        
        % declare path to DWI
        dwi_dir = fullfile(coreg_dir,['sub-',subject],['ses-',session]);
        [fn_dwi,lab_dwi] = get_keyed_fn(dwi_dir,'dwi','.nii.gz');
        assert(length(fn_dwi)==1,'The searched folder does not contain exactly one DWI: %s\n',dwi_dir);
        fn_dwi = fn_dwi{1};
        lab_dwi = lab_dwi{1};
        
        % declare path to output ADC map
        out_dir = fullfile(adc_dir,['sub-',subject],['ses-',session]);
        fn_out = fullfile(out_dir,strrep(lab_dwi,'dwi_coreg','adc.nii.gz'));        
                        
        % do ADC fit
        if exist(fn_out,'file')
            fprintf('ADC map already exists: %s\n',fn_out);
        else            
            
            % determine number of b-values
            hdr = nii_tool('hdr',fn_dwi);
            if hdr.dim(5)==13
                all_bvals = all_bvals_13;
                bval_indices = bval_indices_13;
                nsa = nsa_13;
            elseif hdr.dim(5)==11
                all_bvals = all_bvals_11;
                bval_indices = bval_indices_11;
                nsa = nsa_11;
            else
                all_bvals = [];
                bval_indices = [];
            end
            
            % create ADC map
            if isempty(all_bvals)
                fprintf('DWI did not have 11 or 13 b-values: %s\n',fn_dwi);
            else
                % create output directory
                if ~exist(out_dir,'dir')
                    mkdir(out_dir);
                end
                
                % fit ADC and write
                create_adc_from_dwi(fn_dwi,all_bvals,bval_indices,fn_out,...
                    'Method','WLLS2',...
                    'Averages',nsa,...
                    'ResampleResolution',[2,2.18,5],...
                    'MaskPath',fn_mask);
                fprintf('ADC map created: %s\n',fn_out);
            end
        end
    end
end

end