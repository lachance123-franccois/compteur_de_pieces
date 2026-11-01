function C = refine_circles(gray, C)
% REFINE_CIRCLES Affine le centre et le rayon de chaque cercle sur le vrai bord de la pièce.

    th = linspace(0, 2*pi, 181); 
    th(end) = [];
    
    for i = 1:size(C, 1)
        cx = C(i, 1); cy = C(i, 2); r = C(i, 3);
        rs = 0.8*r : 0.25 : 1.2*r;
        
        X = cx + cos(th') * rs;
        Y = cy + sin(th') * rs;
        
        P = interp2(gray, X, Y, 'linear', NaN);
        P = fillmissing_rows(P);
        
        sgn = sign(median(reshape(P(:, end-3:end), [], 1)) - median(reshape(P(:, 1:4), [], 1)));
        if sgn == 0, sgn = 1; end
        
        Dv = sgn * diff(P, 1, 2) / 0.25;
        g = conv(median(Dv, 1), ones(1, 3)/3, 'same');
        
        lm = find(g(2:end-1) >= g(1:end-2) & g(2:end-1) >= g(3:end)) + 1;
        cand = lm(g(lm) >= 0.6 * max(g));
        if isempty(cand), continue; end
        
        rmid = (rs(1:end-1) + rs(2:end)) / 2;
        r1 = rmid(max(cand));

        win = abs(rmid - r1) <= max(2, 0.06 * r);
        Dw = Dv;
        Dw(:, ~win) = -inf;
        [~, kk] = max(Dw, [], 2);
        re = rmid(kk);
        
        px = cx + re(:) .* cos(th');
        py = cy + re(:) .* sin(th');

        keep = true(numel(th), 1);
        for it = 1:2
            A = [px(keep) py(keep) ones(nnz(keep), 1)];
            b = px(keep).^2 + py(keep).^2;
            sol = A \ b;
            
            xc = sol(1)/2; 
            yc = sol(2)/2;
            rr = sqrt(sol(3) + xc^2 + yc^2);
            
            res = abs(hypot(px - xc, py - yc) - rr);
            mad = median(res(keep)) + 1e-9;
            keep = res < 3 * 1.4826 * mad + 0.5;
        end
        C(i, 1:3) = [xc yc rr];
    end
end

function P = fillmissing_rows(P)
    for k = 1:size(P, 1)
        v = P(k, :);
        bad = isnan(v);
        if all(bad), P(k, :) = 0; continue; end
        if any(bad)
            idx = find(~bad);
            v(bad) = interp1(idx, v(idx), find(bad), 'nearest', 'extrap');
            P(k, :) = v;
        end
    end
end
