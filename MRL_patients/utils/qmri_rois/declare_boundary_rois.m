function bound_rois = declare_boundary_rois()
% returns a structure with information on the boundary ROIs for the low-ADC
% region

bound_rois = struct;
bound_rois.types = {'contours','aiaa','aiaa_tc'};
bound_rois.names = {'GTV','tumourcore','tumourcore'};
bound_rois.onames = {'','_aiaa','_aiaa_tc'};

end