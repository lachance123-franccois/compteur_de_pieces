function [types, pxPerMm, total] = classify_coins(circles, F, pxPerMm)
%CLASSIFY_COINS  Identifie chaque piece a partir de son diametre et de sa couleur.
%   [types, pxPerMm, total] = CLASSIFY_COINS(circles, F, pxPerMm)
%     circles : K x >=3 [cx cy r ...] (pixels)
%     F       : caracteristiques couleur (coin_features)
%     pxPerMm : echelle connue (pixels/mm). Si vide, elle est estimee
%               automatiquement (voir ci-dessous).
%   types    : indice de chaque piece dans coin_table (K x 1)
%   pxPerMm  : echelle utilisee
%   total    : montant total en euros
%
%   Estimation automatique de l'echelle : pour chaque echelle candidate s, on
%   associe chaque piece au diametre officiel le plus proche PARMI les pieces
%   de la bonne couleur, et on mesure l'erreur relative. L'echelle retenue
%   minimise cette erreur. La couleur rend ce probleme bien pose : sans elle,
%   une photo de pieces de 10 c pourrait aussi bien etre une photo de 20 c
%   prise de plus loin.

T = coin_table();
K = size(circles, 1);
if K == 0                                  % aucune piece detectee
    types = zeros(0, 1); total = 0;
    if nargin < 3, pxPerMm = []; end
    return;
end
dPx = 2 * circles(:, 3);

if nargin < 3 || isempty(pxPerMm)
    sGrid = linspace(min(dPx) / 27, max(dPx) / 15, 2000);
    cost = zeros(size(sGrid));
    for j = 1:numel(sGrid)
        [~, err] = assign(dPx / sGrid(j), F.material, T);
        cost(j) = sum(err.^2);
    end
    [~, jBest] = min(cost);
    pxPerMm = sGrid(jBest);
end

[types, ~] = assign(dPx / pxPerMm, F.material, T);
total = sum(T.values(types));
end

function [types, relErr] = assign(dMm, material, T)
K = numel(dMm);
types = zeros(K, 1);
relErr = zeros(K, 1);
for i = 1:K
    cand = find(strcmp(T.material, material{i}));
    if isempty(cand), cand = 1:numel(T.values); end
    [e, j] = min(abs(T.diamMm(cand) - dMm(i)) ./ T.diamMm(cand));
    types(i) = cand(j);
    relErr(i) = e;
end
end