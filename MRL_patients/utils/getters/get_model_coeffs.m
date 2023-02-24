function p = get_model_coeffs(work_dir)
% returns the polynomial model coefficients for predicting MR-sim ADC
% values from MR-Linac ADC values

fn = fullfile(work_dir,'results','adc_bias_correction','model_coeffs.csv');
if ~exist(fn,'file')
    fprintf('Model coefficient file does not exist; did you run buildBiasModel.R?:\n\t%s\n',fn);
else
    t = readtable(fn);
    p = struct;
    for ix = 1:numel(t.Scanner)
        p.(t.Scanner{ix}) = fliplr(t{ix,2:end});
    end
end

end