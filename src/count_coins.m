function out = count_coins(img, pxPerMm, opts)
% COUNT_COINS Chaîne complète de traitement : réduction, détection et classification.
%
%   out = COUNT_COINS(img, pxPerMm, opts)
%
%   Entrées :
%       img     : Image RGB (matrice uint8 ou double)
%       pxPerMm : Échelle en pixels/mm ([] pour une estimation automatique)
%       opts    : Structure d'options contenant les plages de rayons (.rRangeMm)
%                 et la taille maximale de traitement (.maxSide)
%
%   Sortie :
%       out     : Structure regroupant les cercles trouvés, les types de pièces,
%                 le montant total calculé, l'échelle et les images intermédiaires.

    if nargin < 2, pxPerMm = []; end
    if nargin < 3, opts = struct(); end
    
    % Normalisation de l'image au format double [0, 1]
    img = im2double_local(img);

    % Réduction de résolution pour limiter la taille de la Transformée de Hough 3D
    maxSide = 900;
    if isfield(opts, 'maxSide')
        maxSide = opts.maxSide; 
    end
    
    scale = min(1, maxSide / max(size(img, 1), size(img, 2)));
    if scale < 1
        img = resize_bilinear(img, scale);
        if ~isempty(pxPerMm)
            pxPerMm = pxPerMm * scale; 
        end
    end
    
    % Conversion RGB en niveaux de gris (Luminance CCIR 601)
    gray = 0.2989 * img(:, :, 1) + 0.5870 * img(:, :, 2) + 0.1140 * img(:, :, 3);

    % Détermination de la plage de recherche des rayons en pixels
    if ~isempty(pxPerMm)
        rRangeMm = [7 14]; % Rayons limites de l'Euro (7mm à 14mm)
        if isfield(opts, 'rRangeMm')
            rRangeMm = opts.rRangeMm; 
        end
        rRange = round(rRangeMm * pxPerMm);
    elseif isfield(opts, 'rRange')
        rRange = round(opts.rRange * scale);
    else
        error('count_coins:scale', ...
            'Spécifier l''argument pxPerMm ou le paramètre opts.rRange.');
    end

    % Exécution du pipeline algorithmique
    circles = hough_circles(gray, rRange, opts);
    circles = refine_circles(gray, circles);
    F = coin_features(img, circles);
    [types, pxPerMm, total] = classify_coins(circles, F, pxPerMm);

    % Encapsulation des résultats dans la structure de sortie
    out.circles = circles;
    out.types = types;
    out.total = total;
    out.pxPerMm = pxPerMm;
    out.features = F;
    out.scale = scale;
    out.img = img;
    out.gray = gray;
end

function I = im2double_local(I)
% IM2DOUBLE_LOCAL Convertit proprement une image entière ou double en double.
    if isinteger(I)
        I = double(I) / double(intmax(class(I)));
    else
        I = double(I);
    end
    if size(I, 3) == 1
        I = repmat(I, 1, 1, 3); 
    end
end

function J = resize_bilinear(I, s)
% RESIZE_BILINEAR Redimensionne une image par interpolation bilinéaire 2D.
    [H, W, C] = size(I);
    h = round(H * s); 
    w = round(W * s);
    [Xq, Yq] = meshgrid(linspace(1, W, w), linspace(1, H, h));
    J = zeros(h, w, C);
    for c = 1:C
        J(:, :, c) = interp2(I(:, :, c), Xq, Yq, 'linear');
    end
end
