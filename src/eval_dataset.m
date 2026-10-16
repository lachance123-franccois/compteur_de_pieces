%% Evaluation sur photos reelles annotees
% Deux sources possibles (on peut avoir les deux) :
%
% A) Export Roboflow au format YOLO (ex. universe.roboflow.com/eurocoins/euro_detection,
%    licence CC BY 4.0) decompresse dans data/roboflow/ :
%       data/roboflow/data.yaml
%       data/roboflow/train/images/*.jpg   et   data/roboflow/train/labels/*.txt
%       (idem valid/ et test/ si presents)
%    Chaque ligne d'un .txt : classe cx cy w h (coordonnees normalisees 0-1).
%
% B) Vos photos dans data/*.jpg + un fichier data/verite.csv :
%       fichier,montant
%       photo1.jpg,3.85
%       photo2.jpg,1.27
%
% Sortie : tableau par image (pieces detectees / reelles, bien identifiees,
% montant estime / reel), bilan global et figures annotees dans results/eval/.
%
% Auteur : Lachance - github.com/lachance123-franccois

clear; close all; clc;
root = fileparts(mfilename('fullpath'));
if ~exist(fullfile(root, 'src'), 'dir'), root = pwd; end
addpath(fullfile(root, 'src'));
outDir = fullfile(root, 'results', 'eval');
if ~exist(outDir, 'dir'), mkdir(outDir); end
T = coin_table();

% Parametres de detection pour des photos d'echelle inconnue :
% une piece occupe entre rMinFrac et rMaxFrac du plus grand cote de l'image.
rMinFrac = 0.02;  rMaxFrac = 0.12;
opts = struct('maxSide', 700, 'rStep', 1);
saveFigs = true;

rows = {};      % une ligne par image

%% A) Jeu Roboflow (YOLO)
rfDir = fullfile(root, 'data', 'roboflow');
if exist(fullfile(rfDir, 'data.yaml'), 'file')
    names = read_yaml_names(fullfile(rfDir, 'data.yaml'));
    map = map_class_names(names, T);
    fprintf('Roboflow : classes %s\n', strjoin(names, ', '));
    imgs = [dir(fullfile(rfDir, '**', 'images', '*.jpg')); dir(fullfile(rfDir, '**', 'images', '*.png'))];
    for k = 1:numel(imgs)
        f = fullfile(imgs(k).folder, imgs(k).name);
        [~, base] = fileparts(imgs(k).name);
        lbl = fullfile(fileparts(imgs(k).folder), 'labels', [base '.txt']);
        if ~exist(lbl, 'file'), continue; end
        I = imread(f);
        [H, W, ~] = size(I);
        L = read_yolo(lbl);
        if isempty(L), continue; end
        gt.cx = L(:, 2)' * W;  gt.cy = L(:, 3)' * H;
        gt.r = (L(:, 4)' * W + L(:, 5)' * H) / 4;    % boite -> rayon moyen
        gt.type = map(L(:, 1)' + 1);
        rows(end+1, :) = evaluate_one(I, gt, imgs(k).name, T, rMinFrac, rMaxFrac, opts, outDir, saveFigs); %#ok<SAGROW>
    end
end

%% B) Vos photos + verite.csv (montant seulement)
csvFile = fullfile(root, 'data', 'verite.csv');
if exist(csvFile, 'file')
    V = readtable(csvFile, 'TextType', 'string');
    for k = 1:height(V)
        f = fullfile(root, 'data', V.fichier(k));
        if ~exist(f, 'file'), fprintf('Introuvable : %s\n', f); continue; end
        I = imread(f);
        gt = struct('cx', [], 'cy', [], 'r', [], 'type', [], 'total', V.montant(k));
        rows(end+1, :) = evaluate_one(I, gt, char(V.fichier(k)), T, rMinFrac, rMaxFrac, opts, outDir, saveFigs); %#ok<SAGROW>
    end
end

if isempty(rows)
    error(['Aucune donnee : placez un export YOLO de Roboflow dans data/roboflow/ ' ...
        'ou vos photos + data/verite.csv dans data/ (voir l''en-tete du script).']);
end

%% Bilan
R = cell2table(rows, 'VariableNames', {'image', 'n_reel', 'n_detecte', 'vrais_pos', ...
    'bien_identifiees', 'montant_reel', 'montant_estime', 'temps_s'});
disp(R);
writetable(R, fullfile(outDir, 'resultats.csv'));

hasBoxes = ~isnan(R.vrais_pos);
fprintf('\n===== Bilan sur %d images =====\n', height(R));
if any(hasBoxes)
    tp = sum(R.vrais_pos(hasBoxes)); nDet = sum(R.n_detecte(hasBoxes)); nGt = sum(R.n_reel(hasBoxes));
    fprintf('Detection  : precision %.1f %%, rappel %.1f %%  (%d pieces annotees)\n', ...
        100*tp/max(nDet, 1), 100*tp/max(nGt, 1), nGt);
    fprintf('Identification (parmi les pieces detectees) : %.1f %%\n', ...
        100*sum(R.bien_identifiees(hasBoxes))/max(tp, 1));
end
err = abs(R.montant_estime - R.montant_reel);
fprintf('Montant exact : %d / %d images ; erreur absolue moyenne %.2f EUR\n', ...
    sum(err < 0.005), height(R), mean(err));
fprintf('Temps moyen : %.2f s par image\n', mean(R.temps_s));
fprintf('Tableau et figures dans %s\n', outDir);

%% ------------------------------------------------------------------------
function row = evaluate_one(I, gt, name, T, rMinFrac, rMaxFrac, opts, outDir, saveFigs)
side = max(size(I, 1), size(I, 2));
opts.rRange = round([rMinFrac rMaxFrac] * side);
tic;
o = count_coins(I, [], opts);
t = toc;
C = o.circles;
C(:, 1:3) = C(:, 1:3) / o.scale;                 % retour aux coordonnees d'origine
if isfield(gt, 'total')
    totReel = gt.total; nReel = NaN; tp = NaN; ok = NaN;
else
    m = match_detections(C, o.types, gt);
    totReel = sum(T.values(gt.type));
    nReel = numel(gt.cx); tp = m.tp; ok = m.correctType;
end
row = {name, nReel, size(C, 1), tp, ok, totReel, o.total, t};
fprintf('%-30s reel %6.2f EUR | estime %6.2f EUR | %2d pieces detectees\n', name, totReel, o.total, size(C, 1));
if saveFigs
    fig = figure('Visible', 'off', 'Position', [50 50 900 650]);
    draw_result(o.img, o.circles, o.types, o.total, sprintf('%s (reel %.2f €) -', name, totReel));
    if ~isfield(gt, 'total')                       % verite terrain en pointilles jaunes
        hold on; th = linspace(0, 2*pi, 60);
        for j = 1:numel(gt.cx)
            plot(gt.cx(j)*o.scale + gt.r(j)*o.scale*cos(th), gt.cy(j)*o.scale + gt.r(j)*o.scale*sin(th), 'y:', 'LineWidth', 1);
        end
    end
    [~, base] = fileparts(name);
    save_fig(fig, fullfile(outDir, [base '.png']));
    close(fig);
end
end

function names = read_yaml_names(f)
% Lit la liste "names" d'un data.yaml (forme ['a', 'b'] ou liste a tirets)
txt = fileread(f);
tok = regexp(txt, 'names:\s*\[([^\]]*)\]', 'tokens', 'once');
if ~isempty(tok)
    names = strtrim(strrep(strrep(strsplit(tok{1}, ','), '''', ''), '"', ''));
else
    blk = regexp(txt, 'names:\s*\n((?:\s*-\s*[^\n]+\n?)+)', 'tokens', 'once');
    names = strtrim(regexprep(regexp(blk{1}, '-\s*([^\n]+)', 'match'), '^-\s*', ''));
end
end

function map = map_class_names(names, T)
% '10cent' -> indice de '10 c' dans coin_table, '2eur' -> '2 €', etc.
map = zeros(1, numel(names));
for i = 1:numel(names)
    s = lower(regexprep(names{i}, '[^0-9a-zA-Z]', ''));
    v = str2double(regexp(s, '^\d+', 'match', 'once'));
    if contains(s, 'eur') && ~contains(s, 'cent'), val = v; else, val = v / 100; end
    j = find(abs(T.values - val) < 1e-9, 1);
    if isempty(j), error('Classe non reconnue : %s', names{i}); end
    map(i) = j;
end
end

function L = read_yolo(f)
L = [];
fid = fopen(f, 'r');
c = textscan(fid, '%f %f %f %f %f %*[^\n]');
fclose(fid);
if ~isempty(c{1}), L = [c{:}]; end
end