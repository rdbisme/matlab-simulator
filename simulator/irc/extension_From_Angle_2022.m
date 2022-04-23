function [x] = extension_From_Angle_2022(alpha,settings)
% HELP
% alpha must be already in radiants
%
% input:
% alpha: servo angle reference
% settings: a struct containing everything basically

switch settings.rocketName

    case 'Pyxis'

        x = settings.arb.extPol(1)*alpha.^4 + settings.arb.extPol(2)*alpha.^3+settings.arb.extPol(3)*alpha.^2 + settings.arb.extPol(4).*alpha;
    
    case 'Lynx'

        % Obtain delta_S given the servomotor angle
        a = -9.43386/1000;
        b = 19.86779/1000;
        delta_S = a*(alpha^2) + b*alpha;
        % delta_S [m^2] = (-9.43386 * alpha^2 + 19.86779 * alpha) * 10^(-3), with alpha in [rad] from 0 to 0.89 rad.
        
        % Obtain aerobrakes extension given the delta_S
        a = -1.04034;
        b = 0.30548;
        x = (-b + sqrt(b^2 + 4*a*delta_S)) / (2*a);
        % A [m^2] = -1.04034 * x^2 + 0.30548 * x, with x in [m] from 0 to 0.03866 m;

end