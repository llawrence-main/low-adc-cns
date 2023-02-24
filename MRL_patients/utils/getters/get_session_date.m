function date = get_session_date(subject,session)
%DATE = GET_SESSION_DATE(SUBJECT,SESSION) returns the date of a scan for
%SUBJECT and SESSION.

bids_dir = '/scratch/alau/data/MRL/dwi/bids-cns-mrl/dataset-mrl';
json_filenames = dir(fullfile(bids_dir,subject,session,'anat','*.json'));
assert(~isempty(json_filenames),'no .json files found');
fname = fullfile(json_filenames(1).folder,json_filenames(1).name);
fid = fopen(fname); 
raw = fread(fid,inf); 
str = char(raw'); 
fclose(fid); 
val = jsondecode(str);
dt = val.AcquisitionDateTime;
dt = erase(dt(1:10),'-');
date = datetime(dt,'InputFormat','yyyyMMdd');
end