function fits = do_fit_ivim_fD(bvals,b_thresh,dwi,varargin)
% Fits a single exponential to DWI for high b-values, then computes blood
% volume fraction for low b-values
% Arguments
%     b: b-values vector
%     b_thresh: threshold b-value for diffusion-dominated region
%     dwi: MR signals matrix
% Parameters
%     ReturnFitModel: (default=false) If true, will return the functions
%     that predict the DWI signal from the model parameters
%     NaNBadFits: (default=true) If true, will set to NaN fits with D<=0 or
%     f<=0 or f>=0.3
%     Method: (default='LLS') Method for fitting monoexponential model to
%     high b-values
%     Averages: (default=[]) Number of averages at each b-value
% Returns
%     fits: struct with fitting outputs
% Notes
%     - relies on do_fit_adc.m to fit the monoexponential model

%% Check inputs
assert(isvector(bvals),'b must be a vector.');
assert(length(bvals)>=4,'Insufficient number of b-values for simple IVIM fit.');
assert(size(dwi,1)==length(bvals),'mr must have length(b) rows.');
assert(isscalar(b_thresh),'b_thresh must be a scalar.');
bvals = reshape(bvals,1,[]);

%% Parse inputs
p = inputParser;
addParameter(p,'ReturnFitModel',false);
addParameter(p,'NaNBadFits',true);
addParameter(p,'Method','LLS');
addParameter(p,'Averages',[]);
parse(p,varargin{:});

if size(dwi,2)>0
    %% Fit exponential to mr signal in b>b_thresh region
    % Extract diffusion-dominated data
    b_diff_locs = bvals>b_thresh;
    assert(nnz(b_diff_locs)>=2,'Insufficient number of b-values in diffusion region.');
    b_diff = bvals(b_diff_locs);
    mr_diff = dwi(b_diff_locs,:);
    
    % Do ADC fit and extract
    averages = p.Results.Averages;
    if ~isempty(averages)
        averages = averages(b_diff_locs);
    end
    
    adc_fits = do_fit_adc(b_diff,mr_diff,...
        'Method',p.Results.Method,...
        'Averages',averages);
    D = adc_fits.D;
    A = adc_fits.S0;   
    
    %% Output fit results
    % Compute f
    f = 1 - A./dwi(1,:);
    
    % Set bad fits to NaN
    if p.Results.NaNBadFits
        bad_fits_D = D<=0;
        bad_fits_f = (bad_fits_D)|(f<=0)|(f>=0.3);
        f(bad_fits_f) = NaN;
        D(bad_fits_D) = NaN;
    end
    
    % Compute ADC predictions
    adc_preds = A.*exp(-bvals'*D);
else
    f = [];
    D = [];
    adc_preds = [];
end
% Output ivim struct
fits.f = f;
fits.D = D;
fits.adc_preds = adc_preds;
num_fits = size(dwi,2);
if p.Results.ReturnFitModel
    fits.adc_models = cell(1,num_fits);
    for fit_no = 1:num_fits
        fits.adc_models{fit_no} =@(b) A(fit_no)*exp(-D(fit_no)*b);
    end
end
end