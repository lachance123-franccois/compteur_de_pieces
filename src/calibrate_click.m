function pxPerMm = calibrate_click(img, knownMm)
%Echelle (pixels/mm) a partir de deux clics sur une longueur connue.
%   pxPerMm = CALIBRATE_CLICK(img, knownMm)
%   ou 50 mm sur une regle posee a cote des pieces).

if nargin < 2, knownMm = 25.75; end
fig = figure('Name', 'Calibration');
imshow(img);
title(sprintf('Cliquez les 2 extremites d''une longueur de %.2f mm', knownMm));
[x, y] = ginput(2);
pxPerMm = hypot(diff(x), diff(y)) / knownMm;
fprintf('Echelle : %.3f pixels/mm\n', pxPerMm);
close(fig);
end
