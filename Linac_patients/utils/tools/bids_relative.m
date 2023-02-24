function fn_rel = bids_relative(fn,is_raw)
% returns the filename relative to the BIDS root
% args:
%     fn (str): BIDS-style filename
%     is_raw (bool): if true, assumes fn is from raw dataset; otherwise,
%     assumes fn is from derived dataset
% returns
%     fn_rel (str): relative filename

if is_raw
    n = 4;
else
    n = 6;
end
parent = fn;
for i = 1:n
    parent = fileparts(parent);
end
fn_rel = erase(fn,[parent,filesep]);

end