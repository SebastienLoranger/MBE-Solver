classdef Ideal_S < MBE.Fiber.fiber
    %Fiber model
    %   Simplified waveguide optimized for lowest Stokes. 
    %   Fundamental mode only. 
    %   Beta not defined by fiber, but by target values
    %   Only overlap between last Stokes and all other comb lines can be
    %   adjusted. It is supposed that all other overlaps are 1.
    
    properties

        loss = 0;        %Loss (dB/m). Scalar: uniform to all modes; Vector: specific loss for each mode
        dBetaS = 0;      % Phase-matching offset (m^-1) from ideal case
        dBetaAS = 1000;     % Phase mismatched for AS. Scalar: uniform to all AS. Vector: specific to each AS line.

        overlap(:,1) = [1;1];     %1st line: Overlap low-Stokes/Pump (lowest Stokes)  with its own Q-wave, 2nd line: Overlap low-Stokes/Pump (lowest Stokes) on main Q-wave (cross-Q)

        thick(1,1) = 500e-9;        %Core-wall thickness
        AreaRatio(1,1) = 0.25;   %Area ratio between pump and last Stokes. Only used if Q-wave of last Stokes is used.
    end

    
    methods
        
        function [varargout]=SRPCF_dispersion(obj,medium,wl)

            %%% Choice of the filling gas %%%
            ngas=medium.ngas(wl);
            
            ka0=2*pi./wl;
            u01=2.40482555769577;
            x=wl.*1e6; %%% lambda in micrometers
            ng=sqrt(1+0.6961663./(1-(0.0684043./x).^2)+0.4079426./(1-(0.1162414./x).^2)+0.8974794./(1-(9.896161./x).^2));     
            phi1=ka0.*obj.thick.*sqrt(ng.^2-ngas.^2);
            epsilon=(ng./ngas).^2;
            R=1.072*(obj.Dcore/2); %%% this pre-factor accounts for the effective negative core contour in single-ring ARR-PCF

            n_Jena=ngas-u01^2./(2*ka0.^2.*ngas.*R^2)-(0.5*(epsilon+1)).*(u01^2./(ka0.^3.*ngas.^2.*R^3)).*(cot(phi1)./sqrt(epsilon-1));
            beta=n_Jena.*ka0;
            
            %%%% OUTPUT ARGUMENTS %%%%
            varargout(1)={beta};
            varargout(2)={n_Jena};
        end

        function B = GenrateBeta(obj,medium, wl)
            %w: wavelengths. Must be at least size 3
            %Array size from Stokes to anti-Stokes
            if mod(length(wl),2)~=1
                error('number of requested fields does not match with this model')
            end
            

            %Calculate beta
            B=obj.SRPCF_dispersion(medium,wl);
            
            
            if length(wl)>1
                np=(length(wl)-1)/2+1;
                B(1)=2*B(np-1)-B(np)+obj.dBetaS; %Phase matching condition
            %Add anti-Stokes dephasing
                if length(obj.dBetaAS) >= length(wl)-np
                    ASdephase=obj.dBetaAS;
                else
                    ASdephase=obj.dBetaAS.*ones(1,length(wl)-np);
                end
                for i=np+1:length(wl)
                    B(i)=B(i-1)+(B(np)-B(np-1))+ASdephase(i-np);
                end
            end
            
        end

        function alpha = GenrateAlpha(obj, wl)

            %Calculate alpha
            if isempty(obj.loss)
                alpha=zeros(1,length(wl));
            elseif length(obj.loss)==1
                alpha=abs(obj.loss.*ones(1,length(wl))*log(10)/10);
            else
                alpha=zeros(1,length(wl));
                if numel(obj.loss)==length(obj.loss)
                    for i=1:length(alpha)
                        alpha(i)=abs(obj.loss(i)*log(10)/10);
                    end
                elseif size(obj.loss,1)>= length(alpha) && ismatrix(obj.loss)
                    alpha=abs(obj.loss(1:length(alpha),1)*log(10)/10);
                elseif size(obj.loss,2)>= length(alpha) && ismatrix(obj.loss)
                    alpha=abs(obj.loss(1,1:length(alpha))*log(10)/10);
                end
            end
        end

        function [s] = GenrateOverlap(obj,wl,~)


            s=GenrateOverlap@MBE.Fiber.fiber(obj, wl,1);
            %Overlap between current generated Stokes and its pump
            if length(obj.overlap) == 1; obj.overlap=[obj.overlap; obj.overlap]; end
            s(1,1)=obj.overlap(1);
            s(1,2:end)=obj.overlap(2).*ones(1,size(s,2)-1);
            s(2:end,1)=obj.overlap(2).*ones(size(s,2)-1,1);

        end

        function A = Area(obj)
            A = 1.8.*(obj.Dcore/2).^2;
        end


    end
end
