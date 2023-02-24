function [tx_date] = get_tx_start_date(subject)
% Returns the start date of radiotherapy for a given patient
% Arguments
%     subject: subject name
% Returns
%     tx_date: treatment start date

% read table of patient properties
t = readtable('/home/llawrence/Documents/dwi_response/data/momentum_tracker_full.xlsx',...
    'Range','B3:T252');
loc = strcmp(t.StudyID,subject);
tx_date = datetime(t.TXSTARTDATE{loc});
end