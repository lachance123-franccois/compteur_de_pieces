function pxPerMm = calibrate_click(img, knownMm)
% CALIBRATE_CLICK Calcule l'échelle pixels/mm par sélection graphique d'une distance connue.
%
%   pxPerMm = CALIBRATE_CLICK(img, knownMm)
%
%   Entrées :
%       img     : Matrice de l'image (RGB ou niveaux de gris)
%       knownMm : Longueur réelle de l'objet de référence en mm (Ex: 25.75 pour 2€)
%
%   Sortie :
%       pxPerMm : Facteur d'échelle calculé (pixels par millimètre)

    % Valeur par défaut : diamètre d'une pièce de 2 euros (25.75 mm)
    if nargin < 2
        knownMm = 25.75; 
    end
    
    % Ouverture de l'interface graphique de sélection
    fig = figure('Name', 'Calibration spatiale');
    imshow(img);
    title(sprintf('Cliquez sur les 2 extrémités de la référence (%.2f mm)', knownMm));
    
    % Capture des deux points de l'utilisateur
    [x, y] = ginput(2);
    
    % Calcul de la distance euclidienne et mise à l'échelle
    pxPerMm = hypot(diff(x), diff(y)) / knownMm;
    
    fprintf('Échelle calibrée : %.3f pixels/mm\n', pxPerMm);
    close(fig);
end
