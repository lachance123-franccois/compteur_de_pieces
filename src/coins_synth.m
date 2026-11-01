function [img, gt] = coins_synth(nCoins, pxPerMm, imgSize, touching, noiseStd)
% COINS_SYNTH Génère une image de synthèse réaliste de pièces en euros avec vérité terrain.
%
%   [img, gt] = COINS_SYNTH(nCoins, pxPerMm, imgSize, touching, noiseStd)
%
%   Entrées :
%       nCoins   : Nombre de pièces à générer                         [Défaut: 10]
%       pxPerMm  : Échelle spatiale (pixels par mm)                   [Défaut: 4]
%       imgSize  : Dimensions de l'image [hauteur, largeur]           [Défaut:]
%       touching : Booléen autorisant le contact entre les pièces     [Défaut: false]
%       noiseStd : Écart-type du bruit gaussien appliqué au capteur   [Défaut: 0.02]
%
%   Sorties :
%       img      : Image RGB au format double compris entre
%       gt       : Structure de vérité terrain (cx, cy, r en pixels et indices types)

    % Gestion des paramètres par défaut
    if nargin < 1 || isempty(nCoins),   nCoins = 10;        end
    if nargin < 2 || isempty(pxPerMm),  pxPerMm = 4;        end
    if nargin < 3 || isempty(imgSize),  imgSize = [600 800]; end
    if nargin < 4 || isempty(touching), touching = false;   end
    if nargin < 5 || isempty(noiseStd), noiseStd = 0.02;    end

    T = coin_table();
    H = imgSize(1); W = imgSize(2);
    [X, Y] = meshgrid(1:W, 1:H);

    % Génération du fond texturé avec dégradé linéaire d'éclairage
    bg = 0.80 + 0.06 * (X / W) - 0.05 * (Y / H);
    tex = conv2(randn(H, W), ones(5)/25, 'same') * 0.04;
    img = repmat(bg + tex, 1, 1, 3) .* reshape([1.0 0.98 0.95], 1, 1, 3);

    % Palettes de couleurs métalliques de référence
    colCopper = [0.72 0.42 0.22];
    colGold   = [0.86 0.70 0.32];
    colSilver = [0.74 0.74 0.76];

    % Initialisation de la structure de vérité terrain
    gt.cx = zeros(1, 0); gt.cy = zeros(1, 0); gt.r = zeros(1, 0); gt.type = zeros(1, 0);
    maxTry = 5000;
    tries = 0;
    
    % Boucle de placement des pièces (Algorithme de rejet)
    while numel(gt.cx) < nCoins && tries < maxTry
        tries = tries + 1;
        k = randi(numel(T.values));
        r = T.diamMm(k) / 2 * pxPerMm;
        
        % Génération de coordonnées aléatoires sécurisées par rapport aux bords
        cx = r + 5 + rand * (W - 2*r - 10);
        cy = r + 5 + rand * (H - 2*r - 10);
        
        % Vérification de non-recouvrement géométrique
        d = hypot(gt.cx - cx, gt.cy - cy);
        if touching
            minD = gt.r + r - 1;               
        else
            minD = gt.r + r + 0.3 * r;
        end
        if any(d < minD), continue; end
        
        % Validation de la pièce
        gt.cx(end+1) = cx; gt.cy(end+1) = cy; gt.r(end+1) = r; gt.type(end+1) = k;
    end

    % Génération et application d'une ombre portée diffuse
    shadow = zeros(H, W);
    for i = 1:numel(gt.cx)
        shadow = max(shadow, double(hypot(X - gt.cx(i) - 3, Y - gt.cy(i) - 3) < gt.r(i) + 1));
    end
    shadow = conv2(shadow, ones(7)/49, 'same');
    img = img .* (1 - 0.25 * shadow);

    % Rendu analytique de chaque pièce validée
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
        
        % Modélisation mathématique du relief, des ciselures et du chanfrein
        shade = 1 + 0.12 * (-(X - gt.cx(i)) - (Y - gt.cy(i))) / gt.r(i) / sqrt(2);
        rim = 1 - 0.35 * exp(-((1 - rho) * gt.r(i) / 1.5).^2);
        engr = 1 + 0.05 * sin(0.6 * (X - gt.cx(i))) .* cos(0.5 * (Y - gt.cy(i))) .* (rho < 0.8);
        
        % Remplissage des canaux de couleur en gérant l'agencement bimétallique
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

    % Application de la fonction d'étalement du point (PSF optique) et du bruit de capteur
    g = [1 2 1; 2 4 2; 1 2 1] / 16;
    for ch = 1:3
        img(:, :, ch) = conv2(img(:, :, ch), g, 'same');
    end
    img = img + noiseStd * randn(size(img));
    img = min(max(img, 0), 1);
    
    % Nettoyage des artefacts de convolution sur les bordures de la matrice
    img(1, :, :) = img(2, :, :); img(end, :, :) = img(end-1, :, :);
    img(:, 1, :) = img(:, 2, :); img(:, end, :) = img(:, end-1, :);
    
    gt.pxPerMm = pxPerMm;
end
