%% clear
clc
clear all
close all

%% create simulated data
f = 0.2;
S0 = 1;
D = 5e-3;
Ds = 100e-3;
b = [0:10:100,200:200:800];
model =@(b) S0*((1-f)*exp(-D*b)+f*exp(-Ds*b));
S = reshape(model(b),[],1);

%% do fit
b_thresh = 150;
fits = do_fit_ivim_fD(b,b_thresh,S);

%% display results
disp(fits);

%% make plot
figure(1);
semilogy(b,S,'o');
hold on
semilogy(b,fits.adc_preds,'-k');
hold off
xlabel('b-value');
ylabel('signal');