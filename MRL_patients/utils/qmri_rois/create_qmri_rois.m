function create_qmri_rois(work_dir,subjects)
% Creates ROIs from quantitative MRI
% Arguments
%     work_dir: working directory
%     subjects: list of subjects
% Returns
%     none

% loop subjects
n_sub = length(subjects);
for ix_sub = 1:n_sub
    
    subject = subjects{ix_sub};   
    
    % create low-ADC ROIs for MRL with original ADC maps
    create_qmri_rois_subject(work_dir,subject,'original');   
    
    % create low-ADC ROIs for MRL with adjusted ADC maps
%     create_qmri_rois_subject(work_dir,subject,'adjusted');   
    
    % create low-ADC ROIs for MR-sim
    create_qmri_rois_subject_mrsim(work_dir,subject);
    
end