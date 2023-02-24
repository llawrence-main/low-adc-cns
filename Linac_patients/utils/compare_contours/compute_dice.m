function score = compute_dice(fn1,fn2)
% computes the Dice score between two contours stored as niis
% args:
%     fn1 (str): filename of contour 1
%     fn2 (str): filename of contour 2; is resampled to space of contour 1 
% returns:
%     score (double): Dice score


nii1 = nii_tool('load',fn1);
nii2 = nii_xform(fn2,nii1);

img1 = nii1.img>0;
img2 = nii2.img>0;

score = dice(img1,img2);

end