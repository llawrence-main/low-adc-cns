function [gtv_name,ctv_name] = get_contour_names(work_dir,subject)
% Returns the name of the GTV and CTV for the given subject
% Arguments
%     work_dir: working directory
%     subject: subject name
% Returns
%     gtv_name: name of GTV
%     ctv_name: name of CTV

fn_csv = fullfile(work_dir,'data','roi_names.csv');
t = readtable(fn_csv);

loc = strcmp(t.ID,subject);
gtv_name = t.GTV{loc};
ctv_name = t.CTV{loc};

end