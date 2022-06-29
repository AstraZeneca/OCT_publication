function [axes1, aPatch] = az_showLabelMat3D_OCT(i_labelMat, figure1, i_displayMode)

    if nargin <= 2 || isempty(i_displayMode)
        i_displayMode = 'Full';
    end

    if nargin <= 1 || isempty(figure1)
        figure1 = figure('Color',[0 0 0]);
    end
    
    
    hPanel = uipanel('Parent', figure1, 'units','normalized', 'BackgroundColor','black');
    set(hPanel,'Position',[0 0 1 1]);
    
    
%%___________________________________________________
%%
    [mL, nL, zL] = size(i_labelMat);
    
    bw = zeros(mL + 2, nL + 2, zL + 2);
    
    for i = 2:zL+1
        bw(:, :, i) = padarray(i_labelMat(:, :, i-1), [1 1], 0);
    end
  
    [mL, nL, zL] = size(bw);
    
    x = 1:nL;    %-- note this is "n"
    y = 1:mL;    %-- note this is "m"
    z = 1:zL;
    [XL, YL, ZL] = meshgrid(x, y, z);
%%___________________________________________________
%%
    axes1 = axes('Parent',hPanel,...
                'Color',[0 0 0],...
                'ZColor',[1 1 0],...
                'YColor',[1 1 0],...
                'XColor',[1 1 0],...
                'MinorGridColor',[1 1 1],...
                'GridColor',[0.75 0.75 0],...
                'boxstyle', 'full');
            
    axis ij;

    view(axes1,[180 -75]);
    
    cmap = summer(max(bw(:))); % always jet for now..
    cmap = cmap(randperm(size(cmap,1)),:);

    if isempty(cmap)
        aPatch = [];
        return;
    end
    
    for ii = 1:size(cmap,1)

        [faces, verts, ~] = isosurface(XL, YL, ZL, bw==ii, 0, bw==ii);
        aPatch{ii} = patch('Vertices', verts,...
                           'Faces', faces, ... 
                           'FaceColor', cmap(ii,:),... 
                           'edgecolor', 'none',...
                           'parent', axes1, ...
                           'FaceAlpha', 1);
    end
    
    daspect([1,1,1])
    
%     view(3);
    
    if strcmp(i_displayMode, 'Full') == 1
        xlim(axes1, [1, nL]);
        ylim(axes1, [1, mL]);
        zlim(axes1, [1, zL]);
    else
        axis tight
    end

    grid(axes1,'on');
    grid(axes1,'minor');
    box(axes1,'on');

    zlabel('z');
    ylabel('y');
    xlabel('x');
    
    camlight 
    lighting gouraud
    
    delete aPatch
end