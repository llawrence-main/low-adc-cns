function sessions = get_sessions(folder)
% Return a list of sessions
% Arguments
%     folder: folder with BIDS-style sessions
% Returns
%     sessions: list of sessions

d = dir(fullfile(folder,'ses-*'));
n = numel(d);
sessions = cell(1,n);
for ix = 1:n
    sessions{ix} = erase(d(ix).name,'ses-');
end
end