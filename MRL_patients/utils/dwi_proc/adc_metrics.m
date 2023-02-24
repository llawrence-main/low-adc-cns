function res = adc_metrics(varargin)
% computes the ADC metrics and returns as a table row
% args:
%     cmd (str): command 
%     adc (3D array, optional): ADC map
%     roi (3D array, optional): ROI, must be given if ADC is given
% returns:
%     res (depends on command): 
%         cmd=computeTable -> table with one row having ADC metrics over ROI
%         cmd=blankTable -> blank table
%         cmd=varNamesTypes -> variable names and types

if nargin==1
    cmd = varargin{1};
elseif nargin==3
    cmd = varargin{1};
    adc = varargin{2};
    roi = varargin{3};
else
    error('Must give 1 or 3 arguments')
end

validatestring(cmd,{'computeTable','blankTable','varNamesTypes'});

var_names_types = {...
    'Mean','double';...
    'Median','double';...
    'Q25','double';...
    'Q75','double';...
    'SD','double';...
    'Min','double';...
    'Max','double';...
    };

if strcmp(cmd,'varNamesTypes')
    res = var_names_types;
elseif strcmp(cmd,'blankTable')
    res = table(NaN,NaN,NaN,NaN,NaN,NaN,NaN,...
        'VariableNames',var_names_types(:,1));
elseif strcmp(cmd,'computeTable')
    
    % check inputs
    assert(nnz(roi)>0,'ROI must have at least one non-zero value');
    
    % extract values and discard NaNs
    vals = adc(roi);
    vals = vals(~isnan(vals));
    
    % compute metrics
    res = table(mean(vals),...
        median(vals),...
        quantile(vals,0.25),...
        quantile(vals,0.75),...
        std(vals),...
        min(vals),...
        max(vals),...
        'VariableNames',var_names_types(:,1));

end


end
