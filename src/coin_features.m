function F = coin_features(img, circles)
%COIN_FEATURES  Couleur du centre et de la couronne de chaque piece detectee.
%   F = COIN_FEATURES(img, circles)
%     img     : image RGB double [0,1]
%     circles : K x >=3 [cx cy r ...]
%   F.hueIn, F.satIn   : teinte et saturation moyennes du centre (rho < 0.45)
%   F.hueOut, F.satOut : idem sur la couronne (0.80 < rho < 0.93)
%   F.matIn, F.matOut  : 'cuivre', 'or' ou 'argent' (voir material_of)
%   F.material         : materiau global ('cuivre','or','bi1','bi2')

[H, W, ~] = size(img);
K = size(circles, 1);
F.hueIn = zeros(K, 1); F.satIn = zeros(K, 1);
F.hueOut = zeros(K, 1); F.satOut = zeros(K, 1);
F.matIn = cell(K, 1); F.matOut = cell(K, 1); F.material = cell(K, 1);

for i = 1:K
    cx = circles(i, 1); cy = circles(i, 2); r = circles(i, 3);
    x0 = max(1, floor(cx - r)); x1 = min(W, ceil(cx + r));
    y0 = max(1, floor(cy - r)); y1 = min(H, ceil(cy + r));
    [X, Y] = meshgrid(x0:x1, y0:y1);
    rho = hypot(X - cx, Y - cy) / r;
    patch = img(y0:y1, x0:x1, :);
    rgbIn = mean_rgb(patch, rho < 0.45);
    rgbOut = mean_rgb(patch, rho > 0.80 & rho < 0.93);
    hsvIn = rgb2hsv(rgbIn); hsvOut = rgb2hsv(rgbOut);
    F.hueIn(i) = hsvIn(1); F.satIn(i) = hsvIn(2);
    F.hueOut(i) = hsvOut(1); F.satOut(i) = hsvOut(2);
    F.matIn{i} = material_of(hsvIn);
    F.matOut{i} = material_of(hsvOut);
    if strcmp(F.matIn{i}, 'argent') && strcmp(F.matOut{i}, 'or')
        F.material{i} = 'bi1';
    elseif strcmp(F.matIn{i}, 'or') && strcmp(F.matOut{i}, 'argent')
        F.material{i} = 'bi2';
    elseif strcmp(F.matIn{i}, 'argent')
        F.material{i} = 'bi1';        % centre argent : forcement une piece de 1 euro
    else
        F.material{i} = F.matIn{i};
    end
end
end

function c = mean_rgb(patch, m)
c = zeros(1, 3);
for ch = 1:3
    p = patch(:, :, ch);
    c(ch) = mean(p(m));
end
end

function m = material_of(hsv)
% Seuils regles pour un eclairage neutre ; a ajuster pour vos photos
% (balance des blancs) en regardant la figure teinte/saturation du main.
satSilver = 0.22;     % en dessous : metal gris (argent)
hueCopper = 0.10;     % teinte < 0.10 (orange-rouge) : cuivre ; au-dessus : or (jaune)
if hsv(2) < satSilver
    m = 'argent';
elseif hsv(1) < hueCopper || hsv(1) > 0.9
    m = 'cuivre';
else
    m = 'or';
end
end
