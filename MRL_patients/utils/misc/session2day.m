function day = session2day(work_dir,scanner,subject,sessions)
% Convert the session to treatment day for a given subject
% Arguments
%     work_dir: working directory
%     scanner: scanner name (mrl or sim)
%     subject: subject name
%     sessions: list of sessions
% Returns
%     day: list of treatment days

% parse inputs
assert(any(strcmp(scanner,{'mrl','sim'})),'scanner must be one of {mrl,sim}');

% put char into cell
if ischar(sessions)
    sessions = {sessions};
end

% load table
fn = fullfile(work_dir,'results','metadata',sprintf('session_day_%s.csv',scanner));
t = readtable(fn);

% loop sessions
n_ses = length(sessions);
day = NaN(1,n_ses);
for ix_ses = 1:n_ses
    session = sessions{ix_ses};
    loc = strcmp(subject,t.Subject) & strcmp(session,t.Session);
    ix = find(loc);
    assert(length(ix)<=1,'more than one subject-session pairing found');
    if sum(loc)==0
        day = NaN;
    else
        day(ix_ses) = t.TxDay(ix);
    end
end
end