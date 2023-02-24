function test_view_slice(name,args,do_fig)
% Function for testing view_slice.m
if do_fig
    h = figure;
    set(h,'name',name);
end
try
    view_slice(args{:});
catch ME
    fprintf('%s: error: %s\n',name,ME.message);
end
end