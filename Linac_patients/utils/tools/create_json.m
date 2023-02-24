function create_json(fn_json,data)
% creates .json sidecar
% args:
%     fn_json (str): filename of json
%     data (struct): structure to be turned in .json file

spm_jsonwrite(fn_json,data);

end