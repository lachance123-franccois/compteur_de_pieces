function draw_result(img, circles, types, total, ttl)
% DRAW_RESULT Affiche l'image avec chaque pièce entourée et sa valeur identifiée.
%
%   DRAW_RESULT(img, circles, types, total, ttl)
%
%   Entrées :
%       img     : Image d'origine (RGB au format double ou entier)
%       circles : Matrice [K x 3] des cercles détectés [cx, cy, r] en pixels
%       types   : Vecteur [K x 1] contenant l'indice de chaque pièce dans la table
%       total   : Montant total calculé de la séquence en euros
%       ttl     : Préfixe textuel optionnel pour personnaliser le titre

    % Chargement de la table de référence pour obtenir les noms affichables
    T = coin_table();
    
    % Affichage de l'image de base
    imshow(img); 
    hold on;
    
    % Génération du maillage angulaire polaire
    th = linspace(0, 2 * pi, 100);
    
    % Tracé itératif des repères géométriques et des étiquettes
    for i = 1:size(circles, 1)
        cx = circles(i, 1); 
        cy = circles(i, 2); 
        r  = circles(i, 3);
        
        % Tracé vectoriel du contour estimé du cercle (en vert)
        plot(cx + r * cos(th), cy + r * sin(th), 'g-', 'LineWidth', 1.5);
        
        % Superposition de l'étiquette textuelle centrée
        text(cx, cy, T.names{types(i)}, 'Color', 'k', 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', 'BackgroundColor', [1 1 1], ...
            'Margin', 1, 'FontSize', 8);
    end
    
    % Gestion du titre d'affichage
    if nargin < 5
        ttl = ''; 
    end
    title(sprintf('%s  %d pieces, total = %.2f €', ttl, size(circles, 1), total));
    
    hold off;
end
