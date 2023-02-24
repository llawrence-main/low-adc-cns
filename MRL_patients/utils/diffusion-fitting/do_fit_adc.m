function [fits,debug] = do_fit_adc(bvals,dwi,varargin)
%DO_FIT_ADC Fit ADC to DWI data
% Arguments:
%     bvals: b-values dwi: DWI signal as array of size [n_bvals,n_voxels]
%
% Parameters:
%     'Method': (default=LLS) fitting method. Can be one of {LLS,WLLS,WLLS2}
%     'NaNBadFits': (default=true) whether to set fits with S0<=0 or D<=0
%     to NaN 'NumberParameters': (default=2) number of parameters to
%     estimate. If 1, only D estimated. 'Averages': (default=[]) number of
%     averages at each b-value. Only used if the fitting method is weighted
%
% Returns:
%     fits: struct containing results of fit
%     debug: struct containing variables useful for debugging

% Check inputs
assert(isvector(bvals)&&all(bvals>=0),'bvals must be a vector of nonnegative floats.');
assert(length(bvals)>=2,'Insufficient number of b-values for ADC fit.');
assert(size(dwi,1)==length(bvals),'dwi must have length(b) rows.');

% declare parameters
bvals = reshape(bvals,1,[]);
nb = length(bvals);
num_fits = size(dwi,2);

% declare debugging structure
debug = struct;

% Input parser
p = inputParser;
addParameter(p,'NaNBadFits',true);
addParameter(p,'ReturnFitModel',false);
addParameter(p,'NumberParameters',2);
addParameter(p,'Method','LLS');
addParameter(p,'Averages',[]);
parse(p,varargin{:});

% check method
method = p.Results.Method;
val_methods = {'LLS','WLLS','WLLS2'}; % linear least-squares, weighted linear least squares, two-step WLLS
assert(any(cellfun(@(x)strcmp(method,x),val_methods)),'method must be one of {LLS, WLLS, WLLS2}');

% get number of averages
Na = p.Results.Averages;
if isempty(Na)
    Na = ones(nb,1);
else
    assert(isvector(Na),'Averages must be a vector');
    assert(length(Na)==length(bvals),'Length of averages and b-values not the same');
    Na = reshape(Na,nb,1);
end

% determine number of parameters
np = p.Results.NumberParameters;
assert((np==1)||(np==2),'Number of estimated parameters must be 1 or 2.');

% declare model matrix
if np == 2
    model_matrix_adc = [-bvals',ones(length(bvals),1)];
elseif np == 1
    model_matrix_adc = -bvals';
end


% do fit according to method
if strcmp(method,'LLS')
    fit_params = do_fit_lls(model_matrix_adc,dwi);
elseif strcmp(method,'WLLS')    
    % compute weights
    Na_mat = repmat(Na,1,size(dwi,2));
    weights = (dwi.^2).*Na_mat;
    debug.weights = weights;
    
    % do weighted fit
    fit_params = do_fit_wlls(model_matrix_adc,dwi,weights);
elseif strcmp(method,'WLLS2')
    % do LLS fit to obtain initial signal estimates
    lls_fit_params = do_fit_lls(model_matrix_adc,dwi);
    
    % compute predictions from LLS
    lls_preds = compute_predictions(bvals,lls_fit_params);
    
    % use predictions to compute weights for weighted fit
    Na_mat = repmat(Na,1,size(dwi,2));
    weights = (lls_preds.^2).*Na_mat;
    loc_nan = all(isnan(lls_preds));
    weights(:,loc_nan) = 1;
    debug.weights = weights;
    
    % do weighted fit
    fit_params = do_fit_wlls(model_matrix_adc,dwi,weights);
end

% extract fitted parameters
if np == 2
    D = fit_params(1,:);
    S0 = exp(fit_params(2,:));
elseif np == 1
    D = fit_params(1,:);
    S0 = ones(size(D));
end

% Predictions
preds = compute_predictions(bvals,fit_params);
residuals = preds-dwi;
debug.preds = preds;

% Compute R2
sos_err = sum(residuals.^2);
sos_tot = sum((dwi-mean(dwi)).^2);
R2 = 1 - sos_err./sos_tot;

% Exclude bad fits
if p.Results.NaNBadFits
    bad_fit = (D <= 0)|(S0 <= 0);
    S0(bad_fit) = NaN;
    D(bad_fit) = NaN;
end

% Output adc struct
fits.D = D;
fits.S0 = S0;
if p.Results.ReturnFitModel
    fits.models = cell(1,num_fits);
    for fit_no = 1:num_fits
        fits.models{fit_no} =@(b) S0(fit_no)*exp(-D(fit_no)*b);
    end
end

end

function fit_params = do_fit_lls(model_matrix,dwi)
%DO_FIT_LLS do linear least-squares fitting for ADC
% Parameters:
%     model_matrix: linear model matrix
%     dwi: array of DWI signal [n_bvals,n_voxels]
% Returns:
%     fit_params: parameters from fit
fit_params = lscov(model_matrix,log(dwi));
end

function fit_params = do_fit_wlls(model_matrix,dwi,weights)
%DO_FIT_WLLS do weighted linear least-squares fitting for ADC
% Parameters:
%     model_matrix: linear model matrix
%     dwi: array of DWI signal [n_bvals,n_voxels]
%     weights: array of weights [n_bvals,n_voxels]
% Returns:
%     fit_params: parameters from fit

np = size(model_matrix,2);
num_fits = size(dwi,2);
fit_params = NaN(np,num_fits);
for ix = 1:num_fits    
    fit_params(:,ix) = lscov(model_matrix,log(dwi(:,ix)),weights(:,ix));    
end
end

function preds = compute_predictions(bvals,fit_params)
%COMPUTE_PREDICTIONS compute the predicted signal values given the ADC fit
%parameters
% Arguments:
%     bvals: b-values
%     fit_params: parameters of fit
% Returns:
%     preds: predicted signal values

np = size(fit_params,1);
if np == 2
    D = fit_params(1,:);
    S0 = exp(fit_params(2,:));
elseif np == 1
    D = fit_params(1,:);
    S0 = ones(size(D));
end

num_obvs = length(bvals);
preds = repmat(S0,num_obvs,1).*exp(-bvals'*D);
end