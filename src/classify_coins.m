function [types, pxPerMm, total] = classify_coins(circles, F, pxPerMm)
% CLASSIFY_COINS Identifie chaque pièce à partir de son diamètre et de sa couleur.
%
%   [types, pxPerMm, total] = CLASSIFY_COINS(circles, F, pxPerMm)
%
%   Entrées :
%       circles : Matrice [K x >=3] contenant les coordonnées [cx, cy, r] en pixels
%       F       : Structure contenant le type de matériau de chaque pièce (F.material)
%       pxPerMm : Échelle (pixels/mm). Si vide ou absent, elle est estimée.
%
%   Sorties :
%       types   : Vecteur [K x 1] des indices des pièces identifiées dans la table
%       pxPerMm : Échelle finale utilisée pour le calcul (pixels/mm)
%       total   : Montant total calculé de la séquence en euros

    T = coin_table();
    K = size(circles, 1);
    
    % Cas limite : aucune pièce détectée dans l'image
    if K == 0                                  
        types = zeros(0, 1); 
        total = 0;
        if nargin < 3, pxPerMm = []; end
        return;
    end
    
    % Conversion des rayons en diamètres (pixels)
    dPx = 2 * circles(:, 3);

    % Estimation automatique de l'échelle si non fournie
    if nargin < 3 || isempty(pxPerMm)
        % Grille d'échelles candidates basée sur les dimensions extrêmes de l'Euro (15 à 27 mm)
        sGrid = linspace(min(dPx) / 27, max(dPx) / 15, 2000);
        cost = zeros(size(sGrid));
        
        % Évaluation du critère des moindres carrés sur la grille
        for j = 1:numel(sGrid)
            [~, err] = assign(dPx / sGrid(j), F.material, T);
            cost(j) = sum(err.^2);
        end
        
        % Sélection de l'échelle minimisant l'erreur globale
        [~, jBest] = min(cost);
        pxPerMm = sGrid(jBest);
    end

    % Classification finale avec l'échelle retenue
    [types, ~] = assign(dPx / pxPerMm, F.material, T);
    total = sum(T.values(types));
end

function [types, relErr] = assign(dMm, material, T)
% ASSIGN Apparie chaque diamètre calculé au diamètre officiel le plus proche par matériau.
    K = numel(dMm);
    types = zeros(K, 1);
    relErr = zeros(K, 1);
    
    for i = 1:K
        % Filtrage des candidats par type de matériau (couleur)
        cand = find(strcmp(T.material, material{i}));
        if isempty(cand)
            cand = 1:numel(T.values); 
        end
        
        % Calcul de l'erreur relative minimale
        [e, j] = min(abs(T.diamMm(cand) - dMm(i)) ./ T.diamMm(cand));
        types(i) = cand(j);
        relErr(i) = e;
    end
end
