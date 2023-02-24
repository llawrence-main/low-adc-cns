function [rois,fn_rois] = load_rois(work_dir,subject,session,type,roi_names,varargin)
% Returns an array of ROIs
% Arguments
%     work_dir: working directory
%     subject: subject name
%     session: session name
%     type: type of contours
%     roi_names: names of ROIs
% Parameters
%     'Template' (default=[]) template nii or nii filename to resample to
%     'FilenamesOnly' (default=false) if true, will only return filenames
% Returns
%     rois: 4D array of ROIs
%     fn_rois: filenames of ROIs

% Parse inputs
iparser = inputParser;
addParameter(iparser,'Template',[],@isnii);
addParameter(iparser,'FilenamesOnly',false,@islogical);
parse(iparser,varargin{:});
nii_t = iparser.Results.Template;
filenames_only = iparser.Results.FilenamesOnly;
validatestring(type,{'definitive','enhancing','contours','qmri','aiaa','aiaa_tc'});

% Determine ROI filenames
switch lower(type)
    
    case 'definitive' 
                
        if ischar(roi_names)
            roi_names = {roi_names};
        end
        
        n_rois = numel(roi_names);
        fn_rois = cell(n_rois,1);
        
        for ix = 1:n_rois
            roi_name = roi_names{ix};
            validatestring(roi_name,{'GTV','CTV','GTV1','GTV2'});
            
            % retrieve GLIO study contour if it exists
            roi_dir = fullfile(work_dir,'results','mr_sim','glio_contours');
            glio_subject_dir = fullfile(roi_dir,['sub-',subject]);
            search_dir = fullfile(roi_dir,...
                ['sub-',subject],...
                ['ses-',session]);
            
            if strcmp(subject,'M110')&&any(strcmp(session,{'sim001','sim002'}))
                % special cases
                fn_roi_search = fullfile(search_dir,strcat('T1_',roi_name,'_coreg.nii.gz'));
            else
                if exist(search_dir,'dir')
                    % load GLIO contour filename
                    fns_rois_search = cellstr(spm_select('FPList',search_dir,roi_name));
                    assert(length(fns_rois_search)<=1,'multiple ROIs found: %s',search_dir);
                    fn_roi_search = fns_rois_search{1};
                else
                    fn_roi_search = '';
                end
            end
            
            if ~exist(fn_roi_search,'file')
                fn_roi_search = '';
            end
            
            fn_rois{ix} = fn_roi_search;            
        end
        
        if n_rois == 1
            fn_rois = fn_rois{1};
        end
    
    case 'enhancing'
        
        if strcmp(subject,'M020')
            if strcmp(session,'sim002')
                roi_dir = fullfile(work_dir,'results','rois_pjm');
            else
                roi_dir = fullfile(work_dir,'data','rois_lspl');
            end
        else
            if strcmp(session,'sim001')
                roi_dir = fullfile(work_dir,'results','rois_pjm');
            else
                roi_dir = fullfile(work_dir,'data','rois_lspl');
            end
        end
        fn_rois = fullfile(roi_dir,['sub-',subject],['ses-',session],strcat('sub-',subject,'_ses-',session,'_',roi_names,'.nii.gz'));
        
    case 'contours'
        
        % check names
        assert(all(cellfun(@(x)any(strcmp(x,{'GTV','CTV'})),roi_names)),'roi_names must be {GTV,CTV}');
        
        roi_dir = fullfile(work_dir,'results','mr_linac','contours');
        [gtv_name,ctv_name] = get_contour_names(work_dir,subject);
        ix_ctv = find(strcmp(roi_names,'CTV'));
        ix_gtv = find(strcmp(roi_names,'GTV'));
        load_names = cell(1,length(roi_names));
        if ~isempty(ix_gtv)
            load_names{ix_gtv} = gtv_name;
        end
        if ~isempty(ix_ctv)
            load_names{ix_ctv} = ctv_name;
        end
        fn_rois = fullfile(roi_dir,['sub-',subject],['ses-',session],strcat(load_names,'_coreg.nii.gz'));
        
    case 'qmri'
        
        roi_dir = fullfile(work_dir,'results','mr_linac','qmri_rois');
        fn_rois = fullfile(roi_dir,['sub-',subject],['ses-',session],strcat('sub-',subject,'_ses-',session,'_',roi_names,'.nii.gz'));
        
    case {'aiaa','aiaa_tc'}
        
        % determine whether using segmentation of tumourcore, enhancing
        % tumour, whole tumour versus tumour core alone
        if strcmpi(type,'aiaa')
            folder = 'aiaa_seg';
        else
            folder = 'aiaa_seg_tc';
        end
        
        % handle special cases requiring manually-modified ROIs
        sub_man = get_subjects_man_tc(work_dir);
        if any(strcmp(subject,sub_man))
            roi_dir = fullfile(work_dir,'data','aiaa_seg_tc_modified');
        else
            roi_dir = fullfile(work_dir,'results','mr_sim',folder);
        end
        
        % declare ROI filenames
        roi_names = strcat(sprintf('sub-%s_ses-%s_label-',subject,session),roi_names,'_mask.nii.gz');
        fn_rois = fullfile(roi_dir,['sub-' subject],['ses-' session],roi_names);
        
end

if filenames_only
    rois = [];
else
    if all(cellfun(@(x)exist(x,'file')>0,fn_rois))
        
        % Load ROIs
        if isempty(nii_t)
            % load in native space
            imgs = cellfun(@(x)nii_tool('img',x),fn_rois,'UniformOutput',false);
            rois = cat(4,imgs{:});
        else
            % xform to template NIfTI
            niis = cellfun(@(x)nii_xform(x,nii_t),fn_rois,'UniformOutput',true);
            imgs = niis.img;
            rois = cat(4,imgs);
        end
        rois = rois>0.9;
        
    else
        warning('Not all ROIs exist; returning empty array. (%s %s)',subject,session);
        rois = [];
        
    end
end
    
end

function val = isnii(x)

val = false;
if isstruct(x)
    val = isfield(x,'img')&&isfield(x,'hdr');
elseif ischar(x)
    bits = split(x,filesep);
    name = bits{end};
    ext = name(find(name=='.',1):end);
    val = (exist(x,'file')>0)&&(any(strcmp(ext,{'.nii.gz','.nii'})));
end


end