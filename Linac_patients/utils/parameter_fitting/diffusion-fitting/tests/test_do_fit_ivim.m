%% clear
clc
clear all
close all

%% declare parameters
S0 = 1.1;
f = 0.1;
D = 2e-3;
Ds = 30e-3;
bvals = [0:10:100,200:100:1000].';

%% create signal
dwi = ivim_model(bvals,S0,f,D,Ds);

%% do IVIM fit
out = do_fit_ivim(bvals,dwi,'method','full','Ds',0.03);

%% plot signal and fit
fno = 1;
figure(fno);
plot(bvals,dwi,'ok','markersize',16);
hold on
plot(bvals,out.preds,'--k');
hold off
xlabel('b-values');
ylabel('signal');
legend('data','fit');