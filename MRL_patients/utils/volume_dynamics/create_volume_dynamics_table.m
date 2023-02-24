function create_volume_dynamics_table(work_dir,subjects,force,varargin)
% Creates a table with metrics that characterize the dynamics of ROIs
% Arguments
%     work_dir (str): working directory
%     subjects (cell): list of subjects
%     force (cell): list of keys (e.g. MXXX_simYYY); processing is forced for
%     these subject-sessions
%     ADCType (str, optional): ADC map type to use {original, adjusted}
%     ForceSubjects (cell, optional): processing is forced for these
%     subjects
% Returns
%     none

% input parser
iparser = inputParser;
addParameter(iparser,'ADCType','original');
addParameter(iparser,'ForceSubjects',{});
parse(iparser,varargin{:});
adc_type = iparser.Results.ADCType;
force_subjects = iparser.Results.ForceSubjects;
validatestring(adc_type,{'original','adjusted'});

% declare parameters
scanners = {'mr_linac','mr_sim'};
scanners_short = {'mrl','sim'};
n_scanners = length(scanners);
out_dir = fullfile(work_dir,'results','volume_dynamics');
fig_dir = fullfile(out_dir,'verify');
if ~exist(fig_dir,'dir')
    mkdir(fig_dir);
end
bound_type = 'definitive'; 

switch adc_type
    case 'original'
        roi_dirnames = {'qmri_rois','qmri_rois'};
        adc_dirnames = {'adc','adc'};
        suffix = '';
    case 'adjusted'
        roi_dirnames = {'qmri_rois_adc_adjusted','qmri_rois'};
        adc_dirnames = {'adc_adjusted','adc'};        
        suffix = '_adc_adjusted';
end
      
% declare output table
fn_table = fullfile(out_dir,sprintf('dyn_table%s.csv',suffix));
if exist(fn_table,'file') && isempty(force)
    fprintf('Table of volume dynamics already exists: %s\n',fn_table);
else
    
    % load output data structure
    fn_data = fullfile(out_dir,sprintf('dyn_data%s.mat',suffix));
    if exist(fn_data,'file')
        load(fn_data,'out'); % out.MXXX_sesYYY contains the output data for subject MXXX and session sesYYY
    else
        out = struct;
    end
    
    % loop scanners
    for ix_scan = 1:n_scanners
        
        scanner = scanners{ix_scan};
        scanner_short = scanners_short{ix_scan};
        adc_dir = fullfile(work_dir,'results',scanner,adc_dirnames{ix_scan});
        roi_dir = fullfile(work_dir,'results',scanner,roi_dirnames{ix_scan});
        
        % loop subjects
        n_sub = length(subjects);
        for ix_sub = 1:n_sub
            
            subject = subjects{ix_sub};
            
            % get list of sessions
            sessions = get_sessions(fullfile(adc_dir,['sub-',subject]));
            days = session2day(work_dir,scanner_short,subject,sessions);
            n_ses = length(sessions);
                        
            % initialize figures
            fnos = 100 + [1:5];
            for fno = fnos
                figure(fno);
                set(fno,'color','w');
                clf;
            end                        
            
            % dimensions of subplot
            if strcmp(scanner,'mr_linac')
                n_row = 5;
                n_col = 6;
            else
                n_row = 1;
                n_col = 6;
            end
            
            % loop sessions
            for ix_ses = 1:n_ses
                session = sessions{ix_ses};
                
                
                % declare key (field name) of structure
                key = strcat(subject,'_',session);
                if isfield(out,key) && ~any(strcmp(key,force)) && ~any(strcmp(subject,force_subjects))
                    fprintf('Volume dynamic data already exists: %s\n',key);
                    make_fig = false;
                else
                    
                    make_fig = true;
                    
                    fprintf('Creating volume dynamic data: %s\n',key);
                    
                    % add day to output structure
                    out.(key).Day = days(ix_ses);                    
                    
                    % get ROI filenames of given session
                    [fns_rois,bound_sessions] = get_fn_lowadc(roi_dir,subject,session);
                    
                    for ix_roi = 1:numel(fns_rois)
                        
                        fn_roi = fns_rois{ix_roi};
                        bound_session = bound_sessions{ix_roi};
                    
                        % compute ROI metrics and store
                        if ~isempty(fn_roi)
                            
                            % intrinsic ROI metrics
                            [vol,nii_roi] = compute_roi_metrics(fn_roi);
                            
                            % save in output structure
                            out.(key).(bound_session).('VolumeLowADC') = vol;
                            
                            % get boundary ROI
                            if strcmp(subject,'M174')
                                roi_names = {'GTV1','GTV2'};
                            else
                                roi_names = 'GTV';
                            end
                            [~,fn_contour] = load_rois(work_dir,subject,bound_session,...
                                bound_type,...
                                roi_names,...
                                'FilenamesOnly',true);
                            
                            % put into cell to handle cases with multifocal
                            % GTVs
                            if ischar(fn_contour)
                                fn_contour = {fn_contour};
                            end
                            
                            % compute volume of boundary ROI and save in output
                            % structure
                            vol_encl = 0;
                            for ix_contour = 1:numel(fn_contour)
                                vol_encl = vol_encl + compute_roi_metrics(fn_contour{ix_contour});
                            end
                            out.(key).(bound_session).('VolumeTumourcore') = vol_encl;
                            
                            % create verification figure
                            
                            % get ADC filename
                            fn_adc = get_keyed_fn(fullfile(adc_dir,['sub-',subject],['ses-',session]),...
                                'adc','.nii.gz');
                            fn_adc = fn_adc{1};
                            
                            % load ADC
                            nii_adc = nii_tool('load',fn_adc);
                            
                            % compute slice
                            slice = max_roi_slice(nii_roi.img,3);
                            
                            % xform boundary ROI to ADC 
                            nii_bound = nii_xform(fn_contour{1},nii_roi);
                            nii_bound.img = nii_bound.img > 0.9;
                            for ix_contour = 2:numel(fn_contour)  
                                nii_tmp = nii_xform(fn_contour{ix_contour},nii_roi);
                                nii_bound.img = nii_bound.img | (nii_tmp.img > 0.9);
                            end
                            
                            % declare ROI array
                            rois = cat(4,nii_roi.img,nii_bound.img);
                            
                            % display ADC map with overlaid contour
                            figure(fnos(ix_roi));
                            subtightplot(n_row,n_col,ix_ses);
                            view_slice(nii_adc,'axial',slice,...
                                'Contours',rois,...
                                'ContourType',{'wash','curve'},...
                                'ContourLineWidths',[1,0.5],...
                                'ContourColors',[1,0,0;0,0,1]);                                                                                    
                        end
                    
                    end
                    
                    % save output structure
                    save(fn_data,'out');
                    
                end
                
            end
            
            % save verification figures
            if make_fig
                for ix_roi = 1:numel(fns_rois)
                    fn_fig = fullfile(fig_dir,sprintf('%s_%s_encl-tc-%s_adc_%s_rois.jpg',subject,scanner_short,bound_sessions{ix_roi},adc_type));
                    export_fig(fnos(ix_roi),fn_fig,'-r300');
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
                t = table({subject},{session},day,entries(ix_ent),metrics(ix_m),val,'VariableNames',{'Subject','Session','Day','TumourcoreSession','Metric','Value'});
                T = [T;t];
            end
        end
    end
    
end
end
    
    