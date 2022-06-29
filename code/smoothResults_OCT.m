function output = smoothResults_OCT(aReadout)
    output = smooth(aReadout, 7);
%     output(output<0) = 0;
%     
%     figure, plot(aReadout);
%     hold on,
%         plot(output, 'r*');
%         plot(medfilt1(aReadout, 9), 'b.');
end
