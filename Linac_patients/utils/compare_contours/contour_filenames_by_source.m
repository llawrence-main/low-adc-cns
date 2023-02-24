function fns = contour_filenames_by_source(root,subject,session,source,labels,varargin)
% returns the filenames of the contours from a given source
% args:
%     root (str): project root
%     subject (str): subject name
%     session (str): session name
%     source (str): name of contour source
%     labels (cell): list of contour labels
%     UseCoreg (str,optional): use co-registered contours?
% returns:
%     fns (cell): list of contour filenames that exist

% parse inputs
parser = inputParser;
addParameter(parser,'UseCoreg',false);
parse(parser,varargin{:});
use_coreg = parser.Results.UseCoreg;

% declare folder with contours
folder = get_source_folder(source,use_coreg);

% declare suffix for filename
if use_coreg
    coreg_entity = 'desc-coreg_';
else
    coreg_entity = '';
end

parent = fullfile(root,'interim','derivatives');
fns = cellfun(@(x)fullfile(parent,folder,['sub-' subject],['ses-' session],'anat',...
    sprintf('sub-%s_ses-%s_label-%s_%smask.nii.gz',subject,session,x,coreg_entity)),labels,...
    'UniformOutput',false);
loc = cellfun(@(x)exist(x,'file')>0,fns);
fns = fns(loc);

end
