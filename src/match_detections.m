function m = match_detections(circles, types, gt)

    used = false(1, numel(gt.cx));
    m.tp = 0; 
    m.fp = 0; 
    m.correctType = 0; 
    m.radiusErrPx = [];
    
    for i = 1:size(circles, 1)
        d = hypot(gt.cx - circles(i, 1), gt.cy - circles(i, 2));
        d(used) = inf;
        [dmin, j] = min(d);
        
        if ~isempty(j) && dmin < 0.3 * gt.r(j)
            used(j) = true;
            m.tp = m.tp + 1;
            m.correctType = m.correctType + (types(i) == gt.type(j));
            m.radiusErrPx(end+1) = circles(i, 3) - gt.r(j);
        else
            m.fp = m.fp + 1;
        end
    end
    m.fn = sum(~used);
end
