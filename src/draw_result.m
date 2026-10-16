function draw_result(img, circles, types, total, ttl)
%DRAW_RESULT  Affiche l'image avec chaque piece entouree et sa valeur.
T = coin_table();
imshow(img); hold on;
th = linspace(0, 2*pi, 100);
for i = 1:size(circles, 1)
    cx = circles(i, 1); cy = circles(i, 2); r = circles(i, 3);
    plot(cx + r*cos(th), cy + r*sin(th), 'g-', 'LineWidth', 1.5);
    text(cx, cy, T.names{types(i)}, 'Color', 'k', 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'BackgroundColor', [1 1 1], 'Margin', 1, 'FontSize', 8);
end
if nargin < 5, ttl = ''; end
title(sprintf('%s  %d pieces, total = %.2f €', ttl, size(circles, 1), total));
hold off;
end
