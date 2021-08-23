classdef MotorXYZT < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        seport = [];
        curloc = [0 0 0 0];
        motor_speed = 2000;
        calibr = [[1 1 1]/(0.00025*25.4/4) 1/(0.0100)]; % step/mm and last one step/degree
        % Velmex stages
    end
    
    methods
        
        function status = connect(obj, port)
            status = 0;
            fprintf('Connecting to motor port %s\n',port)
            ports = serialportlist
            if ~isempty(obj.seport)
                delete(obj.seport);
            end
            try
                obj.seport = serialport(port,9600);
                sendcmd2serial(obj,'C,F,R');
                status = 1;
            catch
                fprintf('ERROR connecting to motor port %s\n',port)
            end
        end
        
        function disconnect(obj)
            fprintf('Disconnecting from motor port\n')
            delete(obj.seport);
        end
        
        function move_relative(obj, motor_number, rel_distance)
            fprintf('Moving motor %d by %5.2f\n', motor_number, rel_distance);
            
            MotorStep = round( rel_distance * obj.calibr(motor_number) );
            MotorCmd = sprintf('C,S%1dM%d,I%1dM%d,R', motor_number, obj.motor_speed, motor_number, MotorStep);
            sendcmd2serial(obj, MotorCmd);
            obj.curloc(motor_number) = obj.curloc(motor_number) + rel_distance;
        end
        
        function move_absolute(obj, motor_number, location)
            fprintf('Moving motor %d to location %5.2f\n', motor_number, location);
            
            MotorStep = round( location * obj.calibr(motor_number) );
            MotorCmd = sprintf('C,S%1dM%d,IA%1dM+%d,R', motor_number, obj.motor_speed, motor_number, MotorStep);
            sendcmd2serial(obj, MotorCmd);
            obj.curloc(motor_number) = location;
        end
        
        function sethome(obj)
            disp('Setting motors home in current location')
            sendcmd2serial(obj, 'F,C,IA1M-0,IA2M-0,IA3M-0,IA4M-0,R')
            obj.curloc = [0 0 0 0];
        end
        
        function gohome(obj)
            sendcmd2serial(obj, 'F,C,IA1M0,IA2M0,IA3M0,IA4M0,R');
            obj.curloc = [0 0 0 0];
        end
        
        function sendcmd2serial(obj, cmd)
            try,
%                 disp(' * * *')
%                 obj.seport
%                 cmd
%                 disp(' * * *')
%                 fprintf(obj.seport, cmd);
                writeline(obj.seport, cmd);
            catch,
                disp(sprintf('ERORR: %s failed',cmd))
            end
        end
    end
end

