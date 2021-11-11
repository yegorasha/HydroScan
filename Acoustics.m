classdef Acoustics < handle
    %UNTITLED3 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        pressure
    end
    
    methods
        
        function val = rms(obj, s)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            val = sqrt( (s'*s) / length(s) );
        end

        
    end
end

