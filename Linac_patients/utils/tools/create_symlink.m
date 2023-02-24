function create_symlink(src,dest)
%{
Creates a symbolic link pointing from dest to src
IN
src: existing file
dest: symlink path
OUT
%}
command = ['ln -sfn ' src ' ' dest];
disp(command);
system(command);
end