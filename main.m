%% Comptage de pieces de monnaie par transformee de Hough circulaire
% Detection (Hough codee a la main), identification par diametre + couleur,
% estimation automatique de l'echelle, calcul du montant total.
% Aucune toolbox requise (imfindcircles de l'Image Processing Toolbox est
% utilisee seulement, si presente, comme reference).
%
% Auteur : Lachance - github.com/lachance123-franccois

clear; close all; clc;
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));
resDir = fullfile(root, 'results');
if ~exist(resDir, 'dir'), mkdir(resDir); end
rng(7);
T = coin_table();

%% 1. Image synthetique et etapes de la detection
pxPerMm = 4;
[img, gt] = coins_synth(12, pxPerMm, [600 800], false, 0.02);
out = count_coins(img, pxPerMm);
[~, acc, edges] = hough_circles(out.gray, round([7 14] * pxPerMm));
fprintf('Image synthetique : %d pieces, total reel %.2f €\n', numel(gt.cx), sum(T.values(gt.type)));
fprintf('Detecte : %d pieces, total estime %.2f €\n', size(out.circles, 1), out.total);

fig = figure('Position', [50 50 1300 700]);
subplot(2, 2, 1); imshow(img); title('Image d''entree (synthetique)');
subplot(2, 2, 2); imshow(edges); title('Contours (Sobel + suppression des non-maxima)');
subplot(2, 2, 3);
[~, kBest] = max(squeeze(max(max(acc, [], 1), [], 2)));
imagesc(acc(:, :, kBest)); axis image off; colorbar;
title(sprintf('Accumulateur de Hough pour r = %d px', round(7*pxPerMm) + kBest - 1));
subplot(2, 2, 4); draw_result(img, out.circles, out.types, out.total, 'Resultat :');
save_fig(fig, fullfile(resDir, 'fig1_etapes.png'));

%% 2. Caracteristiques couleur : teinte / saturation du centre et de la couronne
fig = figure('Position', [50 50 700 500]);
F = out.features;
mats = {'cuivre', 'or', 'bi1', 'bi2'};
cols = [0.75 0.40 0.15; 0.85 0.65 0.10; 0.3 0.3 0.9; 0.1 0.6 0.2];
hold on;
for k = 1:numel(mats)
    sel = strcmp(F.material, mats{k});
    scatter(F.hueIn(sel), F.satIn(sel), 60, cols(k, :), 'filled');
end
xline(0.10, 'k--'); yline(0.22, 'k--');
xlabel('Teinte du centre'); ylabel('Saturation du centre'); grid on; box on;
legend('cuivre (1-2-5 c)', 'or (10-20-50 c)', '1 € (centre argent)', '2 € (centre or)', 'Location', 'best');
title('Espace de decision couleur (seuils en pointilles)');
save_fig(fig, fullfile(resDir, 'fig2_couleurs.png'));

%% 3. Echelle inconnue : estimation automatique
out2 = count_coins(img, [], struct('rRange', [25 60]));
fprintf('Echelle estimee automatiquement : %.2f px/mm (vraie : %.2f), total %.2f €\n', ...
    out2.pxPerMm, pxPerMm, out2.total);

%% 4. Evaluation sur 30 images synthetiques (separees puis jointives)
nImg = 30;
cases = {false, true};
caseNames = {'pieces separees', 'pieces jointives'};
for c = 1:2
    tp = 0; fp = 0; fn = 0; ok = 0; exactTotal = 0; rErr = [];
    for n = 1:nImg
        [im, g] = coins_synth(randi([6 14]), 3 + 2*rand, [600 800], cases{c}, 0.03);
        o = count_coins(im, g.pxPerMm);
        m = match_detections(o.circles, o.types, g);
        tp = tp + m.tp; fp = fp + m.fp; fn = fn + m.fn; ok = ok + m.correctType;
        rErr = [rErr m.radiusErrPx]; %#ok<AGROW>
        exactTotal = exactTotal + (abs(o.total - sum(T.values(g.type))) < 1e-9);
    end
    fprintf('\n[%s, %d images]\n', caseNames{c}, nImg);
    fprintf('  Precision detection : %.1f %%   Rappel : %.1f %%\n', 100*tp/(tp+fp), 100*tp/(tp+fn));
    fprintf('  Pieces bien identifiees (parmi les detectees) : %.1f %%\n', 100*ok/max(tp, 1));
    fprintf('  Erreur de rayon : moyenne %.2f px, ecart-type %.2f px\n', mean(rErr), std(rErr));
    fprintf('  Montant total exact : %d / %d images\n', exactTotal, nImg);
end

%% 5. Exemple avec pieces jointives et bruit plus fort
[img3, gt3] = coins_synth(14, 4, [600 800], true, 0.05);
o3 = count_coins(img3, 4);
fig = figure('Position', [50 50 900 600]);
draw_result(img3, o3.circles, o3.types, o3.total, ...
    sprintf('Jointives, bruit 0.05 (reel %.2f €) -', sum(T.values(gt3.type))));
save_fig(fig, fullfile(resDir, 'fig3_jointives.png'));

%% 6. Comparaison avec imfindcircles (si Image Processing Toolbox)
if exist('imfindcircles', 'file')
    rr = round([7 14] * pxPerMm);
    tic; [cRef, rRef] = imfindcircles(out.gray, rr, 'Sensitivity', 0.92); tRef = toc;
    tic; cMine = hough_circles(out.gray, rr); tMine = toc;
    fprintf('\nimfindcircles : %d cercles en %.2f s | Hough maison : %d cercles en %.2f s\n', ...
        numel(rRef), tRef, size(cMine, 1), tMine);
end

%% 7. Vos propres photos (data/*.jpg)
% Photo prise du dessus, fond uni contrastant, pieces non superposees.
% Pour l'echelle : soit calibrate_click (2 clics sur une longueur connue),
% soit l'estimation automatique (donner alors opts.rRange en pixels).
photos = [dir(fullfile(root, 'data', '*.jpg')); dir(fullfile(root, 'data', '*.png'))];
for p = 1:numel(photos)
    I = imread(fullfile(photos(p).folder, photos(p).name));
    s = 900 / max(size(I, 1), size(I, 2));
    % Hypothese : une piece occupe entre 4 % et 15 % du plus grand cote
    rRange = round([0.02 0.075] * max(size(I, 1), size(I, 2)));
    o = count_coins(I, [], struct('rRange', rRange));
    fig = figure;
    draw_result(o.img, o.circles, o.types, o.total, photos(p).name);
    save_fig(fig, fullfile(resDir, ['photo_' photos(p).name(1:end-4) '.png']));
    fprintf('%s : %d pieces, %.2f € (echelle %.2f px/mm apres reduction x%.2f)\n', ...
        photos(p).name, size(o.circles, 1), o.total, o.pxPerMm, s);
end
if isempty(photos)
    fprintf('\n(Ajoutez vos photos dans data/ pour les traiter)\n');
end
fprintf('\nFigures enregistrees dans %s\n', resDir);
