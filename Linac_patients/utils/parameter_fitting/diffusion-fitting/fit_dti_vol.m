function out = fit_dti_vol(bvals,bvecs,dti)
%FIT_DTI_VOL Fit diffusion tensor model to diffusion MRI data.
%     FIT_DTI_VOL(BVALS,


% Reshape DTI data
sz_dti = size(dti);
n_bvals = sz_dti(4);
dti = reshape(permute(dti,[4,1,2,3]),n_bvals,[]);
n_vox = size(dti,2);

% Fit diffusion tensors
fit = do_fit_dti(bvals,bvecs,dti);

% Compute metrics from diffusion tensors and save in output structure
out = struct;
out.S0 = fit.S0;
V_fieldnames = {'V1','V2','V3'};
L_fieldnames = {'L1','L2','L3'};
for ix = 1:3
    out.(V_fieldnames{ix}) = NaN(3,n_vox);
    out.(L_fieldnames{ix}) = NaN(1,n_vox);
end
out.FA = NaN(1,n_vox);
for ix = 1:n_vox
    [V,Lambda] = eig(fit.D(:,:,ix));
    [L,I] = sort(diag(Lambda));
    V = V(:,I);
    for jx = 1:3
        out.(V_fieldnames{jx})(:,ix) = V(:,jx);
        out.(L_fieldnames{jx})(:,ix) = L(jx);
    end
    out.FA(ix) = sqrt(1/2)*sqrt(((L(1)-L(2))^2+(L(2)-L(3)^2)+(L(3)-L(1))^2)/(sum(L.^2)));
end

% Reshape derived data
out.S0 = reshape(out.S0,sz_dti(1:3));
for ix = 1:3
    out.(V_fieldnames{ix}) = reshape(out.(V_fieldnames{ix})',sz_dti(1:3),3);
    out.(L_fieldnames{ix}) = reshape(out.(L_fieldnames{ix}),sz_dti(1:3));
end
out.FA = reshape(out.FA,sz_dti(1:3));
end