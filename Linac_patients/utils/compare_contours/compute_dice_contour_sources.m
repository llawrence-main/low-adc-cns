function compute_dice_contour_sources(root,subjects,cont1,cont2,varargin)
% compute the Dice score between contours for all sessions in a given
% contour source
% args:
%     root (str): project root
%     subjects (cell): list of subjects
%     cont1, cont2 (struct): contour source structures. Fields:
%         - source (str): name of contour source
%         - labels (cell): contour labels
%     IncludePlan (bool, optional): including planning contour as part of
%     contour 1 filenames?
%     UseCoreg (bool, optional): use co-registered contours?
% notes:
%     - the sessions are pulled from the source of cont1

% parse inputs
parser = inputParser;
addParameter(parser,'IncludePlan',false);
addParameter(parser,'UseCoreg',false);
parse(parser,varargin{:});
include_plan = parser.Results.IncludePlan;
use_coreg = parser.Results.UseCoreg;

fprintf('computing Dice scores: %s vs. %s\n',cont1.source,cont2.source);

% declare parameters
roi_dir = fullfile(root,'interim','derivatives',get_source_folder(cont1.source,use_coreg));
session_plan = 'GLIO01';

% initialize table
out_filename = fullfile(root,'interim','dice_contour_sources.csv');
var_names = {'Subject','string';...
    'Session','string';...
    'Contour1','string';...
    'Contour2','string';...
    'Dice','double'};
if exist(out_filename,'file')
    T = readtable(out_filename);
else
    T = table('Size',[0,size(var_names,1)],...
        'VariableNames',var_names(:,1),...
        'VariableTypes',var_names(:,2));
end

% compute Dice scores
n_sub = length(subjects);
for ix_sub = 1:n_sub
    
    subject = subjects{ix_sub};
    
    sessions = get_sessions(fullfile(roi_dir,['sub-',subject]));
    n_ses = length(sessions);
    
    for ix_ses = 1:n_ses
        
        session = sessions{ix_ses};
        
        loc = strcmp(T.Subject,subject)&strcmp(T.Session,session);
        if any(loc)
            fprintf('Dice score already computed: sub-%s_ses-%s\n',subject,session);
        else
                                    
            % get contour filenames            
            fns_1 = contour_filenames_by_source(root,subject,session,cont1.source,cont1.labels,...
                'UseCoreg',use_coreg);
            if include_plan
                fns_1 = [fns_1,...
                    contour_filenames_by_source(root,subject,session_plan,cont1.source,cont1.labels,...
                    'UseCoreg',use_coreg)];
                t_labels1 = [cont1.labels,strcat(cont1.labels,'-plan')];
            else
                t_labels1 = cont1.labels;
            end
            fns_2 = contour_filenames_by_source(root,subject,session,cont2.source,cont2.labels,...
                'UseCoreg',use_coreg);
            t_labels2 = cont2.labels;
            
            % compute pairwise Dice
            n1 = numel(fns_1);
            n2 = numel(fns_2);
            
            if (n1>0) && (n2>0)
                fprintf('computing Dice scores: sub-%s_ses-%s\n',subject,session);
                dices = NaN(n1,n2);
                label_pairs = cell(n1,n2,2);
                for ix_c1 = 1:n1
                    for ix_c2 = 1:n2
                        fn1 = fns_1{ix_c1};
                        fn2 = fns_2{ix_c2};
                        fprintf('\tfn1: %s\n\tfn2: %s\n',fn1,fn2);
                        dices(ix_c1,ix_c2) = compute_dice(fn1,fn2);
                        label_pairs{ix_c1,ix_c2,1} = t_labels1{ix_c1};
                        label_pairs{ix_c1,ix_c2,2} = t_labels2{ix_c2};
                    end
                end
                
                % write to table
                nrow = numel(dices);
                col_subject = cellstr(repmat(subject,nrow,1));
                col_session = cellstr(repmat(session,nrow,1));
                col_lab1 = label_pairs(:,:,1);
                col_lab1 = strcat(cont1.source,'-',col_lab1(:));
                col_lab2 = label_pairs(:,:,2);
                col_lab2 = strcat(cont2.source,'-',col_lab2(:));
                col_dice = dices(:);
                t = table(col_subject,col_session,col_lab1,col_lab2,col_dice,...
                    'VariableNames',var_names(:,1));
                T = [T;t];
            end
        end
        
        writetable(T,out_filename);
        
    end            
end

end

