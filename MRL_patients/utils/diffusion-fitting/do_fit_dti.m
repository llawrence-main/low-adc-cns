function out = do_fit_dti(bvals,bvecs,signal,varargin)
%DO_FIT_DTI Fit diffusion tensor to diffusion data.
%     OUT = DO_FIT_DTI(BVALS,BVECS,SIGNAL) fits a diffusion tensor to the
%     data in SIGNAL, assuming each column is a set of acquisitions, the
%     b-values in BVALS and the directions in BVECS using linear
%     least-squares. The output structure OUT contains the fitted b=0
%     signals, the diffusion tensors, and the mean square errors of the
%     fits.
%
%     OUT = DO_FIT_DTI(...,'Method',METHOD) uses the fitting method
%     specified by METHOD, which can be one of 'LLS' (linear
%     least-squares).
% 
%     OUT = DO_FIT_DTI(...,'GradientTensor',L) uses the gradient coil
%     tensors at each voxel, stored in L, to adjust the b-vector before
%     fitting.

% Input parser
iparser = inputParser;
addParameter(iparser,'Method','LLS');
addParameter(iparser,'GradientTensor',[]);
parse(iparser,varargin{:});
method = iparser.Results.Method;
L = iparser.Results.GradientTensor;

% Check inputs
assert(length(bvals)==size(bvecs,2),'The length of bvals must be the same as the number of columns of bvecs.');
assert(size(bvecs,1)==3,'bvecs must have 3 rows.');
assert(length(bvals)==size(signal,1),'the length of bvals must be the same as the number of rows of dti');
n_dirs = length(bvals);
n_vox = size(signal,2);
if ~isempty(L)
    sz_L = size(L);
    assert(all(sz_L(1:2)==[3,3]),'The gradient tensor must be a set of 3 by 3 matrices.');
    assert(sz_L(3)==n_vox,'There must be one gradient tensor for each voxel.');
end

% Do fit
n_params = 7; % {S0, Dxx, Dyy, Dzz, Dxy, Dyz, Dxz}
if strcmp(method,'LLS')
    if isempty(L) % If no gradient tensor passed
        % Build model matrix
        M = NaN(n_dirs,n_params);
        for ix = 1:n_dirs
            b = bvals(ix);
            g = bvecs(:,ix);
            M(ix,:) = [1,-b*g(1)^2,-b*g(2)^2,-b*g(3)^2,-2*b*g(1)*g(2),-2*b*g(2)*g(3),-2*b*g(1)*g(3)];
        end
        % Do linear least-squares fit
        [p,~,mse] = lscov(M,log(signal));
    else % Correct b-vector at each voxel using gradient tensor before fit
        p = NaN(7,n_vox);
        mse = NaN(1,n_vox);
        for ix_vox = 1:n_vox
            % Build model matrix
            M = NaN(n_dirs,n_params);
            for ix_dir = 1:n_dirs
                b = bvals(ix_dir);
                g = L(:,:,ix_vox)*bvecs(:,ix_dir);
                M(ix_dir,:) = [1,-b*g(1)^2,-b*g(2)^2,-b*g(3)^2,-2*b*g(1)*g(2),-2*b*g(2)*g(3),-2*b*g(1)*g(3)];
            end
            % Do linear least-squares fit
            [p(:,ix_vox),~,mse(ix_vox)] = lscov(M,log(signal(:,ix_vox)));
        end
    end
    % Extract parameters
    S0 = exp(p(1,:));
    d = p(2:7,:);    
    D = [d(1,:);d(4,:);d(6,:);d(4,:);d(2,:);d(5,:);d(6,:);d(5,:);d(3,:)];
    D = reshape(D,3,3,n_vox);    
end

% Create output structure
out = struct;
out.S0 = S0;
out.D = D;
out.mse = mse;
end
