function create_missingness_table(work_dir,subjects)
% creates a table showing missing data
% args
%     work_dir: working directory
%     subjects: subject list


n_sub = length(subjects);

column_names = {'HasMRsimCoreg',...
    'HasContours',...
    'HasMRsimADCmaps',...
    'HasAIAAseg'};
folders = {fullfile(work_dir,'results','mr_sim','coreg'),...
    fullfile(work_dir,'results','mr_linac','contours'),...
    fullfile(work_dir,'results','mr_sim','adc'),...
    fullfile(work_dir,'results','mr_sim','aiaa_seg')};
n_cols = length(column_names);

T = table;
for ix_col = 1:n_cols
    info = cellstr(spm_select('List',folders{ix_col},'dir','sub'));
    info = erase(info,'sub-');
    
    col = zeros(n_sub,1);
    for ix_sub = 1:n_sub        
        if any(contains(info,subjects{ix_sub}))
            col(ix_sub) = 1;
        end
    end
    t = table(col,'VariableNames',column_names(ix_col));
    T  = [T,t];
end
    

% % co-registered MR-sim scans?
% coreg = cellstr(spm_select('List',,'dir','sub'));
% coreg = erase(coreg,'sub-');
% has_coreg = zeros(n_sub,1);
% 
% % contours?
% contours = cellstr(spm_select('List',,'dir','sub'));
% contours = erase(contours,'sub-');
% has_contours = zeros(n_sub,1);
% 
% for ix_sub = 1:n_sub
%     subject = subjects{ix_sub};
%     if any(contains(coreg,subject))
%         has_coreg(ix_sub) = 1;
%     end
%     
%     if any(contains(contours,subject))
%         has_contours(ix_sub) = 1;
%     end
% end
% 
% T = table(subjects,has_coreg,has_contours,...
%     'VariableNames',{'Subject','HasMRsimCoreg','HasContours'});
T = [table(subjects,'VariableName',{'Subject'}),T];
fn = fullfile(work_dir,'results','missingness','dwi_missingness.csv');
writetable(T,fn);
fprintf('table of DWI data missingness created: %s\n',fn);

end