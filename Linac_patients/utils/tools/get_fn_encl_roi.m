function fn_roi = get_fn_encl_roi(root,subject,session,encl)
% returns the filename of the enclosing contour for defining the low-ADC
% region
% args:
%     root (str): project root
%     subject (str): subject name
%     session (str): session name
%     encl (str): enclosing ROI name
% returns:
%     fn_roi (str): filename of enclosing ROI

switch encl
    case 'GTVDaily'
        fn_roi = get_fn_contour(root,subject,session,'GTV');
    case 'GTVPlanning'
        fn_roi = get_fn_contour(root,subject,'GLIO01','GTV');
    case 'CTVDaily'
        fn_roi = get_fn_contour(root,subject,session,'CTV');
    case 'CTVPlanning'
        fn_roi = get_fn_contour(root,subject,'GLIO01','CTV');
    case 'AIAAtumourcore'
        fn_roi = get_fn_contour(root,subject,session,'tumourcore');
    otherwise
        error('encl argument is invalid');
end

end