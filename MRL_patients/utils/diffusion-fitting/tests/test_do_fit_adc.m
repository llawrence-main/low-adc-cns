%% Clear
clc
clear all
close all

%% Create fake data
% Declare b-values and averages
b = [0:200:1000]';
Na = [ones(1,3),ones(1,3)];
nb = length(b);

% Initialize seed for reproducibility
rng(0);

% Diffusion parameters
S0 = 1;
D = [0.8,3,5,7]*1e-3;
nv = length(D);

% Noise level
sigma = 1e-2;

% noised signal
% n = ones(length(b),1); % averages for weighted fit
n = [1,2,2,4,4,4]';
S_all = NaN(nb,nv);
for iv = 1:nv
    for ix = 1:nb
         d = makedist('Rician',S0*exp(-b(ix)*D(iv)),sigma/sqrt(n(ix)));
         S_all(ix,iv) = random(d);
    end
end


%% Try fitting

for iv = 1:nv
    S = S_all(:,iv);
    y = log(S);
    X = [ones(length(b),1),-b];
    
    % test LLS fit
    beta = inv(X'*X)*X'*y;
    S0 = exp(beta(1));
    D_man = beta(2);
    [fits,debug] = do_fit_adc(b,S,'Method','LLS','ReturnFitModel',true);
        
    disp('LLS');
    fprintf('D_true: %.10f \t D_fit: %.10f\n',D(iv),fits.D);
    figure(iv);
    semilogy(b,S,'o');
    hold on
    semilogy(b,fits.models{1}(b),'--k');    
    
    % test WLLS fit    
    W = diag(S.^2.*n);
    beta = inv(X'*W*X)*X'*W*y;
    S0 = exp(beta(1));
    D_man = beta(2);
    fits = do_fit_adc(b,S,'Method','WLLS','Averages',n,'ReturnFitModel',true);
    disp('WLLS');
    fprintf('D_true: %.10f \t D_fit: %.10f\n',D(iv),fits.D);
    
    % plot
    semilogy(b,fits.models{1}(b),'--b');    

    
    % test WLLS2 fit
    fits = do_fit_adc(b,S,'Method','WLLS2','Averages',n,'ReturnFitModel',true);
    disp('WLLS2');
    semilogy(b,fits.models{1}(b),'--r');    
    
    % also plot predictions for LLS
    semilogy(b,debug.preds,'om');
    hold off
    
    legend({'data','LLS','WLLS','WLLS2','LLS_preds'},'interpreter','none');
    title(sprintf('D_true = %.5f',D(iv)),'interpreter','none');
    xlabel('b-value');
    ylabel('signal');
    fprintf('D_true: %.10f \t D_fit: %.10f\n',D(iv),fits.D);
    

    
end

%% test fitting all at once
fits = do_fit_adc(b,S_all,'Method','WLLS2','Averages',n);

