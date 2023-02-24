function folder = get_image_folder(root,subject,timepoint)
% return the source image folder
% args:
%     root (str): project root
%     subject (str): subject name
%     timepoint (str): timepoint
% returns:
%     folder (str): folder name

% load patient list
fn = fullfile(root,'data','metadata','pt_info_GBM_spreadsheet.xlsx');
df = readtable(fn);

% find subject row
id = str2double(erase(subject,'GBM'));
loc = df.id==id;
if isempty(timepoint)
    folder = '';
else
    folder = df.(timepoint){loc};
end

end