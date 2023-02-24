function image_handle = view_slice(data,varargin)
%{
Displays an image slice and overlaid contours.
IN
data: data to view: a NIfTI structure, a volume, or a matrix.
view: one of {'sagittal','coronal','axial'}
OUT
image_handle: handle to image
%}

% Input parser -- positional arguments
iparser = inputParser;
view_validation =@(view) assert(any(strcmp(view,{'sagittal','coronal','axial'})),'view must be one of {sagittal,coronal,axial}');
addOptional(iparser,'View','',view_validation); % View: sagittal, coronal, or axial
addOptional(iparser,'SliceNumber',[]); % Number(s) of slice(s) to show

% Input parser -- parameter arguments
addParameter(iparser,'VoxelDimensions',[]); % Dimensions of voxels for scaling
addParameter(iparser,'ColorMap',[]); % Color map for imagesc
addParameter(iparser,'ColorLimits',[]); % Limits of color map
addParameter(iparser,'ShowLabels',false); % Show anatomical labels?
addParameter(iparser,'Contours',[]); % ROIs to show as contours
addParameter(iparser,'ContourColors',[]); % Colors to use for contours
addParameter(iparser,'ContourStyles','-'); % Line style for contours
addParameter(iparser,'ContourLineWidths',2); % Line width for contours
addParameter(iparser,'ContourDimensions',3); % Dimensions of ROIs (2D or 3D)
addParameter(iparser,'ColorbarLabel',''); % Label for color bar
addParameter(iparser,'ContourType','curve'); % Style of contours (curve or wash)
addParameter(iparser,'WashAlpha',0.3); % Transparency for colour wash
parse(iparser,varargin{:});

% Determine if data is a NIfTI struct, a volume, or a matrix
if isstruct(data) && isfield(data,'img') && isfield(data,'hdr')
    datatype = 'nii';
elseif ndims(data)==3
    datatype = 'vol';
elseif ismatrix(data)
    datatype = 'matrix';
else
    assert(false,'data must be a NIfTI structure, a volume, or a matrix.');
end

% Check inputs depending on type of data
if strcmp(datatype,'matrix')
    view = 'axial';
else
    view = iparser.Results.View;
    view_validation(view);
    slice_number = iparser.Results.SliceNumber;
    assert(~isempty(slice_number),'If data is a volume or NIfTI structure, then a slice number must be passed.');
end

% Set orientation of axes
if strcmp(datatype,'nii')
    if data.hdr.pixdim(1)==-1
        ax_or = 'LAS';
    else
        ax_or = 'RAS';
    end
else
    ax_or = 'RAS';
end

% Define slice(s) to show
if strcmp(datatype,'matrix')
    slice = data;
else
    if strcmp(datatype,'nii')
        vol = double(data.img);
    else
        vol = data;
    end
    if strcmp(view,'sagittal')
        slice = squeeze(vol(slice_number,:,:));        
    elseif strcmp(view,'coronal')
        slice = squeeze(vol(:,slice_number,:));
    else
        slice = squeeze(vol(:,:,slice_number));
    end    
end

% Define voxel dimensions
if strcmp(datatype,'nii')
    vox_dims = data.hdr.pixdim(2:4);
else
    vox_dims = iparser.Results.VoxelDimensions;
    if isempty(vox_dims)
        vox_dims = ones(1,3);
    end
end

% Plot slice
slice = permute(slice,[2,1,3]);
image_handle = imagesc(slice);
% if strcmp(view,'sagittal')
%     ax = gca;
%     ax.YDir = 'normal';
%     anatomical_labels_x = {'P','A'};
%     anatomical_labels_y = {'I','S'};
%     daspect_vec = [vox_dims(3),vox_dims(2),1];
% elseif strcmp(view,'coronal')
%     ax = gca;
%     ax.YDir = 'normal';
%     switch ax_or
%         case 'RAS'            
%             ax.XDir = 'reverse';
%         case 'LAS'
%             ax.XDir = 'normal';
%     end
%     anatomical_labels_x = {'L','R'};
%     anatomical_labels_y = {'I','S'};
%     daspect_vec = [vox_dims(3),vox_dims(1),1];
% elseif strcmp(view,'axial')
%     ax = gca;
%     ax.YDir = 'normal';
%     switch ax_or
%         case 'RAS'
%             ax.XDir = 'reverse';
%         case 'LAS'
%             ax.XDir = 'normal';
%     end
%     anatomical_labels_x = {'L','R'};
%     anatomical_labels_y = {'P','A'};
%     daspect_vec = [vox_dims(2),vox_dims(1),1];
% end

% % Anatomical labels
% show_labels = iparser.Results.ShowLabels;
% if show_labels
%     xticks(xlim);
%     yticks(ylim);
%     xticklabels(anatomical_labels_x);
%     yticklabels(anatomical_labels_y);
% else
%     xticks([]);
%     yticks([]);
% end

% Color map
cmap = iparser.Results.ColorMap;
if isempty(cmap)
    colormap(gca,gray(256));
else
    colormap(gca,cmap);    
end

% Color limits
clims = iparser.Results.ColorLimits;
if ~isempty(clims)
    caxis(clims);
end

% Colorbar label
cbar_label = iparser.Results.ColorbarLabel;
if ~isempty(cbar_label)
    hcbar = colorbar;
    ylabel(hcbar,cbar_label);
