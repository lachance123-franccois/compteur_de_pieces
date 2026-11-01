function [circles, acc, edges] = hough_circles(gray, rRange, opts)
% HOUGH_CIRCLES Détection de cercles par transformée de Hough circulaire.

    if nargin < 3, opts = struct(); end
    sigma = getopt(opts, 'sigma', 1.5);
    edgeFrac = getopt(opts, 'edgeFrac', 0.15);
    minScore = getopt(opts, 'minScore', 0.30);
    maxCircles = getopt(opts, 'maxCircles', 60);
    rStep = getopt(opts, 'rStep', 1);

    [H, W] = size(gray);
    I = filter_replicate(gray, gauss_kernel(sigma));

    % Extraction du gradient (Sobel)
    sx = [-1 0 1; -2 0 2; -1 0 1] / 8;
    gx = filter_replicate(I, sx);
    gy = filter_replicate(I, sx');
    mag = hypot(gx, gy);

    % Suppression des non-maxima (NMS)
    ang = mod(atan2(gy, gx), pi);
    q = mod(round(ang / (pi/4)), 4);
    offs = [0 1; 1 1; 1 0; 1 -1];
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

    % Vote dans l'accumulateur 3D
    rList = rRange(1):rStep:rRange(2);
    nR = numel(rList);
    acc = zeros(H, W, nR, 'single');
    for k = 1:nR
        r = rList(k);
        cx = round([ex + r*ux; ex - r*ux]);
        cy = round([ey + r*uy; ey - r*uy]);
        ok = cx >= 1 & cx <= W & cy >= 1 & cy <= H;
        A = accumarray([cy(ok) cx(ok)], 1, [H W]);
        A = conv2(A, ones(3), 'same');
        acc(:, :, k) = single(A / (2*pi*r));
    end

    % Extraction itérative des maxima locaux
    circles = zeros(0, 4);
    work = acc;
    [Xg, Yg] = meshgrid(1:W, 1:H);
    for it = 1:maxCircles
        [s, idx] = max(work(:));
        if s < minScore, break; end
        [cy0, cx0, k0] = ind2sub(size(work), idx);
        
        prof = squeeze(acc(cy0, cx0, :));
        lm = find(prof(2:end-1) >= prof(1:end-2) & prof(2:end-1) >= prof(3:end)) + 1;
        kOuter = max(lm(prof(lm) >= max(minScore, 0.6 * s)));
        if ~isempty(kOuter) && kOuter > k0
            k0 = kOuter;
            s = prof(k0);
        end
        
        % Interpolation parabolique fine du rayon
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
