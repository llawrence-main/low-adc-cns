function folder = get_source_folder(source,use_coreg)
% returns the folder associated with a given contour source
% args:
%     source (str): manual or AIAA source 
%     use_coreg (bool): use co-registered contours?
% returns:
%     folder (str): folder housing contours

switch source
    case 'manual'
        folder = 'contours';
    case 'aiaa'
        folder = 'aiaa_seg';
end

if use_coreg
    folder = strcat('coreg_',folder);
end


end