end

% Contours
contours_passed = iparser.Results.Contours;
contour_dimensions = iparser.Results.ContourDimensions;
contour_styles = iparser.Results.ContourStyles;
contour_line_widths = iparser.Results.ContourLineWidths;
assert(any(contour_dimensions==[2,3]),'Contour dimensions must be 2 or 3.');

style = iparser.Results.ContourType;
if ischar(style)
    style = {style};
end
check_style =@(x) any(strcmp(x,{'curve','wash'}));
assert(all(cellfun(check_style,style)),'ContourType must be one of {curve,wash}');
if any(strcmp(style,'wash'))
    assert(strcmp(view,'axial'),'ContourType=wash only tested with axial view');
    alph = iparser.Results.WashAlpha;
end

% Display contours if nonempty
if ~isempty(contours_passed)    
    if isstruct(contours_passed)&&~(isfield(contours_passed,'img')||isfield(contours_passed,'hdr'))
        % If contours is a structure, with each field a contour
        contour_names = fieldnames(contours_passed);
        num_contours = length(contour_names);
        size_contours = size(contours_passed.(contour_names{1}));
        contours = false([size_contours,num_contours]);
        for contour_no = 1:num_contours
            contour_name = contour_names{contour_no};
            contour = contours_passed.(contour_name);
            if contour_dimensions == 3
                contours(:,:,:,contour_no) = contour;
            else
                contours(:,:,contour_no) = contour;
            end
        end        
    elseif isstruct(contours_passed)&&isfield(contours_passed,'img')&&isfield(contours_passed,'hdr')
        % if contours passed is a nifti
        contours = logical(contours_passed.img);
    else
        % if contours passed is a volume
        contours = contours_passed;        
    end
    if contour_dimensions == 3
        num_contours = size(contours,4);
        % Subset to slice
        if strcmp(view,'sagittal')
            contours_slice = squeeze(contours(slice_number,:,:,:));
        elseif strcmp(view,'coronal')
            contours_slice = squeeze(contours(:,slice_number,:,:));
        elseif strcmp(view,'axial')
            contours_slice = squeeze(contours(:,:,slice_number,:));
        end
    else
        num_contours = size(contours,3);
        contours_slice = contours;
    end
    % Define contour colours
    contour_colors = iparser.Results.ContourColors;
    if isempty(contour_colors)
        contour_colors = prism(num_contours);
    end
    % Define contour styles
    if length(contour_styles)==1
        contour_styles_deal = contour_styles;
        contour_styles = cell(1,num_contours);
        [contour_styles{1:num_contours}] = deal(contour_styles_deal);
    end
    % Define contour line widths
    if length(contour_line_widths)==1
        contour_line_widths = contour_line_widths*ones(1,num_contours);
    end
    % Draw contours
    hold on
    for contour_no = 1:num_contours
        contour = squeeze(contours_slice(:,:,contour_no));
        switch style{contour_no}
            case 'curve'
                contour_boundary_array = bwboundaries(contour); % Trace boundaries with 4-connectivity
                num_blobs = length(contour_boundary_array);
                for blob_no = 1:num_blobs
                    contour_boundary = contour_boundary_array{blob_no};
                    plot(contour_boundary(:,1),contour_boundary(:,2),...
                        'Color',contour_colors(contour_no,:),...
                        'LineStyle',contour_styles{contour_no},...
                        'LineWidth',contour_line_widths(contour_no));
                end
                
            case 'wash'
                wash = repmat(permute(contour_colors(contour_no,:),[3,1,2]),size(contour,1),size(contour,2)); % repeat colour vector
                wash = permute(wash,[2,1,3]); % to match size of slice
                h = imshow(wash);
                alpha_data = double(fliplr(rot90(contour,-1)))*alph;
                set(h,'AlphaData',alpha_data);
        end
                
    end
    hold off
end

% Axis orientation
if strcmp(view,'sagittal')
    ax = gca;
    ax.YDir = 'normal';
    anatomical_labels_x = {'P','A'};
    anatomical_labels_y = {'I','S'};
    daspect_vec = [vox_dims(3),vox_dims(2),1];
elseif strcmp(view,'coronal')
    ax = gca;
    ax.YDir = 'normal';
    switch ax_or
        case 'RAS'            
            ax.XDir = 'reverse';
        case 'LAS'
            ax.XDir = 'normal';
    end
    anatomical_labels_x = {'L','R'};
    anatomical_labels_y = {'I','S'};
    daspect_vec = [vox_dims(3),vox_dims(1),1];
elseif strcmp(view,'axial')
    ax = gca;
    ax.YDir = 'normal';
    switch ax_or
        case 'RAS'
            ax.XDir = 'reverse';
        case 'LAS'
            ax.XDir = 'normal';
    end
    anatomical_labels_x = {'L','R'};
    anatomical_labels_y = {'P','A'};
    daspect_vec = [vox_dims(2),vox_dims(1),1];
end

% Axis scaling
daspect(daspect_vec);

% Anatomical labels
show_labels = iparser.Results.ShowLabels;
if show_labels
    xticks(xlim);
    yticks(ylim);
    xticklabels(anatomical_labels_x);
    yticklabels(anatomical_labels_y);
else
    xticks([]);
    yticks([]);
end
end