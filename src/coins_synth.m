function [img, gt] = coins_synth(nCoins, pxPerMm, imgSize, touching, noiseStd)
%COINS_SYNTH  Image synthetique de pieces en euros avec verite terrain.
%   [img, gt] = COINS_SYNTH(nCoins, pxPerMm, imgSize, touching, noiseStd)
%     nCoins   : nombre de pieces                               [10]
%     pxPerMm  : echelle (pixels par mm)                         [4]
%     imgSize  : [hauteur largeur] en pixels                     [600 800]
%     touching : true pour autoriser des pieces qui se touchent  [false]
%     noiseStd : ecart-type du bruit gaussien (image dans [0,1]) [0.02]
%   img : image RGB double dans [0,1]
%   gt  : structure (cx, cy, r en pixels, type = indice dans coin_table)

if nargin < 1 || isempty(nCoins),   nCoins = 10;        end
if nargin < 2 || isempty(pxPerMm),  pxPerMm = 4;        end
if nargin < 3 || isempty(imgSize),  imgSize = [600 800]; end
if nargin < 4 || isempty(touching), touching = false;   end
if nargin < 5 || isempty(noiseStd), noiseStd = 0.02;    end

T = coin_table();
H = imgSize(1); W = imgSize(2);
[X, Y] = meshgrid(1:W, 1:H);

% Fond : table claire legerement texturee avec un degrade d'eclairage
bg = 0.80 + 0.06 * (X / W) - 0.05 * (Y / H);
tex = conv2(randn(H, W), ones(5)/25, 'same') * 0.04;
img = repmat(bg + tex, 1, 1, 3) .* reshape([1.0 0.98 0.95], 1, 1, 3);

colCopper = [0.72 0.42 0.22];
colGold   = [0.86 0.70 0.32];
colSilver = [0.74 0.74 0.76];

gt.cx = zeros(1, 0); gt.cy = zeros(1, 0); gt.r = zeros(1, 0); gt.type = zeros(1, 0);
maxTry = 5000;
tries = 0;
while numel(gt.cx) < nCoins && tries < maxTry
    tries = tries + 1;
    k = randi(numel(T.values));
    r = T.diamMm(k) / 2 * pxPerMm;
    cx = r + 5 + rand * (W - 2*r - 10);
    cy = r + 5 + rand * (H - 2*r - 10);
    d = hypot(gt.cx - cx, gt.cy - cy);
    if touching
        minD = gt.r + r - 1;               % contact autorise
    else
        minD = gt.r + r + 0.3 * r;
    end
    if any(d < minD), continue; end
    gt.cx(end+1) = cx; gt.cy(end+1) = cy; gt.r(end+1) = r; gt.type(end+1) = k;
end

% Ombre portee douce puis dessin des pieces
shadow = zeros(H, W);
for i = 1:numel(gt.cx)
    shadow = max(shadow, double(hypot(X - gt.cx(i) - 3, Y - gt.cy(i) - 3) < gt.r(i) + 1));
end
shadow = conv2(shadow, ones(7)/49, 'same');
img = img .* (1 - 0.25 * shadow);

for i = 1:numel(gt.cx)
    k = gt.type(i);
    rho = hypot(X - gt.cx(i), Y - gt.cy(i)) / gt.r(i);
    inside = rho <= 1;
    switch T.material{k}
        case 'cuivre', cIn = colCopper; cOut = colCopper;
        case 'or',     cIn = colGold;   cOut = colGold;
        case 'bi1',    cIn = colSilver; cOut = colGold;
        case 'bi2',    cIn = colGold;   cOut = colSilver;
    end
    % eclairage : plus clair en haut a gauche, liseré sombre au bord
    shade = 1 + 0.12 * (-(X - gt.cx(i)) - (Y - gt.cy(i))) / gt.r(i) / sqrt(2);
    rim = 1 - 0.35 * exp(-((1 - rho) * gt.r(i) / 1.5).^2);
    engr = 1 + 0.05 * sin(0.6 * (X - gt.cx(i))) .* cos(0.5 * (Y - gt.cy(i))) .* (rho < 0.8);
    for ch = 1:3
        if T.innerRatio(k) > 0
            col = cOut(ch) * (rho > T.innerRatio(k)) + cIn(ch) * (rho <= T.innerRatio(k));
        else
            col = cIn(ch);
        end
        layer = img(:, :, ch);
        v = col .* shade .* rim .* engr;
        if isscalar(v), v = v * ones(H, W); end
        layer(inside) = v(inside);
        img(:, :, ch) = layer;
    end
end

% Leger flou (optique) + bruit capteur
g = [1 2 1; 2 4 2; 1 2 1] / 16;
for ch = 1:3
    img(:, :, ch) = conv2(img(:, :, ch), g, 'same');
end
img = img + noiseStd * randn(size(img));
img = min(max(img, 0), 1);
% bords de l'image : conv2 assombrit la premiere ligne/colonne, on recopie
img(1, :, :) = img(2, :, :); img(end, :, :) = img(end-1, :, :);
img(:, 1, :) = img(:, 2, :); img(:, end, :) = img(:, end-1, :);
gt.pxPerMm = pxPerMm;
end
