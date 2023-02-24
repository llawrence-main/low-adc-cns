%% Clear
clc
clear all
close all

%% Create fake data
% Declare parameters
n_vox = 3;

% Initialize seed for reproducibility
rng(0);

% Diffusion parameters
S0 = 1;
U = rand(3,3,n_vox);
U(2,1,:) = 0;
U(3,1:2,:) = 0;
for ix = 1:n_vox
    D(:,:,ix) = U(:,:,ix)'*U(:,:,ix)*1e-3;
end

% b-values and b-vectors
A = readmatrix('dti_vectors.txt','NumHeaderLines',1);
bvecs = A(:,1:3)';
bvals = A(:,4)';
loc_keep = bvals > 10;
loc_keep(1) = true;
bvals = bvals(loc_keep);
bvecs = bvecs(:,loc_keep);
n_dir = length(bvals);

% Signal
S = NaN(n_dir,1);
for iv = 1:n_vox
    for ix = 1:n_dir
        S(ix,iv) = S0*exp(-bvals(ix)*bvecs(:,ix)'*D(:,:,iv)*bvecs(:,ix));
    end
end

%% Fit signal
out = do_fit_dti(bvals,bvecs,S);

%% Display fit
disp('D');
disp(D);
disp('Dfit');
disp(out.D);