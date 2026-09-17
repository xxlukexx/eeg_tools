function tests = test_eegAR_Detect
	tests = functiontests(localfunctions);
end


function setupOnce(testCase)
	repositoryRoot = fileparts(fileparts(mfilename('fullpath')));
	testCase.TestData.oldPath = path;
	addpath(repositoryRoot)
end


function teardownOnce(testCase)
	path(testCase.TestData.oldPath)
end


function testHistoricalDefaultsAndNoFigure(testCase)
	data = localData("uV");
	figuresBefore = findall(0, 'Type', 'figure');

	data = eegAR_Detect(data, ...
		'method', 'minmax', ...
		'threshold', [-100, 100]);

	verifyEqual(testCase, data.art_type, {'minmax'})
	verifyTrue(testCase, data.art(1, 2, 1))
	verifyFalse(testCase, data.art(2, 2, 1))
	verifyEqual(testCase, findall(0, 'Type', 'figure'), figuresBefore)
end


function testPhysicalThresholdConvertsToStoredUnits(testCase)
	data = localData("V");
	data.trial{2}(1, 3) = 150e-6;

	data = eegAR_Detect(data, ...
		'method', "minmax", ...
		'threshold', [-100, 100], ...
		'amplitude_unit', "uV");

	verifyTrue(testCase, data.art(1, 2, 1))
	verifyEqual(testCase, data.art_cfg{1}.amplitude_unit, "uV")
end


function testReplaceAndCombineAreExplicit(testCase)
	data = localData("uV");
	data = eegAR_UpdateArt(data, [true, false; false, false], 'manual');
	data = eegAR_UpdateArt(data, [false, true; false, false], 'manual');
	verifyEqual(testCase, data.art(:, :, 1), ...
		logical([true, true; false, false]))

	data = eegAR_UpdateArt( ...
		data, [false, true; false, false], 'manual', 'mode', 'replace');
	verifyEqual(testCase, data.art(:, :, 1), ...
		logical([false, true; false, false]))
end


function data = localData(unit)
	data = struct;
	data.label = {'Cz'; 'Pz'};
	data.fsample = 100;
	data.time = {0:0.01:0.04, 0:0.01:0.04};
	data.trial = {zeros(2, 5), zeros(2, 5)};
	data.trial{2}(1, 3) = 150;
	data.chanunit = {char(unit); char(unit)};
end
