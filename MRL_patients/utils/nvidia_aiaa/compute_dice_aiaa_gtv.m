function compute_dice_aiaa_gtv(work_dir,subjects)
% compares the AIAA tumour core at each MR-sim time point to the GTV at
% baseline by computing Dice score
% args:
%     work_dir (str): working directory
%     subjects (cell): list of subjects

out_dir = fullfile(work_dir,'results','aiaa_comparison');

aiaa_names = {'tumourcore'};
n_rois = length(aiaa_names);

bound_rois = declare_boundary_rois();
n_bound = length(bound_rois.types);

for ix_bound = 2:n_bound
    fn_out = fullfile(out_dir,sprintf('%s_gtv_dices.csv',bound_rois.types{ix_bound}));
    

    if exist(fn_out,'file')
        fprintf('file already exists: %s\n',fn_out);
    else
        T = table;
        
        n_subjects = length(subjects);
        dices = NaN(n_subjects,n_rois);
        for ix_sub = 1:n_subjects
            subject = subjects{ix_sub};
            fprintf('computing Dice: %s\n',subject);
            
            sessions = get_sessions(fullfile(work_dir,'results','mr_sim','aiaa_seg',['sub-',subject]));
            n_sessions = length(sessions);
            
            for ix_ses = 1:n_sessions
                
                sim_session = sessions{ix_ses};
                
                ref_session = get_reference_session(work_dir,subject);
                
                [aiaa_rois,fns] = load_rois(work_dir,subject,sim_session,bound_rois.types{ix_bound},aiaa_names);
                if ~isempty(aiaa_rois)
                    gtv = load_rois(work_dir,subject,ref_session,'contours',{'GTV'},...
                        'template',fns{1});
                    for ix_roi = 1:n_rois
                        roi_name = aiaa_names{ix_roi};
                        dice_val = dice(gtv,aiaa_rois(:,:,:,ix_roi));
                        t = table({subject},{sim_session},{roi_name},dice_val,...
                            'VariableNames',{'Subject','Session','AIAAName','DiceWithGTV'});
                        T = [T;t];
                    end
                end
            end
        end
        
        if ~exist(out_dir,'dir')
            mkdir(out_dir);
        end
        writetable(T,fn_out);
        fprintf('table written: %s\n',fn_out);
        
    end
    
end

end