function subjects = get_high_grade_subjects()
% Returns a list of subjects with high-grade glioma between M001 and M126
% Returns
%     subjects: list of subjects

% read table of patient properties
t = readtable('/home/llawrence/Documents/dwi_response/data/momentum_tracker_full.xlsx',...
    'Range','B3:T232');
loc_high = strcmp(t.Grade,'III')|strcmp(t.Grade,'IV');
subjects = t.StudyID(loc_high);

% subjects to exclude
exclude = {'M007',... % TX start date is N/A,
    'M023',... % No DWI
    'M027',... % No DWI    
    'M028',...% TX start date is N/A
    'M033',... % No DWI
    'M038',... % TX start date is after first MRL session
    'M047',... % No DWI
    'M058',... % No DWI
    'M067',... % No DWI
    'M126',...% TX start date is N/A
    'M130',... % No DWI
    'M134',... % No DWI
    'M135',... % No DWI
    'M137',... % No DWI
    'M138',... % Tx start date is N/A
    };
loc = false(numel(subjects),1);
for ix = 1:numel(exclude)
    loc = strcmp(subjects,exclude{ix})|loc;
end
subjects = subjects(~loc);

end