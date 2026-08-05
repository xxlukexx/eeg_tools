function tests = test_eegPeakCompatibility
%TEST_EEGPEAKCOMPATIBILITY Legacy missing-condition and display support.

    tests = functiontests(localfunctions);
end

function testFindPeakReturnsEmptyForMissingErp(testCase)

    [amplitude, latency] = eegFindPeak([], [0.1, 0.2], 'Cz');

    verifyEmpty(testCase, amplitude)
    verifyEmpty(testCase, latency)
end

function testStorePeakLeavesMissingErpEmpty(testCase)

    erp = eegStorePeak([], 'P1', 'Cz', 3.2, 0.15);

    verifyEmpty(testCase, erp)
end

function testFindPeakStillUsesCanonicalOutputs(testCase)

    erp = struct;
    erp.time = [0, 0.1, 0.2, 0.3];
    erp.label = {'Cz'};
    erp.avg = [1, 4, 2, -3];

    [positiveAmplitude, positiveLatency] = ...
        eegFindPeak(erp, [0.1, 0.3], 'Cz', 'positive');
    [negativeAmplitude, negativeLatency] = ...
        eegFindPeak(erp, [0.1, 0.3], 'Cz', 'negative');

    verifyEqual(testCase, positiveAmplitude, 4)
    verifyEqual(testCase, positiveLatency, 0.1)
    verifyEqual(testCase, negativeAmplitude, -3)
    verifyEqual(testCase, negativeLatency, 0.3)
end

function testPeakFinderExposesOptionalXLimits(testCase)

    classMetadata = meta.class.fromName('tePeakFinder_local');
    propertyNames = {classMetadata.PropertyList.Name};

    verifyTrue(testCase, ismember('XLim', propertyNames))
end
