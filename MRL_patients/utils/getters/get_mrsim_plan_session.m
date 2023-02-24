function session = get_mrsim_plan_session(subject)
% returns the MR-sim session that corresponds to planning

if strcmp(subject,'M020')
    session = 'sim002';
else
    session = 'sim001';
end

end