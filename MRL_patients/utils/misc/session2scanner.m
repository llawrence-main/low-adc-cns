function scanner = session2scanner(session)
% returns the scanner associated with the given session
% args:
%     session (str): session name
% returns:
%     scanner (str): scanner name

if contains(session,'MRL')
    scanner = 'mrl';
elseif contains(session,'sim')
    scanner = 'sim';
else
    error('Session is neither MRL nor MR-sim: %s',session);
end


end