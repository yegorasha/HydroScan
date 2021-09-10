classdef PicoScope < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ps5000aDeviceObj
        sigGenGroupObj
        blockGroupObj
        timeIntervalNanoseconds
        timebaseIndex
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
            [status.setChA] = invoke(obj.ps5000aDeviceObj, 'ps5000aSetChannel', 0, 1, 1, 8, 0.0);
            [status.setChB] = invoke(obj.ps5000aDeviceObj, 'ps5000aSetChannel', 1, 0, 1, 8, 0.0);
            [status.setChC] = invoke(obj.ps5000aDeviceObj, 'ps5000aSetChannel', 2, 0, 1, 8, 0.0);
            [status.setChD] = invoke(obj.ps5000aDeviceObj, 'ps5000aSetChannel', 3, 0, 1, 8, 0.0);
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
                if ( status.getTimebase2 == 0 & timeIntervalNanoseconds == 4 )
                    break;
                else
                    timebaseIndex = timebaseIndex + 1;
                end
            end
            set(obj.ps5000aDeviceObj, 'timebase', timebaseIndex);
            
            obj.timeIntervalNanoseconds = timeIntervalNanoseconds;
            obj.timebaseIndex = timebaseIndex;
            
            [status.getTimebase2, timeIntervalNanoseconds, maxSamples] = invoke(obj.ps5000aDeviceObj, ...
                    'ps5000aGetTimebase2', timebaseIndex, 0);
                fprintf('Scope timebase index %d with interval of %6.4f ns and %d samples IS SET\n',...
                    timebaseIndex, timeIntervalNanoseconds, maxSamples);
            
        end
        
        function configure_scope_acquisition(obj, AcqTimeNanoSeconds)
            
            if ~isempty(obj.timeIntervalNanoseconds)
                np = round(AcqTimeNanoSeconds/obj.timeIntervalNanoseconds)
            else
                np = str2num( get(obj.ps5000aDeviceObj, 'numPreTriggerSamples') );
            end
            set(obj.ps5000aDeviceObj, 'numPreTriggerSamples', np);
        end
        
        function configure_generator(obj, CarrierFrequency_Hz, NumberCycles, RepeatFrequency_Hz, Amplitude_V, PulseType)
            %%
            % Obtain Signalgenerator group object. Signal Generator properties and functions
            % are located in the Instrument Driver's Signalgenerator group
            sigGenGroupObj = get(obj.ps5000aDeviceObj, 'Signalgenerator');
            obj.sigGenGroupObj = sigGenGroupObj(1);
            

            
            %%
            % Prepare arbitrary waveform for generator assuming certain repetition
            % frequency and awgBufferSize
%             RepeatFrequency_Hz = 100000;
            set(obj.sigGenGroupObj, 'startFrequency', RepeatFrequency_Hz);
            set(obj.sigGenGroupObj, 'stopFrequency', RepeatFrequency_Hz);
            set(obj.sigGenGroupObj, 'offsetVoltage', 0.0);
            set(obj.sigGenGroupObj, 'peakToPeakVoltage', Amplitude_V*1e3);
            
            
            awgBufferSize = get(obj.sigGenGroupObj, 'awgBufferSize');
%             x = 0:(2*pi)/(awgBufferSize - 1):2*pi;
            t = (0:(2*pi)/(awgBufferSize - 1):2*pi)/RepeatFrequency_Hz/2/pi; % seconds
            TendPulse = NumberCycles/CarrierFrequency_Hz;
            
%             y0 = sin(x*CarrierFrequency_Hz/RepeatFrequency_Hz).*( (x*CarrierFrequency_Hz/RepeatFrequency_Hz) < (2*pi*NumberCycles) );
            y0 = sin(2*pi*CarrierFrequency_Hz*t).*( t < TendPulse  );
            
            switch PulseType
                case 'Sinusoidal'    
                    y1 = y0;
                case 'Gaussian'
                    Sigma = TendPulse/2 / (2*sqrt(2*log(2)));
                    CenterPos = TendPulse/2;
                    y1 = y0/sqrt(2*pi*Sigma).*exp(-(t-CenterPos).^2/2/Sigma^2);
                case 'Chirp'
                    F0 = CarrierFrequency_Hz/2;
                    F1 = CarrierFrequency_Hz*2;
                    
                    y1 = chirp(t,F0,TendPulse,F1,'linear').*( t < TendPulse  );
            end
            
            y = normalise(y1);
%             figure(11), plot(t*1e6,y), grid, title('DEBUG info')
%             return
            
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
%             numSamples

            tin = obj.timeIntervalNanoseconds;
        end
        
    end
end

