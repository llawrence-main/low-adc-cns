function vals = ivim_model(b,S0,f,D,Ds)
% returns predicted signal values of IVIM model given parameters

assert(size(b,2)==1);
assert(size(S0,1)==1);
assert(size(f,1)==1);
assert(size(D,1)==1);
assert(size(Ds,1)==1);
vals = S0.*((1-f).*exp(-b.*D) + f.*exp(-b.*Ds));

end