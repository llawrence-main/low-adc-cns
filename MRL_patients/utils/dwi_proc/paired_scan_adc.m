function paired_scan_adc(work)
% computes the median ADC over the tumour core for the MRL and MR-sim (both
% Ingenia and Achieva) for scans taken the same day

fn_out = fullfile(work,'results','adc_bias_correction','paired_MRL_MRsim_ADCs.csv');
if exist(fn_out,'file')
    fprintf('Table of paired-scan ADC values already exists: %s\n',fn_out);
else
    
    %% read list of paired scans
    t_pair = readtable(fullfile(work,'results','adc_bias_correction','paired_scan_list.csv'));
    
    %% loop pairs and get filenames
    t_out = table;
    for ix = 1:size(t_pair,1)
        subject = t_pair.Subject{ix};
        session_mrl = t_pair.SessionMRL{ix};
        session_sim = t_pair.SessionSim{ix};
        
        disp(t_pair(ix,:));
        
        % get ADC filenames
        fn_adc_mrl = spm_select('FPList',fullfile(work,'results','mr_linac','adc',['sub-',subject],['ses-',session_mrl]),'adc\.nii\.gz');
        fn_adc_sim = spm_select('FPList',fullfile(work,'results','mr_sim','adc',['sub-',subject],['ses-',session_sim]),'adc\.nii\.gz');                            
        fns_adcs = {fn_adc_mrl,fn_adc_sim};
        
        % get MR-sim scanner name
        sim_name = get_sim_scanner(work,subject,session_sim);
        
        % get GTV or AIAA tumour core filename
        if strcmp(subject,'M174')
            roi_names = {'GTV1','GTV2'};
        else
            roi_names = 'GTV';
        end
        [~,fn_roi] = load_rois(work,subject,session_sim,'definitive',roi_names,...
            'FilenamesOnly',true);
            
        if isempty(fn_adc_mrl)||isempty(fn_adc_sim)||isempty(fn_roi)
            fprintf('No paired ADC volumes or ROI missing, skipping: %s %s %s\n',subject,session_mrl,session_sim);
        else            
            % compute ADC metrics
            n_scanners = numel(fns_adcs);
            ts = cell(1,n_scanners);
            for ix_scanner = 1:n_scanners
                fn_adc = fns_adcs{ix_scanner};
                
                if iscell(fn_roi)
                    niis_rois = cellfun(@(x)nii_xform(x,fn_adc),fn_roi,'uniformOutput',false);
                    roi = false(size(niis_rois{1}.img));
                    for ix_roi = 1:numel(niis_roi)
                        roi = roi | (niis_rois{ix_roi}.img>0.9);
                    end
                else
                    nii_roi = nii_xform(fn_roi,fn_adc);
                    roi = nii_roi.img>0.9;
                end
                
                adc = nii_tool('img',fn_adc);
                ts{ix_scanner} = adc_metrics('computeTable',adc,roi);
            end
            
            % append to table
            value_mrl = ts{1}.Median;
            value_sim = ts{2}.Median;
            t_app = table({subject},{session_mrl},{session_sim},{sim_name},value_mrl,value_sim,...
                'VariableNames',{'Subject','SessionMRL','SessionSim','SimName','ValueMRL','ValueSim'});
            t_out = [t_out;t_app];
            
        end
        
        
    end
    
    %% write table
    writetable(t_out,fn_out);
    fprintf('Table of paired ADC values written: %s\n',fn_out);

end