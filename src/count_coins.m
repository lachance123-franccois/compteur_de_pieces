function out = count_coins(img, pxPerMm, opts)
%COUNT_COINS  Chaine complete : detection, caracteristiques, identification, total.
%   out = COUNT_COINS(img, pxPerMm, opts)
%     img     : image RGB (uint8 ou double)
%     pxPerMm : echelle en pixels/mm ([] pour l'estimation automatique)
%     opts    : options de hough_circles + .rRangeMm (defaut [7 14] mm)
%               et .maxSide (cote max apres reduction, defaut 900 px)
%   out : structure (circles, types, total, pxPerMm, features, scale, gray)

if nargin < 2, pxPerMm = []; end
if nargin < 3, opts = struct(); end
img = im2double_local(img);

% Reduction de taille pour limiter la memoire de l'accumulateur 3D
maxSide = 900;
if isfield(opts, 'maxSide'), maxSide = opts.maxSide; end
scale = min(1, maxSide / max(size(img, 1), size(img, 2)));
if scale < 1
    img = resize_bilinear(img, scale);
    if ~isempty(pxPerMm), pxPerMm = pxPerMm * scale; end
end
gray = 0.2989 * img(:, :, 1) + 0.5870 * img(:, :, 2) + 0.1140 * img(:, :, 3);

if ~isempty(pxPerMm)
    rRangeMm = [7 14];
    if isfield(opts, 'rRangeMm'), rRangeMm = opts.rRangeMm; end
    rRange = round(rRangeMm * pxPerMm);
elseif isfield(opts, 'rRange')
    rRange = round(opts.rRange * scale);
else
    error('count_coins:scale', ...
        'Donner pxPerMm, ou opts.rRange (rayons en pixels de l''image d''origine).');
end

circles = hough_circles(gray, rRange, opts);
circles = refine_circles(gray, circles);
F = coin_features(img, circles);
[types, pxPerMm, total] = classify_coins(circles, F, pxPerMm);

out.circles = circles;
out.types = types;
out.total = total;
out.pxPerMm = pxPerMm;
out.features = F;
out.scale = scale;
out.img = img;
out.gray = gray;
end

function I = im2double_local(I)
if isinteger(I)
    I = double(I) / double(intmax(class(I)));
else
    I = double(I);
end
if size(I, 3) == 1, I = repmat(I, 1, 1, 3); end
end

function J = resize_bilinear(I, s)
[H, W, C] = size(I);
h = round(H * s); w = round(W * s);
[Xq, Yq] = meshgrid(linspace(1, W, w), linspace(1, H, h));
J = zeros(h, w, C);
for c = 1:C
    J(:, :, c) = interp2(I(:, :, c), Xq, Yq, 'linear');
end
end
