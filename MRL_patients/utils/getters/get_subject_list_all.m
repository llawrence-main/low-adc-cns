function subjects = get_subject_list_all(work_dir)
% returns a list of all subjects with high-grade glioma
% args
%     work_dir (str): working directory
% returns
%     subjects (cell): subject list

fn = fullfile(work_dir,'results','subject_reference_list.csv');
t = readtable(fn);
subjects = t.Subject;

end