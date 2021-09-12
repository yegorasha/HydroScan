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
        
        function y = high_pass_filter(obj, x,Fs,fhp)
            
%             t= 0:(1/Fs):1;   % Time Vector
            N = length(x);
            
            %Compute Hamming window
%             hamm = 0.53836-0.46164*cos(2*pi*(1:N)/N);
            
            f = linspace(-1,1,N)'*Fs/2;
            HPF = fftshift(abs(f)>fhp);
            
            X=fft(x,N);
            y = real(ifft(HPF.*X,N));
        end
        
    end
end

