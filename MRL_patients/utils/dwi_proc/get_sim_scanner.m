function scanner = get_sim_scanner(work,subject,session)
% returns the scanner used for a given MR-sim session
% args
%     work (str): working directory
%     subject (str): subject name
%     session (str): MR-sim session name
% returns
%     scanner (str): scanner name

folder = fullfile(work,'data','bids-cns-mrl','dataset-sim',['sub-',subject],['ses-',session],'anat');
fns = cellstr(spm_select('FPList',folder,'\.json$'));
fn = fns{1};
s = spm_jsonread(fn);
scanner = s.ManufacturersModelName;

end