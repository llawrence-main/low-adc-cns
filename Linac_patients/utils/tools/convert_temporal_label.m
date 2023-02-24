function tgt_val = convert_temporal_label(root,subject,src_lab,src_val,tgt_lab)
% converts a temporal label (session, date, timepoint)
% args:
%     subject (str): subject name
%     src_lab (str): source label
%     src_val (str): source value
%     tgt_lab (str): target label
% returns:
%     tgt_val (str): target value

% check inputs
for lab = {src_lab,tgt_lab}
    assert(any(strcmp(lab,{'Session','Date','Timepoint'})),'source and target labels must be one of {Session,Date,timepoint}');
end

% read table of session-date-day correspondence
df = readtable(fullfile(root,'interim','derivatives','session_dict','session_dict.tsv'),...
    'FileType','text',...
    'Delimiter','tab');

% find row with source value
loc = strcmp(df.Subject,subject)&strcmp(df.(src_lab),src_val);

% check that exactly one row matches
nnz_loc = nnz(loc);
assert(nnz_loc<2,'multiple rows match the given subject and source');

% extract target value
if nnz_loc
    tgt_val = df.(tgt_lab){loc};
else
    tgt_val = '';
end

end