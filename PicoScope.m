classdef PicoScope < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ps5000aDeviceObj
        sigGenGroupObj
        blockGroupObj
        timeIntervalNanoseconds
    end
    
    methods
        
        function connect(obj)
            h = instrfind('Type','scope');
            if ~isempty(h)
                disconnect(h);
                delete(h);
            end
            if ~isempty(obj.ps5000aDeviceObj)
                if (obj.ps5000aDeviceObj.isvalid && strcmp(obj.ps5000aDeviceObj.status, 'open'))
                    disconnect(obj.ps5000aDeviceObj);
                    delete(obj.ps5000aDeviceObj);
                end
            end
            obj.ps5000aDeviceObj = icdevice('picotech_ps5000a_generic.mdd');
            connect(obj.ps5000aDeviceObj);
        end
        
        function disconnect(obj)
            if (obj.ps5000aDeviceObj.isvalid && strcmp(obj.ps5000aDeviceObj.status, 'open'))
                disconnect(obj.ps5000aDeviceObj);
                delete(obj.ps5000aDeviceObj);
            end
        end
        
        function configure_scope(obj)
            %%
            % Configure 2 scope channels for acquisition (after ID_Block_Example)
            [status.setChA] = invoke(obj.ps5000aDeviceObj, 'ps5000aSetChannel', 0, 1, 1, 8, 0.0)
            [status.setChB] = invoke(obj.ps5000aDeviceObj, 'ps5000aSetChannel', 1, 0, 1, 8, 0.0)
            [status.setChC] = invoke(obj.ps5000aDeviceObj, 'ps5000aSetChannel', 2, 0, 1, 8, 0.0)
            [status.setChD] = invoke(obj.ps5000aDeviceObj, 'ps5000aSetChannel', 3, 0, 1, 8, 0.0)
            % Block data acquisition properties and functions are located in the
            % Instrument Driver's Block group.
            blockGroupObj = get(obj.ps5000aDeviceObj, 'Block');
            obj.blockGroupObj = blockGroupObj(1);
            
            %%
            % Set device resolution
            [status.setResolution, resolution] = invoke(obj.ps5000aDeviceObj, 'ps5000aSetDeviceResolution', 12);
            
            %%
            % timebases are vaguely described in section 3.6 of the manual
            status.getTimebase2 = 14;
            timebaseIndex = 0;
            
            while (status.getTimebase2 == 14)
                
                [status.getTimebase2, timeIntervalNanoseconds, maxSamples] = invoke(obj.ps5000aDeviceObj, ...
                    'ps5000aGetTimebase2', timebaseIndex, 0);
                fprintf('Timebase index %d has time interval %6.4f ns and %d samples\n',...
                    timebaseIndex, timeIntervalNanoseconds, maxSamples);
                if (status.getTimebase2 == 0)
                    break;
                else
                    timebaseIndex = timebaseIndex + 1;
                end
            end
            set(obj.ps5000aDeviceObj, 'timebase', timebaseIndex);
            
            obj.timeIntervalNanoseconds = timeIntervalNanoseconds;
            
        end
        
        function configure_generator(obj, CarrierFrequency, NumberCycles)
            %%
            % Obtain Signalgenerator group object. Signal Generator properties and functions
            % are located in the Instrument Driver's Signalgenerator group
            sigGenGroupObj = get(obj.ps5000aDeviceObj, 'Signalgenerator');
            obj.sigGenGroupObj = sigGenGroupObj(1);
            
            %%
            % Prepare arbitrary waveform for generator assuming certain repetition
            % frequency and awgBufferSize: half of the buffer filled with 10 MHz tone
            % and remaining half of the buffer filled with zero
            RepetitionFrequency = 100000;
            set(obj.sigGenGroupObj, 'startFrequency', RepetitionFrequency);
            set(obj.sigGenGroupObj, 'stopFrequency', RepetitionFrequency);
            set(obj.sigGenGroupObj, 'offsetVoltage', 0.0);
            set(obj.sigGenGroupObj, 'peakToPeakVoltage', 4000.0);
            
            awgBufferSize = get(obj.sigGenGroupObj, 'awgBufferSize')
            x = 0:(2*pi)/(awgBufferSize - 1):2*pi;
            
%             fc = CarrierFrequency; % Carrier frequency Hz
            y = normalise(sin(CarrierFrequency/RepetitionFrequency*x)).*(CarrierFrequency/RepetitionFrequency*x<NumberCycles);
            % this was the call to set waveform into generator
            % [status.setSigGenArbitrarySimple] = invoke(sigGenGroupObj, 'setSigGenArbitrarySimple', y);
            
            %%
            % Set trigger parameters for signal generator. The first sample in the arbitrary
            % waveform will occure once scope is acquiring
            offsetMv 			= 0;
            pkToPkMv 			= 2000;
            increment 			= 0; % Hz
            dwellTime 			= 0; % seconds
            sweepType 			= 0;
            operation 			= 0;
            indexMode 			= 0;
            shots 				= 1;
            sweeps 				= 0;
            triggerType 		= 0;
            triggerSource 		= 1;
            extInThresholdMv 	= 0;
            
            [status.setSigGenArbitrary] = invoke(obj.sigGenGroupObj, 'setSigGenArbitrary', increment, dwellTime, y, sweepType, ...
                operation, indexMode, shots, sweeps, triggerType, triggerSource, extInThresholdMv);
            
        end
        
        function [chA, tin] = pulse(obj)
            %%
            % Acquire one block. This acquisition is expected to trigger generator to
            % deliver a precofigured burst
            [status.runBlock] = invoke(obj.blockGroupObj, 'runBlock', 0);
            
            %%
            % Retrieve acquired response
            startIndex              = 0;
            segmentIndex            = 0;
            downsamplingRatio       = 1;
            downsamplingRatioMode   = 0;
            [numSamples, overflow, chA, chB] = invoke(obj.blockGroupObj, 'getBlockData', startIndex, segmentIndex, ...
                downsamplingRatio, downsamplingRatioMode);

            tin = obj.timeIntervalNanoseconds;
        end
        
    end
end

