function save_fig(fig, filename)
folder = fileparts(filename);
if ~isempty(folder) && ~exist(folder, 'dir'), mkdir(folder); end
if exist('exportgraphics', 'file')
    exportgraphics(fig, filename, 'Resolution', 150);
else
    print(fig, filename, '-dpng', '-r150');
end
end
