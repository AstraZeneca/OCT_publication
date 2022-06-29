function qc_showAnnotation(gTruth)

    saveDir = sprintf('%s/qc', pwd);

    flag = exist(saveDir, 'dir');
    if flag ~= 7
        mkdir(saveDir);
    end

    for i = 1:length(gTruth.DataSource.Source)
        f = imread(gTruth.DataSource.Source{i});
        g = imread(gTruth.LabelData.PixelLabelData{i});

        f1 = imoverlay(f, g == 1, [255 0 0], 1);
        f1 = imoverlay(f1, g == 2, [0 255 0], 1);
        f1 = imoverlay(f1, g == 3, [0 0 255], 1);
        f1 = imoverlay(f1, g == 4, [255 255 0], 1);
        f1 = imoverlay(f1, g == 5, [255 0 255], 1);
        f1 = imoverlay(f1, g == 6, [0 255 255], 1);
        f1 = imoverlay(f1, g == 7, [255 255 255], 1);

        temp = montage(cat(4, cat(3, f, f, f), f1), 'BorderSize' ,10, 'BackgroundColor', 'white');

        aString = sprintf('%s/qc_%d.jpg', saveDir, i);
        imwrite(temp.CData, aString);

        close all;
    end
end
