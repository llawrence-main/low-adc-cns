function create_tsv(fn,vec)
% writes a vector to a .tsv file
% args:
%     fn (str): .tsv filename
%     vec (vector): vector to write

dlmwrite(fn,vec,'\t');

end