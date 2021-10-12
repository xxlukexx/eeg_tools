function eegFT_plotLightSensorMatch(data_ft, light)

    % default extent is 200ms either side of light sensor maker
    ext_s = [-0.200, 0.200];
    ext = round(ext_s * data_ft.fsample);

%     figure
    clf
    numLight = length(light.mrk_light_samps);
    mrk = light.mrk_light_samps;
    idx_chan = light.lightChannelIdx;
    numLightPerFig = 100;
    numFig = ceil(numLight / numLightPerFig);
    if numFig == 1
        nsp = numSubplots(numLight);
    else
        nsp = numSubplots(numLightPerFig);
    end

    ev = struct2table(data_ft.events);

    for f = 1:numFig
        
        fig(f) = figure('visible', 'off');
        
        l1 = 1 + ((f - 1) * numLightPerFig); 
        l2 = f * numLightPerFig;
        if l2 > numLight, l2 = numLight; end
        spCounter = 1;

        for l = l1:l2

            subplot(nsp(1), nsp(2), spCounter)
            set(gca, 'XTick', [])
            set(gca, 'YTick', [])
            spCounter = spCounter + 1;
            s = mrk(l) + ext;

            plot(s(1):s(2), data_ft.trial{1}(idx_chan, s(1):s(2)));
            hold on
            yl = ylim;
            line([mrk(l), mrk(l)], [yl(1), yl(2)], 'color', 'r')

            idx_ev = ev.sample >= s(1) & ev.sample <= s(2);
            if any(idx_ev)

                thisEv = ev(idx_ev, :);
                numEv = size(thisEv, 1);
                for e = 1:numEv
                    x = [thisEv.sample(e), thisEv.sample(e)];
                    line(x, yl, 'color', 'g')
                end

            end

            if ~isnan(idx(l))
                x = [ev.sample(idx(l)), ev.sample(idx(l))];
                line(x, yl, 'color', 'm')
            end

        end

    end

    arrayfun(@(x) set(x, 'visible', 'on'), fig)

end