function [alpha_degree, Vz_setpoint, z_setpoint] = controlAlgorithmLinearized(z,Vz,V_mod,sample_time)

% Define global variables
global data_trajectories coeff_Cd 
global Kp Ki I alpha_degree_prec index_min_value iteration_flag chosen_trajectory saturation


%% TRAJECTORY SELECTION and REFERENCES COMPUTATION

if iteration_flag == 1 % Choose the nearest trajectory ( only at the first iteration )
    
best_min = inf;
best_index = inf;

for ind = 1:length(data_trajectories)

% Select a z trajectory and a Vz trajectory
z_ref = data_trajectories(ind).Z_ref(1:50); % To speed up select only the first values, not ALL
Vz_ref = data_trajectories(ind).V_ref(1:50); % To speed up select only the first values, not ALL
distances_from_current_state = (z_ref-z).^2 + (Vz_ref-Vz).^2; % sqrt is avoidable

% Find the nearest point to the current trajectory
[min_value, index_min_value] = min( distances_from_current_state ); 

if (min_value < best_min)
    best_min = min_value;
    best_index = index_min_value;
    chosen_trajectory = ind;  
end

end

% Save the actual index to speed up the research
index_min_value = best_index;

% I select the reference altitude and the reference vertical velocity
z_setpoint  =  data_trajectories(chosen_trajectory).Z_ref(index_min_value)
Vz_setpoint =  data_trajectories(chosen_trajectory).V_ref(index_min_value)

iteration_flag = 0; % Don't enter anymore the if condition

else  % For the following iterations keep tracking the chosen trajectory

% Select the z trajectory and the Vz trajectory 
% To speed up the research, I reduce the vector at each iteration
z_ref =  data_trajectories(chosen_trajectory).Z_ref;   % .Z_ref( index_min_value-5 : end );
Vz_ref = data_trajectories(chosen_trajectory).V_ref;

% 1) Find the value of the altitude in z_reference nearer to z_misured 
% [~, index_min_value] = min( abs(z_ref - z) );

% 2) Find the reference using Vz(z)
distances_from_current_state = (z_ref-z).^2 + (Vz_ref-Vz).^2; 
[~, index_min_value] = min( distances_from_current_state ); 

z_setpoint = z_ref(index_min_value);
Vz_setpoint = Vz_ref(index_min_value);


% % I select the reference altitude and vertical velocity
% % The reference altitude must NOT be below the current altitude
% if ( z_ref(index_min_value) <= z && index_min_value+1 < length(z_ref) )
%     indice=index_min_value+1
%     real = z
%     z_setpoint = z_ref(index_min_value+1)
%     real = Vz
%     Vz_setpoint = Vz_ref(index_min_value+1)
% else
%     indice=index_min_value
%     real = z
%     z_setpoint = z_ref(index_min_value)
%     real = Vz
%     Vz_setpoint = Vz_ref(index_min_value)
% end

%%%%%%%%%%%%%%%%%%%%%%%%%% scorro ogni valore array in successione senza logica
% index_min_value = index_min_value +1;
% z_setpoint = z_ref(index_min_value);
% Vz_setpoint = Vz_ref(index_min_value)
%%%%%%%%%%%%%%%%%%%%%%%%%%

end  


%% PID ALGORITHM

% If e>0 the rocket is too fast. I slow it down with Fx>0 --> open aerobrakes
% If e<0 the rocket is too slow. I speed it up with Fx<0 --> close aerobrakes

Umin = -1200;  % U_min = -22*9.8 - 0.5*1.225*(0.0201+0.01)*1*250^2
Umax = -220;   % U_max = -22*9.8
dt = 0.1;      % se viene modificato, bisogna modificare pure i PID values

error = (Vz_setpoint - Vz); % cambiato il segno

P = Kp*error;

if saturation == false
I = I + Ki*error*dt;
end

U = P + I;
    
if ( U < Umin)  
U=Umin; 
saturation = true;                                         
elseif ( U > Umax) 
U=Umax; 
saturation = true;                          
else
saturation = false;
end

%% TRANSFORMATION FROM U to delta_S

% Parameters
m = 22;
g = 9.81;
ro = getRho(z);
diameter = 0.15; 
S0 = (pi*diameter^2)/4;  

% Range of values for the control variable
delta_S_available = 0.0:0.001:0.01; 

% Get the Cd for each possible aerobrake surface
Cd_available = 1:length(delta_S_available);
for ind = 1:length(delta_S_available)
Cd_available(ind) = getDrag(V_mod,z,delta_S_available(ind), coeff_Cd);
end

delta_S_available = delta_S_available';
Cd_available = Cd_available';

% For all possible delta_S compute Fdrag.
% Then choose the delta_S which gives an Fdrag which has the minimum error if compared with F_drag_pid
% [~, index_minimum] = min( abs(U - 0.5*ro*S0*Cd_available*Vz*V_mod) ); 


U_linearization = -m*g-0.5*ro*S0*Cd_available*Vz*V_mod;
[~, index_minimum] = min( abs(abs(U) - abs(U_linearization)) ); % ????????????

% pid = U
% formula = U_linearization

% Cd_available = Cd_available(index_min_value)
delta_S = delta_S_available(index_minimum);  % delta_S belongs to [0; 0.01]

%% TRANSFORMATION FROM delta_S to SERVOMOTOR ANGLE DEGREES

% delta_S [m^2] = (-9.43386 * alpha^2 + 19.86779 * alpha) * 10^(-3). Alpha belongs to [0 ; 0.89 rad]
a = -9.43386/1000;
b = 19.86779/1000;

alpha_rad = (-b + sqrt(b^2 + 4*a*delta_S)) / (2*a);
% alpha_rad_rad = (-b - sqrt(b^2 + 4*a*delta_S)) / (2*a); % son sicuro che è sempre la prima?

% Alpha saturation
if (alpha_rad < 0)
    alpha_rad = 0;
elseif (alpha_rad > 0.89)
    alpha_rad = 0.89;
end

alpha_degree = (alpha_rad*180)/pi;

%% LIMIT THE RATE OF THE CONTROL VARIABLE

rate_limiter_max =  60/0.2; % datasheet: 60deg/0.13s --> increased for robustness
rate_limiter_min = -60/0.2;

rate = (alpha_degree - alpha_degree_prec) / sample_time;

if (rate > rate_limiter_max)
    alpha_degree = sample_time*rate_limiter_max + alpha_degree_prec;
elseif (rate < rate_limiter_min)
    alpha_degree = sample_time*rate_limiter_min + alpha_degree_prec;
end

alpha_degree_prec = alpha_degree;

% Testing:
% alpha_degree = 25;
% z_setpoint = 9;
% Vz_setpoint = 5;
end

