function [x,P,y_res] = correctionGPS(x_pred,P_pred,x_sam,y_sam,z_sam,sigma_GPS,sats,fix)
%13/11/2020  ANY QUESTIONS CAN BE DIRECTED TO ALEJANDRO MONTERO FROM SKYWARD

%-----------DESCRIPTION OF FUNCTION:------------------

%STATE SPACE ESTIMATOR (CORRECTION STEP FOR GPS) FOR LINEAR MOVEMENT OF
%ROCKET AND ATTITUDE DYNAMICS
%THE DYNAMIC SYSTEM DESCRIPTION IS:
%       x' = f(x,u) + w         F=df/dx --> F IS THE GRADIENT OF f
%                                           EVALUATED AT EACH ESTIMATION 
%                               w is process noise --> Q IS ITS COVARIANCE
%       z  = h(x,u) + v         H=dh/dx --> H IS THE GRADIENT OF h
%                                           EVALUATED AT EACH ESTIMATION
%                               v is measurement noise --> R IS ITS
%                               COVARIANCE
%       -INPUTS:
%           -x_pred:    1x6 VECTOR OF PREDICTED VALUES --> 3 FIRST STATES
%                       ARE X , Y AND H, THE FOLLOWING THREE ARE VX, VY AND VZ
%                       
%           -P_pred:    6x6 MATRIX OF PREDICTED COVARIANCE OF STATE
%           -x_sam:     MEASUREMENT OF X FROM GPS AT TIME T --> 1x1
%           -y_sam:     MEASUREMENT OF Y FROM GPS AT TIME T --> 1x1
%           -z_sam:     MEASUREMENT OF Z FROM GPS AT TIME T --> 1x1
%           -sigma_GPS: VARIANCE OF THE GPS
%           -sats:      NUMBER OF AVAILABLE SATELITES FOR THE GPS
%           -fix:       BINARY VARIABLE WHICH DESCRIBES THE LEVEL OF TRUST
%                       OF THE GPS
%
%       -OUTPUTS:
%           -x_es:      STATE ESTIMATION CORRECTED AT T. VECTOR WITH 6 COLUMNS
%           -P:         MATRIX OF VARIANCE OF THE STATE AT T, CORRECTED--> IS A
%                       6 x 6 matrix
%           -y_res:     VECTOR OF DIFFERENCES BETWEEN THE CORRECTED ESTIMATION 
%                       OF THE OUTPUT AND THE MEASSURE; ONLY FOR CHECKING
%                       --> 1x3
%---------------------------------------------------------------------------
threshold      =   10e-3;
H              =   sparse(3,6);                 %Pre-allocation of gradient 
                                                 %of the output function 
H(1,1)         =   1;
H(2,2)         =   1;
H(3,3)         =   1; 

R              =   diag(sigma_GPS^2*ones(3,1)/sats); %VARIANCE MATRIX SCALED 
                                                     %TAKING INTO ACCOUNT
                                                     %NUMBER OF SATELITES
                                                     %AVAILABLE

if fix==1

z              =   [x_pred(1);x_pred(2);x_pred(3);];

e              =   [x_sam;y_sam;z_sam] - z;

S              =   H*P_pred*H'+R;                    %Matrix necessary for the correction factor

    if cond(S) > threshold 

        K              =   P_pred*H'/S;              %Kalman correction factor

        x              =   x_pred + (K*e)';          %Corrector step of the state
        

        P              =   (eye(6) - K*H)*P_pred;   %Corrector step of the state covariance
    else
        x              =   x_pred;
        P              =   P_pred;
    end
else
x              =   x_pred;
P              =   P_pred;
end

z_corr         =   [x(1);x(2);x(3);];                %Corrected output expectation

y_res          =    [x_sam;y_sam;z_sam] - z_corr;
end