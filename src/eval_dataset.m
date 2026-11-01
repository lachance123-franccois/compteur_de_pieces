%% Évaluation sur photographies réelles annotées (YOLO / CSV)
%
%   Ce script évalue les performances du pipeline de détection et de 
%   classification de pièces de monnaie en calculant les taux de précision, 
%   de rappel, l'exactitude de l'identification et l'erreur de montant global.
%
%   Sources de données supportées :
%       A) Export Roboflow au format YOLO décompressé dans data/roboflow/
%       B) Photos personnelles dans data/ accompagnées d'un fichier data/verite.csv
* **Auteur** : Lachance - github.com/lachance123-franccois

clear; close all; clc;
root = fileparts(mfilename('fullpath'));
if ~exist(fullfile(root, 'src'), 'dir'), root = pwd; end
addpath(fullfile(root, 'src'));

outDir = fullfile(root, 'results', 'eval');
if ~exist(outDir, 'dir'), mkdir(outDir); end
T = coin_table();

% Paramètres de détection : plage de fraction du plus grand côté de l'image
rMinFrac = 0.02;  
rMaxFrac = 0.12;
opts = struct('maxSide', 700, 'rStep', 1);
saveFigs = true;

rows = {}; % Stockage des lignes de résultats

%% A) Traitement du jeu de données Roboflow (YOLO)
rfDir = fullfile(root, 'data', 'roboflow');
if exist(fullfile(rfDir, 'data.yaml'), 'file')
    names = read_yaml_names(fullfile(rfDir, 'data.yaml'));
    map = map_class_names(names, T);
    fprintf('Roboflow : classes détectées [%s]\n', strjoin(names, ', '));
    
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
        
        % Projection des coordonnées normalisées YOLO dans l'espace image
        gt.cx = L(:, 2)' * W;  
        gt.cy = L(:, 3)' * H;
        gt.r = (L(:, 4)' * W + L(:, 5)' * H) / 4; 
        gt.type = map(L(:, 1)' + 1);
        
        rows(end+1, :) = evaluate_one(I, gt, imgs(k).name, T, rMinFrac, rMaxFrac, opts, outDir, saveFigs); %#ok<SAGROW>
    end
end

%% B) Traitement des photos personnelles + verite.csv
csvFile = fullfile(root, 'data', 'verite.csv');
if exist(csvFile, 'file')
    V = readtable(csvFile, 'TextType', 'string');
    for k = 1:height(V)
        f = fullfile(root, 'data', V.fichier(k));
        if ~exist(f, 'file')
            fprintf('Fichier introuvable : %s\n', f); 
            continue; 
        end
        I = imread(f);
        gt = struct('cx', [], 'cy', [], 'r', [], 'type', [], 'total', V.montant(k));
        rows(end+1, :) = evaluate_one(I, gt, char(V.fichier(k)), T, rMinFrac, rMaxFrac, opts, outDir, saveFigs); %#ok<SAGROW>
    end
end

% Vérification de la présence de données à évaluer
if isempty(rows)
    error('Aucune donnée trouvée. Placez un export YOLO ou un fichier verite.csv dans le dossier data/.');
end

%% Génération du bilan statistique global
R = cell2table(rows, 'VariableNames', {'image', 'n_reel', 'n_detecte', 'vrais_pos', ...
    'bien_identifiees', 'montant_reel', 'montant_estime', 'temps_s'});
disp(R);
writetable(R, fullfile(outDir, 'resultats.csv'));

hasBoxes = ~isnan(R.vrais_pos);
fprintf('\n===== Bilan global sur %d images =====\n', height(R));
if any(hasBoxes)
    tp = sum(R.vrais_pos(hasBoxes)); 
    nDet = sum(R.n_detecte(hasBoxes)); 
    nGt = sum(R.n_reel(hasBoxes));
    fprintf('Détection     : Précision %.1f %%, Rappel %.1f %% (%d pièces annotées)\n', ...
        100 * tp / max(nDet, 1), 100 * tp / max(nGt, 1), nGt);
    fprintf('Classification : Exactitude graphique parmi les détectées = %.1f %%\n', ...
        100 * sum(R.bien_identifiees(hasBoxes)) / max(tp, 1));
end
err = abs(R.montant_estime - R.montant_reel);
fprintf('Montant exact  : %d / %d images ; Erreur absolue moyenne = %.2f EUR\n', ...
    sum(err < 0.005), height(R), mean(err));
fprintf('Temps moyen    : %.2f s par image\n', mean(R.temps_s));

%% ------------------------------------------------------------------------
function row = evaluate_one(I, gt, name, T, rMinFrac, rMaxFrac, opts, outDir, saveFigs)
% EVALUATE_ONE Évalue une seule image et génère la figure de diagnostic associée.
    side = max(size(I, 1), size(I, 2));
    opts.rRange = round([rMinFrac rMaxFrac] * side);
    
    tic;
    o = count_coins(I, [], opts);
    t = toc;
    
    C = o.circles;
    C(:, 1:3) = C(:, 1:3) / o.scale; % Remise à l'échelle d'origine
    
    if isfield(gt, 'total')
        totReel = gt.total; nReel = NaN; tp = NaN; ok = NaN;
    else
        m = match_detections(C, o.types, gt);
        totReel = sum(T.values(gt.type));
        nReel = numel(gt.cx); tp = m.tp; ok = m.correctType;
    end
    
    row = {name, nReel, size(C, 1), tp, ok, totReel, o.total, t};
    fprintf('%-30s | Réel: %6.2f EUR | Estimé: %6.2f EUR | %2d détectées\n', name, totReel, o.total, size(C, 1));
    
    if saveFigs
        fig = figure('Visible', 'off', 'Position', [50 50 900 650]);
        draw_result(o.img, o.circles, o.types, o.total, sprintf('%s (réel %.2f €) -', name, totReel));
        if ~isfield(gt, 'total') 
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
% READ_YAML_NAMES Analyse le fichier de configuration YAML pour extraire les étiquettes de classe.
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
% MAP_CLASS_NAMES Mappe les chaînes textuelles YOLO vers les indices de la table officielle.
    map = zeros(1, numel(names));
    for i = 1:numel(names)
        s = lower(regexprep(names{i}, '[^0-9a-zA-Z]', ''));
        v = str2double(regexp(s, '^\d+', 'match', 'once'));
        if contains(s, 'eur') && ~contains(s, 'cent')
            val = v; 
        else
            val = v / 100; 
        end
        j = find(abs(T.values - val) < 1e-9, 1);
        if isempty(j)
            error('Classe de pièce non reconnue dans le fichier YAML : %s', names{i}); 
        end
        map(i) = j;
    end
end

function L = read_yolo(f)
% READ_YOLO Charge la matrice des coordonnées et classes depuis le fichier d'annotation texte.
    L = [];
    fid = fopen(f, 'r');
    c = textscan(fid, '%f %f %f %f %f %*[^\n]');
    fclose(fid);
    if ~isempty(c{1})
        L = [c{:}]; 
    end
end
