function F = coin_features(img, circles)
% COIN_FEATURES Extrait les caractéristiques de couleur du centre et de la couronne.
%
%   F = COIN_FEATURES(img, circles)
%
%   Entrées :
%       img     : Image RGB au format double compris entre [0, 1]
%       circles : Matrice [K x >=3] contenant les coordonnées [cx, cy, r] en pixels
%
%   Sortie :
%       F       : Structure contenant les composantes HSV et le matériau identifié

    [H, W, ~] = size(img);
    K = size(circles, 1);
    
    % Initialisation des vecteurs de caractéristiques
    F.hueIn = zeros(K, 1);   F.satIn = zeros(K, 1);
    F.hueOut = zeros(K, 1);  F.satOut = zeros(K, 1);
    F.matIn = cell(K, 1);    F.matOut = cell(K, 1); 
    F.material = cell(K, 1);

    for i = 1:K
        % Extraction de la géométrie de la pièce i
        cx = circles(i, 1); cy = circles(i, 2); r = circles(i, 3);
        
        % Définition de la boîte englobante sécurisée par rapport aux bords de l'image
        x0 = max(1, floor(cx - r)); x1 = min(W, ceil(cx + r));
        y0 = max(1, floor(cy - r)); y1 = min(H, ceil(cy + r));
        
        % Calcul du rayon normalisé rho pour chaque pixel de la zone
        [X, Y] = meshgrid(x0:x1, y0:y1);
        rho = hypot(X - cx, Y - cy) / r;
        patch = img(y0:y1, x0:x1, :);
        
        % Calcul de la couleur RGB moyenne du coeur et de la couronne
        rgbIn = mean_rgb(patch, rho < 0.45);
        rgbOut = mean_rgb(patch, rho > 0.80 & rho < 0.93);
        
        % Conversion dans l'espace HSV
        hsvIn = rgb2hsv(rgbIn); 
        hsvOut = rgb2hsv(rgbOut);
        
        % Stockage des descripteurs photométriques
        F.hueIn(i) = hsvIn(1);   F.satIn(i) = hsvIn(2);
        F.hueOut(i) = hsvOut(1); F.satOut(i) = hsvOut(2);
        
        % Identification du métal local
        F.matIn{i} = material_of(hsvIn);
        F.matOut{i} = material_of(hsvOut);
        
        % Logique de décision pour la nature de la pièce (Mono ou Bimétallique)
        if strcmp(F.matIn{i}, 'argent') && strcmp(F.matOut{i}, 'or')
            F.material{i} = 'bi1';        % Centre argent, couronne or : 1 Euro
        elseif strcmp(F.matIn{i}, 'or') && strcmp(F.matOut{i}, 'argent')
            F.material{i} = 'bi2';        % Centre or, couronne argent : 2 Euros
        elseif strcmp(F.matIn{i}, 'argent')
            F.material{i} = 'bi1';        % Sécurité par défaut pour le cœur argent
        else
            F.material{i} = F.matIn{i};   % Pièces monométalliques (cuivre ou or nordique)
        end
    end
end

function c = mean_rgb(patch, m)
% MEAN_RGB Calcule le vecteur RGB moyen sur les pixels validés par le masque m.
    c = zeros(1, 3);
    for ch = 1:3
        p = patch(:, :, ch);
        c(ch) = mean(p(m));
    end
end

function m = material_of(hsv)
% MATERIAL_OF Détermine le type de métal à partir des seuils de teinte et saturation.
    satSilver = 0.22;     % Seuil maximal de saturation pour les métaux gris
    hueCopper = 0.10;     % Seuil de teinte séparant le cuivre (rouge) de l'or (jaune)
    
    if hsv(2) < satSilver
        m = 'argent';
    elseif hsv(1) < hueCopper || hsv(1) > 0.9
        m = 'cuivre';
    else
        m = 'or';
    end
end
