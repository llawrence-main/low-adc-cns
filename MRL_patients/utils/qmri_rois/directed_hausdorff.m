function [hd,ix_a,ix_b] = directed_hausdorff(A,B)
%{
Returns the directed Hausdorff distance from point set A to point set B:
sup_(a \in A) (inf_(b \in B) d(a,b))
IN
A: first point set
B: other point set
OUT
hd: directed Hausdorff distance between point sets A and B
ix_a: index of corresponding point in A
ix_b: index of corresponding point in B
%}

% declare parameters
szA = size(A,1);
szB = size(B,1);

% loop points in A
max_dist = -Inf;
for a_point = 1:size(A,1)
    
%     fprintf('point: %u of %u\n',a_point,szA);
    
    % compute distance from point in A to B    
    [min_dist,b_point_min] = min(vecnorm((B-A(a_point,:))'));
    
    % if distance is greater than current maximum, store distance and
    % indices of points
    if min_dist > max_dist
        max_dist = min_dist;
        ix_a = a_point;
        ix_b = b_point_min;
    end
    
end

hd = max_dist;

end