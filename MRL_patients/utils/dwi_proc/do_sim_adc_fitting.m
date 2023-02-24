function do_sim_adc_fitting(work_dir,subjects)
% Create ADC maps for dwi_response subjects
% Arguments
%     work_dir: working directory
%     subjects: list of subjects
% Returns
%     none

% declare parameters
sname = 'mr_sim';
trace_dir = fullfile(work_dir,'results',sname,'dwi_trace');
adc_dir = fullfile(work_dir,'results',sname,'adc');
bids_dir = fullfile(work_dir,'data','bids-cns-mrl','dataset-sim');

nom_bvals = 0:200:1000; % nominal b-values
bval_indices = true(1,6); % b=[0,200,400,600,800,1000]
nsa = [1,1,1,2,2,3]; % number of averages for option "average high b = yes"

res_ingenia = [1.14,1.45,5];
res_achieva = [1.5,1.52,4];

% loop subjects
n_sub = length(subjects);
for ix_sub = 1:n_sub
    % get subject
    subject = subjects{ix_sub};
    
    % get brain mask filename
    fn_mask = get_fn_brainmask(work_dir,subject);
    
    % get sessions
    sessions = get_sessions(fullfile(trace_dir,['sub-',subject]));
    n_ses = length(sessions);
    
    % loop sessions
    for ix_ses = 1:n_ses
        session = sessions{ix_ses};
        
        % declare path to trace DWI
        dwi_dir = fullfile(trace_dir,['sub-',subject],['ses-',session]);
        [fn_dwi,lab_dwi] = get_keyed_fn(dwi_dir,'dwi','.nii.gz');
        assert(length(fn_dwi)==1,'The searched folder does not contain exactly one DWI: %s\n',dwi_dir);
        fn_dwi = fn_dwi{1};
        lab_dwi = lab_dwi{1};
        
        % declare path to output ADC map
        out_dir = fullfile(adc_dir,['sub-',subject],['ses-',session]);
        fn_out = fullfile(out_dir,strrep(lab_dwi,'dwi_trace','adc.nii.gz'));        
                        
        % do ADC fit
        if exist(fn_out,'file')
            fprintf('ADC map already exists: %s\n',fn_out);
        elseif strcmp(subject,'M141')&&strcmp(session,'sim003')
            fprintf('Skipping sub-M141_ses-sim003; 7-bvalue scan\n');
        else                                 
            
            % create output directory
            if ~exist(out_dir,'dir')
                mkdir(out_dir);
            end
            
            % read b-values
            if strcmp(subject,'M122')&&strcmp(session,'sim004')
                run = 'run-01_';
            else
                run = '';
            end
            fn_bval = fullfile(bids_dir,['sub-',subject],['ses-',session],'dwi',...
                sprintf('sub-%s_ses-%s_%sdwi.bval',subject,session,run));
            bvals = dlmread(fn_bval);
            n_b = length(bvals);
            
            % determine parameters based on scanner
            fn_json = strrep(fn_bval,'.bval','.json');
            s_dwi = spm_jsonread(fn_json);
            if strcmp(s_dwi.ManufacturersModelName,'Achieva')
                all_bvals = bvals([1,2:3:n_b]);
                res = res_achieva;
            elseif strcmp(s_dwi.ManufacturersModelName,'Ingenia')
                all_bvals = bvals;
                res = res_ingenia;
            else
                error('ManufacturersModelName is not {Achieva,Ingenia}');
            end                        
            assert(all(all_bvals==nom_bvals),'all_bvals not equal to nominal b-values'); 
            
            % fit ADC and write
            create_adc_from_dwi(fn_dwi,all_bvals,bval_indices,fn_out,...
                'Method','WLLS2',...
                'Averages',nsa,...
                'ResampleResolution',res,...
                'MaskPath',fn_mask);
            fprintf('ADC map created: %s\n',fn_out);            
        end
    end
end

end