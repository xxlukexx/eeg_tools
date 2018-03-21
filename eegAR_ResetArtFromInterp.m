function data = eegAR_ResetArtFromInterp(data)
% data = EEGAR_RESETARTFROMINTERP(data) resets artefacts of any type in
% DATA.art when they are marked as successfully interpolated in
% DATA.interp. 
%
% This is useful when artefacts have been detected (by whatever method) and
% marked in DATA.art, but are then interpolated. Those trial x channel
% segments that have been successfully interpolated are now "clean" - the
% original artefact is (hopefully) no longer present. After interpolation,
% a subsequent run of artefact detection may be required to check these
% apaprently clean, interpolated channels, to ensure no residual artefact
% is present. This function does not do this, it simply removes artefact
% marks from interpolated segments. 

    % check for fields
    if ~isfield(data, 'art')
        error('Missing .art field.')
    end
    if ~isfield(data, 'interp')
        error('Missing .interp field.')
    end
    
    % make interp structure same depth to match number of .art levels
    numLev = size(data.art, 3);
    interp = repmat(data.interp, 1, 1, numLev);
    
    % remove marks for interpolated segments
    data.art(interp) = false;

end