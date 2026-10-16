function C = refine_circles(gray, C)
%REFINE_CIRCLES  Affine centre et rayon de chaque cercle sur le vrai bord de la piece.
%   C = REFINE_CIRCLES(gray, C)   C : K x >=3 [cx cy r ...]
%
%   Pourquoi : une piece a un liseré en relief et des gravures. Le contour
%   le plus fort n'est donc pas toujours le bord exterieur, et la Hough
%   peut se caler sur un cercle interieur (erreur de 1 a 2 mm, qui suffit a
%   confondre 10 c et 20 c). On procede en trois temps :
%   1) 180 rayons de 0.8 r a 1.2 r, profil d'intensite par interpolation ;
%   2) derivee radiale signee (signe = fond plus clair ou plus sombre que la
%      piece), mediane sur les rayons, on retient le pic le plus EXTERIEUR
%      parmi les pics forts ;
%   3) bord exact sur chaque rayon pres de ce pic, puis ajustement d'un
%      cercle par moindres carres (methode de Kasa) avec rejet des points
%      aberrants (ombre portee, piece voisine qui touche).

th = linspace(0, 2*pi, 181); th(end) = [];
for i = 1:size(C, 1)
    cx = C(i, 1); cy = C(i, 2); r = C(i, 3);
    rs = 0.8*r : 0.25 : 1.2*r;
    X = cx + cos(th') * rs;               % 180 x numel(rs)
    Y = cy + sin(th') * rs;
    P = interp2(gray, X, Y, 'linear', NaN);
    P = fillmissing_rows(P);
    sgn = sign(median(reshape(P(:, end-3:end), [], 1)) - median(reshape(P(:, 1:4), [], 1)));
    if sgn == 0, sgn = 1; end
    Dv = sgn * diff(P, 1, 2) / 0.25;      % derivee radiale signee
    g = conv(median(Dv, 1), ones(1, 3)/3, 'same');
    lm = find(g(2:end-1) >= g(1:end-2) & g(2:end-1) >= g(3:end)) + 1;
    cand = lm(g(lm) >= 0.6 * max(g));
    if isempty(cand), continue; end
    rmid = (rs(1:end-1) + rs(2:end)) / 2;
    r1 = rmid(max(cand));

    % bord individuel de chaque rayon, dans une fenetre autour de r1
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
        xc = sol(1)/2; yc = sol(2)/2;
        rr = sqrt(sol(3) + xc^2 + yc^2);
        res = abs(hypot(px - xc, py - yc) - rr);
        mad = median(res(keep)) + 1e-9;
        keep = res < 3 * 1.4826 * mad + 0.5;
    end
    C(i, 1:3) = [xc yc rr];
end
end

function P = fillmissing_rows(P)
% Remplace les NaN (rayons sortant de l'image) par la derniere valeur valide
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
