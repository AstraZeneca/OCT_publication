function plotAStat2_OCT(anAxes, aStat, yMax, xTicks, xLabel, yLabel, aTitle, fontSize, aFaceColor)
%     h1 = bar(anAxes, aStat, 'FaceColor','g', 'EdgeColor', 'g');
    if nargin <= 8
        aFaceColor = [];
    end

    if isempty(fontSize)
        fontSize = 8;
    end

    h1 = bar(anAxes, aStat, 'stacked', 'EdgeColor','none');
%     h1 = area(anAxes, aStat);

    grid(anAxes,'on');
    grid(anAxes,'minor');
    box(anAxes,'on');

    ylabel(anAxes, yLabel, 'Fontsize', fontSize);
    xlabel(anAxes, xLabel, 'Fontsize', fontSize);

    if ~isempty(xTicks)
        
        aString = 1:length(aStat);
        xticks(anAxes, aString);
        
        xticklabels(anAxes, xTicks);
        xtickangle(anAxes, 45);
        
        set(anAxes,'fontsize',fontSize);
    end

    if ~isempty(yMax)
        ylim(anAxes, [0, sum(yMax)]);
    end
    
    if ~isempty(aTitle)
        title(aTitle, 'Fontsize', fontSize);
    end
    
    if ~isempty(aFaceColor) 
        h1.FaceColor = aFaceColor;
    end
    
    if size(aStat, 2) == 4
        legend('Collagen', 'Sponginess', 'NeoEpidermis', 'Clots');
    elseif size(aStat, 2) == 3
        legend('Collagen', 'Sponginess', 'NeoEpidermis');
    elseif size(aStat, 2) == 2
        legend('Collagen', 'Sponginess');
    elseif size(aStat, 2) == 1
        legend('Collagen');
    else
        legend('off');
    end
end
