function fn_enh = get_enh_fn(work_dir,subject,timepoint)
% Returns the filename of the T1 enhancing ROI
% Arguments
%     work_dir: working directory
%     subject: subject
%     timepoint: time point of scan
% Returns
%     fn_enh: filename of enhancing volume

assert(any(strcmp(timepoint,{'plan'})),'timepoint must be one of {plan}');

fn_enh = '';
switch timepoint
    case 'plan'
        if strcmp(subject,'M020')
            session = 'sim002';
        else
            session = 'sim001';
        end
        fn_enh = fullfile(work_dir,'results','rois_pjm',['sub-',subject],...
            ['ses-',session],sprintf('sub-%s_ses-%s_t1_enh.nii.gz',subject,session));
end

assert(exist(fn_enh,'file')>0,'T1 enhancing ROI does not exist: %s',fn_enh);

end
