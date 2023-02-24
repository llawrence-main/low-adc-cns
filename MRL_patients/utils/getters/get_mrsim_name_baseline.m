function scanner = get_mrsim_name_baseline(work_dir,subject)
% returns the MR-sim name for the treatment planning scan
% args
%     work_dir (str): working directory
%     subject (str): subject name
% returns
%     scanner (str): scanner name

session = get_mrsim_plan_session(subject);
scanner = get_sim_scanner(work_dir,subject,session);

end