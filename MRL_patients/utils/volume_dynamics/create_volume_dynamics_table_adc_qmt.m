function create_volume_dynamics_table(work_dir,subjects,force)
% Creates a table with metrics that characterize the dynamics of ROIs
% Arguments
%     work_dir: working directory
%     subjects: list of subjects
%     force: force processing even if table/matfile exists?
% Returns
%     none

% declare parameters
scanners = {'mr_linac','mr_sim'};
scanners_short = {'mrl','sim'};
n_scanners = length(scanners);
out_dir = fullfile(work_dir,'results','volume_dynamics');
do_hausdorff = false;
verify_hausdorff = false;

if verify_hausdorff
    verify_dir = fullfile(work_dir,'results','mr_linac','hausdorff');
end

% names of ROIs
roi_names = {'low_adc','low_m0b'};
col_names = {'LowADC','LowM0b'};
n_rois = length(roi_names);

% declare output table
fn_table = fullfile(out_dir,'dyn_table.csv');
if exist(fn_table,'file')&&~force
    fprintf('Table of volume dynamics already exists: %s\n',fn_table);
else
    
    % load output data structure
    fn_data = fullfile(out_dir,'dyn_data.mat');
    if exist(fn_data,'file')
        load(fn_data,'out'); % out.MXXX_sesYYY contains the output data for subject MXXX and session sesYYY
    else
        out = struct;
    end
    
    
    % loop scanners
    for ix_scan = 1:n_scanners
        scanner = scanners{ix_scan};
        scanner_short = scanners_short{ix_scan};
        adc_dir = fullfile(work_dir,'results',scanner,'adc');
        qmt_dir = fullfile(work_dir,'results',scanner,'qmt');
        roi_dir = fullfile(work_dir,'results',scanner,'qmri_rois');
    
    
    % loop subjects
    n_sub = length(subjects);
    for ix_sub = 1:n_sub
        
        subject = subjects{ix_sub};
        
        % get list of sessions
        sessions_adc = get_sessions(fullfile(adc_dir,['sub-',subject]));
        sessions_qmt = get_sessions(fullfile(qmt_dir,['sub-',subject]));
        sessions = union(sessions_adc,sessions_qmt);
        days = session2day(work_dir,scanner_short,subject,sessions);
        n_ses = length(sessions);
        
        % declare baseline session
        baseline = sessions{1};
        
        % loop sessions
        for ix_ses = 1:n_ses
            session = sessions{ix_ses};
            
            
            % declare key (field name) of structure
            key = strcat(subject,'_',session);
            if isfield(out,key)&&~force
                fprintf('Volume dynamic data already exists: %s\n',key);
            else
                
                fprintf('Creating volume dynamic data: %s\n',key);
                
                % add day to output structure
                out.(key).Day = days(ix_ses);
                
                % compute ROI metrics and store in output structure
                for ix_roi = 1:n_rois
                    % get ROI filename of given session
                    fn_roi = get_keyed_fn(fullfile(roi_dir,['sub-',subject],['ses-',session]),...
                        roi_names{ix_roi},...
                        '.nii.gz');
                    assert(numel(fn_roi)<=1,'Multiple ROI filenames found for given name: %s %s %s\n',subject,session,roi_names{ix_roi});
                    
                    % get ROI filename of baseline session
                    fn_roi_baseline = get_keyed_fn(fullfile(roi_dir,['sub-',subject],['ses-',baseline]),...
                        roi_names{ix_roi},...
                        '.nii.gz');
                    
                    % compute ROI metrics and store
                    if ~isempty(fn_roi)
                        % intrinsic ROI metrics
                        vol = compute_roi_metrics(fn_roi{1});
                        
                        if do_hausdorff&&(ix_ses > 1)&&strcmp(roi_names{ix_roi},'low_adc')
                            % Hausdorff distance from ROI to baseline ROI
                            [hd,nii_verify] = compute_hausdorff_nii(fn_roi{1},fn_roi_baseline{1},...
                                'xform',true);
                            
                            if verify_hausdorff
                                % save nifti of points used in Hausdorff
                                % distance calculation
                                [~,roi_name] = fileparts(erase(fn_roi{1},'.nii.gz'));
                                fn_verify = fullfile(verify_dir,strcat(roi_name,'_hd.nii.gz'));
                                nii_tool('save',nii_verify,fn_verify);
                            end
                            
                            % save in output structure
                            out.(key).(col_names{ix_roi}).('HausdorffDistance') = hd;
                        end
                        
                        % save in output structure
                        out.(key).(col_names{ix_roi}).('Volume') = vol;                                                
                        
                    end
                end
                
                % save output structure
                save(fn_data,'out');
                
            end
            
        end
        
    end
    
    end
    
    T = datastruct_to_table(out);
    writetable(T,fn_table);
    fprintf('Table of volume dynamics written: %s\n',fn_table);

end

end

function T = datastruct_to_table(out)
% converts the data structure to a table appropriate for writing to csv

keys = fieldnames(out);
n = numel(keys);
T = table;
for ix = 1:n
    key = keys{ix};
    bits = split(key,'_');
    subject = bits{1};
    session = bits{2};
    day = out.(key).Day;
    entries = fieldnames(out.(key));
    for ix_ent = 1:numel(entries)
        if ~strcmp(entries{ix_ent},'Day')
            metrics = fieldnames(out.(key).(entries{ix_ent}));
            for ix_m = 1:numel(metrics)
                val = out.(key).(entries{ix_ent}).(metrics{ix_m});
                t = table({subject},{session},day,entries(ix_ent),metrics(ix_m),val,'VariableNames',{'Subject','Session','Day','ROI','Metric','Value'});
                T = [T;t];
            end
        end
    end
    
end
end
    
    