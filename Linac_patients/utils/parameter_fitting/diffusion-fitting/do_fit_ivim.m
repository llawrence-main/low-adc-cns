function out = do_fit_ivim(bvals,dwi,varargin)
% does nonlinear IVIM model fitting
% args
%     bvals (vector): b-values
%     dwi (matrix): signal data size b-values x voxels
%     method (str, optional): fitting method to use (default='full')
% returns
%     out (struct): structure with results of fitting

% parser
ip = inputParser;
addParameter(ip,'method','full');
addParameter(ip,'Ds',[]);
parse(ip,varargin{:});
method = ip.Results.method;
Ds_fix = ip.Results.Ds;
validatestring(method,{'full','Ds_fixed'});
if strcmp(method,'Ds_fixed')
    assert(~isempty(Ds_fix),'if using Ds_fixed method, need to provide Ds value');
end

% preprocess arguments
if isvector(dwi)
    dwi = reshape(dwi,[],1);
end
bvals = reshape(bvals,[],1);

% normalize signals
norm_vals = dwi(1,:);
dwi = dwi./norm_vals;

% declare function for call to lsqcurvefit
switch method
    case 'full'        
        lsq_fun =@(x,xdata) lsq_model(xdata,x(1),x(2),x(3),x(4)); % see below for lsq_model        
    case 'Ds_fixed'
        lsq_fun =@(x,xdata) lsq_model(xdata,x(1),x(2),x(3),Ds_fix);                        
end

% loop DWI signals and fit
n_sig = size(dwi,2);
S0 = NaN(1,n_sig);
f = NaN(1,n_sig);
D = NaN(1,n_sig);
Ds = NaN(1,n_sig);
for ix = 1:n_sig
    % get signal
    sig = dwi(:,ix);
    
    % get initial guess from linear f-D fit 
    b_thresh = min(150,bvals(end-1)*0.99);
    lin_fit = do_fit_ivim_fD(bvals,b_thresh,sig);
    f_init = lin_fit.f;
    S_init = 1;
    D_init = lin_fit.D;
    Ds_init = D_init*50;
    [A1_init,A2_init] = p2A(S_init,f_init);
    switch method
        case 'full'
            x0 = [A1_init,A2_init,D_init,Ds_init];
        case 'Ds_fixed'
            x0 = [A1_init,A2_init,D_init];
    end
    
    % do the fit
    x = lsqcurvefit(lsq_fun,x0,bvals,sig);
    
    % extract results
    [S0(ix),f(ix)] = A2p(x(1),x(2));    
    D(ix) = x(3);
    switch method
        case 'full'
            Ds(ix) = x(4);
        case 'Ds_fixed'
            Ds(ix) = Ds_fix;
    end
end

% create output structure
out = struct;
out.S0 = S0.*norm_vals; % undo normalization
out.f = f;
out.D = D;
out.Ds = Ds;
out.preds = ivim_model(bvals,out.S0,out.f,out.D,out.Ds);

end

function vals = lsq_model(b,A1,A2,D,Ds)
% returns the IVIM signal values given coefficient for double-exponential
% model
[S0,f] = A2p(A1,A2);
vals = ivim_model(b,S0,f,D,Ds);
vals = reshape(vals,[],1);
end

function [S0,f] = A2p(A1,A2)
% converts double-exponential coefficient to IVIM coefficients
S0 = A1+A2;
f = A2/S0;
end

function [A1,A2] = p2A(S0,f)
% converts IVIM coefficients to double-exponential coefficients
A1 = S0*(1-f);
A2 = S0*f;
end