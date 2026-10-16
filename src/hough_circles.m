function [circles, acc, edges] = hough_circles(gray, rRange, opts)
%HOUGH_CIRCLES  Transformee de Hough circulaire codee a la main.
%   [circles, acc, edges] = HOUGH_CIRCLES(gray, rRange, opts)
%     gray   : image en niveaux de gris (double, [0,1])
%     rRange : [rMin rMax] rayons recherches (pixels)
%     opts   : structure optionnelle
%       .sigma       lissage gaussien avant gradient               [1.5]
%       .edgeFrac    seuil des contours en fraction du gradient max [0.15]
%       .minScore    part minimale du perimetre ayant vote         [0.30]
%       .maxCircles  nombre max de cercles                          [60]
%       .rStep       pas en rayon (pixels)                          [1]
%   circles : matrice K x 4 [cx cy r score], triee par score decroissant
%   acc     : accumulateur 3D (H x W x nR) normalise par le perimetre
%   edges   : carte binaire des contours utilises pour voter
%
%   Principe : chaque pixel de contour vote, pour chaque rayon r, pour le
%   centre situe a la distance r dans la direction du gradient (des deux
%   cotes, car une piece peut etre plus claire ou plus sombre que le fond).
%   Utiliser la direction du gradient reduit le cout de O(N * nR * nTheta)
%   a O(N * nR).

if nargin < 3, opts = struct(); end
sigma = getopt(opts, 'sigma', 1.5);
edgeFrac = getopt(opts, 'edgeFrac', 0.15);
minScore = getopt(opts, 'minScore', 0.30);
maxCircles = getopt(opts, 'maxCircles', 60);
rStep = getopt(opts, 'rStep', 1);

[H, W] = size(gray);
I = filter_replicate(gray, gauss_kernel(sigma));

% Gradient de Sobel
sx = [-1 0 1; -2 0 2; -1 0 1] / 8;
gx = filter_replicate(I, sx);
gy = filter_replicate(I, sx');
mag = hypot(gx, gy);

% Suppression des non-maxima (direction du gradient quantifiee sur 4 axes)
ang = mod(atan2(gy, gx), pi);
q = mod(round(ang / (pi/4)), 4);           % 0: horiz, 1: diag, 2: vert, 3: anti-diag
offs = [0 1; 1 1; 1 0; 1 -1];              % [dy dx] le long du gradient
nms = false(H, W);
for d = 0:3
    dy = offs(d+1, 1); dx = offs(d+1, 2);
    m1 = circshift(mag, [dy dx]);
    m2 = circshift(mag, [-dy -dx]);
    nms = nms | (q == d & mag >= m1 & mag >= m2);
end
edges = nms & mag > edgeFrac * max(mag(:));
edges([1 end], :) = false; edges(:, [1 end]) = false;

[ey, ex] = find(edges);
ux = gx(edges) ./ mag(edges);
uy = gy(edges) ./ mag(edges);

rList = rRange(1):rStep:rRange(2);
nR = numel(rList);
acc = zeros(H, W, nR, 'single');
for k = 1:nR
    r = rList(k);
    cx = round([ex + r*ux; ex - r*ux]);
    cy = round([ey + r*uy; ey - r*uy]);
    ok = cx >= 1 & cx <= W & cy >= 1 & cy <= H;
    A = accumarray([cy(ok) cx(ok)], 1, [H W]);
    A = conv2(A, ones(3), 'same');            % somme 3x3 : tolere un leger decentrage
    acc(:, :, k) = single(A / (2*pi*r));      % fraction du perimetre ayant vote
end

% Extraction iterative des maxima avec suppression autour de chaque cercle
circles = zeros(0, 4);
work = acc;
[Xg, Yg] = meshgrid(1:W, 1:H);
for it = 1:maxCircles
    [s, idx] = max(work(:));
    if s < minScore, break; end
    [cy0, cx0, k0] = ind2sub(size(work), idx);
    % Cercles concentriques (centre d'une piece bimetallique, gravures) :
    % on garde le plus grand rayon bien soutenu au meme centre = le bord de la piece.
    prof = squeeze(acc(cy0, cx0, :));
    lm = find(prof(2:end-1) >= prof(1:end-2) & prof(2:end-1) >= prof(3:end)) + 1;
    kOuter = max(lm(prof(lm) >= max(minScore, 0.6 * s)));
    if ~isempty(kOuter) && kOuter > k0
        k0 = kOuter;
        s = prof(k0);
    end
    % affinage sub-pixel du rayon par interpolation parabolique
    r0 = rList(k0);
    if k0 > 1 && k0 < nR
        a = acc(cy0, cx0, k0-1); b = acc(cy0, cx0, k0); c = acc(cy0, cx0, k0+1);
        den = a - 2*b + c;
        if den < 0, r0 = r0 + rStep * 0.5 * (a - c) / den; end
    end
    circles(end+1, :) = [cx0 cy0 r0 s]; %#ok<AGROW>
    mask = hypot(Xg - cx0, Yg - cy0) < 0.8 * r0;
    work(repmat(mask, 1, 1, nR)) = 0;
end
end

function k = gauss_kernel(sigma)
h = max(1, ceil(3 * sigma));
x = -h:h;
g = exp(-x.^2 / (2 * sigma^2));
g = g / sum(g);
k = g' * g;
end

function J = filter_replicate(I, k)
% Convolution 'same' avec bords repliques (equivalent imfilter(...,'replicate'))
[kh, kw] = size(k);
ph = floor(kh/2); pw = floor(kw/2);
[H, W] = size(I);
rows = min(max((1-ph):(H+ph), 1), H);
cols = min(max((1-pw):(W+pw), 1), W);
J = conv2(I(rows, cols), rot90(k, 2), 'valid');
end

function v = getopt(s, name, default)
if isfield(s, name) && ~isempty(s.(name)), v = s.(name); else, v = default; end
end
