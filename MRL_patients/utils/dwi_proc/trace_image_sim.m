function trace_image_sim(work_dir,subjects)
% Computes the trace DW image for MR-sim scans
% Arguments
%     work_dir: working directory
%     subjects: list of subjects
% Returns
%     none

% declare parameters
sname = 'mr_sim';
coreg_dir = fullfile(work_dir,'results',sname,'coreg');
trace_dir = fullfile(work_dir,'results',sname,'dwi_trace');
bids_dir = fullfile(work_dir,'data','bids-cns-mrl');

% loop subjects
n_sub = length(subjects);
for ix_sub = 1:n_sub
    % get subject
    subject = subjects{ix_sub};
    
    % get sessions
    sessions = get_sessions(fullfile(coreg_dir,['sub-',subject]));
    n_ses = length(sessions);
    
    % loop sessions
    for ix_ses = 1:n_ses
        session = sessions{ix_ses};
        
        % declare path to DWI
        dwi_dir = fullfile(coreg_dir,['sub-',subject],['ses-',session]);        
        
        % special cases
        if strcmp(subject,'M122')&&strcmp(session,'sim004')
            search_key = sprintf('sub-%s_ses-%s_run-01_dwi',subject,session);
        else
            search_key = sprintf('sub-%s_ses-%s_dwi',subject,session);
        end
        [fn_dwi,lab_dwi] = get_keyed_fn(dwi_dir,search_key,'.nii.gz');
        assert(length(fn_dwi)<=1,'The searched folder contains more than one DWI: %s\n',dwi_dir);
        
        if isempty(fn_dwi)
            
            warning('The searched folder contains no DWI: %s\n',dwi_dir);
            
        else
            
            fn_dwi = fn_dwi{1};
            lab_dwi = lab_dwi{1};
            
            % declare output filename
            dir_out = fullfile(trace_dir,['sub-',subject],['ses-',session]);
            lab_out = strrep(lab_dwi,'_coreg','_trace');
            fn_out = fullfile(dir_out,[lab_out,'.nii.gz']);
            if exist(fn_out,'file')
                fprintf('Trace DWI already exists: %s\n',fn_out);
            else
                
                if ~exist(dir_out,'dir')
                    mkdir(dir_out);
                end
                
                % read .json file to determine manufacturer
                fn_json = fullfile(bids_dir,'dataset-sim',['sub-',subject],['ses-',session],'dwi',...
                    sprintf('%s.json',search_key));
                s_json = spm_jsonread(fn_json);
                
                if strcmp(s_json.ManufacturersModelName,'Achieva')
                    
                    % load DWI and compute trace image
                    %                 fprintf('loading dwi: %s\n',fn_dwi);
                    nii = nii_tool('load',fn_dwi);
                    sz_nii = size(nii.img);
                    img = NaN([sz_nii(1:3),6]);
                    img(:,:,:,1) = nii.img(:,:,:,1); % copy b=0
                    assert(sz_nii(4)==16,'Number of b-values is not 16: %s\n',fn_dwi);
                    for ix = 2:6
                        ind_s = (ix-2)*3+2;
                        ind_e = ind_s+2;
                        %                     fprintf('ix: %u\tind_s: %u\tind_e: %u\n',ix,ind_s,ind_e);
                        img(:,:,:,ix) = geomean(nii.img(:,:,:,ind_s:ind_e),4); % compute geometric mean of DWIs in 3 directions at same b-value
                    end
                    
                    % save trace image
                    nii.img = img;
                    nii_tool('save',nii,fn_out);
                    fprintf('Saved trace image: %s\n',fn_out);
                    
                elseif strcmp(s_json.ManufacturersModelName,'Ingenia')
                    
                    % create symbolic link to co-registered DWI
                    create_symlink(fn_dwi,fn_out);
                    fprintf('Created symbolic link: %s\n',fn_out);
                    
                else
                    
                    error('ManufacturersModelName is not {Achieva,Ingenia}');
                    
                end
            end        
        end
    end
end