%-------------------------------------------------------------------------------
%                  MSAT - Matlab Seismic Anisotropy Toolkit 
%-------------------------------------------------------------------------------
% MS_phasevels - calculate the phase velocity details for a set of elastic 
%                 constants
%-------------------------------------------------------------------------------
% [pol,avs,vs1,vs2,vp] = MS_phasevels(C,rh,inc,azi)
%
%	Inputs:
%     
%     C = Stiffness tensor, in 6x6 Voigt notation, units of GPa, symmetry is
%            enforced.
%     rh = density (units of kg/m^3)
%
%		* inc and azi may be scalars, or vectors of the same size. *
%
%     AZI = angle from +ve 1-axis in x1-x2 plane                              
%           (deg, +ve c'wise looking at origin from 3-axis)                  
%     INC = angle from x1-x2 plane towards x3                                 
%           (deg, zero is in x1-x2 plane)                                     
%
%  Outputs: 
%
%     'pol' = angle in plane normal to raypath of FSW                           
%            (deg, zero is x3 direction, +ve c'wise looking along             
%            raypath at origin)  
%     'avs' = shear-wave anisotropy
%     'vs1' = fast shear-wave velocity (m/s)
%     'vs2' = slow shear-wave velocity (m/s)
%     'vp'  = P-wave velocity (m/s)
% 
%  See source code for further notes

% (C) James Wookey, 2007-2011
% Notes:   
% Based on EMATRIX6 by D. Mainprice. Re-coded in MATLAB by JW
%
% Reference: Mainprice D. (1990). An efficient
%            FORTRAN program to calculate seismic anisotropy from
%            the lattice preferred orientation of minerals.
%            Computers & Gesosciences, vol16, pp385-393.
%
%
function [pol,avs,vs1,vs2,vp] = MS_phasevels(C,rh,inc,azi)

		if (length(inc)~=length(azi))
			error('AZI and INC must be scalars or vectors of the same dimension');
		end	

%  ** convert GPa to MB file units (Mbars), density to g/cc
      C(:,:) = C(:,:) * 0.01 ;
      rh = rh ./ 1e3 ;
      
		avs = zeros(size(azi)) ;
		vp = zeros(size(azi)) ;
		vs1 = zeros(size(azi)) ;
		vs2 = zeros(size(azi)) ;
		pol = zeros(size(azi)) ;
		S1 = zeros(length(azi),3) ;
		S1P = zeros(length(azi),3) ;

%	** start looping
	for ipair = 1:length(inc)
		cazi = azi(ipair) ;
		cinc = inc(ipair) ;

%  ** create the cartesian vector
		XI = cart2(1,cinc,cazi) ;

%  ** compute phase velocities		
		[V,EIGVEC]=velo(XI,rh,C) ;
		
%  ** pull out the eigenvectors
		P  = EIGVEC(:,1) ;
      S1 = EIGVEC(:,2) ;

		if ~isreal(S1)
			S1
			fprintf('%f,%f\n',cinc,cazi)
			C_in
			error('bad') ;
		end
      S2 = EIGVEC(:,3) ;

%  ** calculate projection onto propagation plane      
      S1N = cross(XI,S1) ;
      S1P = cross(XI,S1N);

%  ** rotate into y-z plane to calculate angles
      [S1PR] = V_rot3(S1P,0,0,cazi) ;
	  [S1PRR] = V_rot3(S1PR,0,cinc,0) ;

	   ph = atan2(S1PRR(2),S1PRR(3)) .* 180/pi ;

%  ** transform angle to between -90 and 90
      if (ph < -90.), ph = ph + 180.;,end
      if (ph >  90.), ph = ph - 180.;,end

%	** calculate some useful values
		dVS =  (V(2)-V(3)) ;
      VSmean = (V(2)+V(3))/2.0 ;

      avs(ipair) = 100.0*(dVS/VSmean) ;
      vp(ipair) =  V(1) ;
      vs1(ipair) = V(2) ;
      vs2(ipair) = V(3) ;
		
		pol(ipair) = ph ;
	end % ipair = 1:length(inc_in)
		
return
%=======================================================================================  

%=======================================================================================  
function [VR] = V_rot3(V,alp,bet,gam)

%  Make rotation matrix
a = alp * pi/180. ;
b = bet * pi/180. ;
g = gam * pi/180. ;

R1 = [ 1 0 0 ; 0 cos(a) sin(a) ; 0 -sin(a) cos(a) ] ;
R2 = [ cos(b) 0 -sin(b) ; 0 1 0 ; sin(b) 0 cos(b) ] ;
R3 = [ cos(g) sin(g) 0 ; -sin(g) cos(g) 0 ; 0 0 1 ] ;

RR =  R3 * R2 * R1;

VR = V * RR ;
 
return
%=======================================================================================  

%=======================================================================================  
	function [X] = cart2(irev,inc,azm)
%=======================================================================================  
%c convert from spherical to cartesian co-ordinates
%c north x=100  west y=010 up z=001
%c irev=+1 positive vector x
%c irev=-1 negative vector x
	caz=cosd(azm)  ;
   saz=sind(azm)  ;
   cinc=cosd(inc) ;
   sinc=sind(inc) ;
   X=[caz*cinc -saz*cinc sinc] ;
%c normalise to direction cosines
   r=sqrt(X(1)*X(1)+X(2)*X(2)+X(3)*X(3)) ;
   
	X = X./r ;
	if(irev == -1), X = -X;, end
   return
%=======================================================================================  

%=======================================================================================  
	function [V,EIGVEC]=velo(X,rh,C)
%=======================================================================================  
% PHASE-VELOCITY SURFACES IN AN ANISOTROPIC MEDIUM
% revised April 1991
%     X(3) - DIRECTION OF INTEREST
%     RHO - DENSITY
%     V - PHASE VELOCITIES (1,2,3= P,S,SS)
%     EIGVEC(3,3) - eigenvectors stored by columns
%
% Translated to MATLAB by James Wookey         
		ijkl = [1,6,5; ...
		        6,2,4; ...
		        5,4,3] ;
%c form symmetric matrix tik=cijkl*xj*xl
		for i=1:3
      	for k=1:3
	         T(i,k)=0.0 ;
      		for j=1:3
      			for l=1:3
      				m=ijkl(i,j) ;
      				n=ijkl(k,l) ;
      				T(i,k)=T(i,k)+C(m,n).*X(j).*X(l) ;
					end
				end
			end
		end
% determine the eigenvalues of symmetric tij
      [EIVEC EIVAL] = eig(T) ;

% calculate velocities and sort
		V_RAW = (sqrt([EIVAL(1,1) EIVAL(2,2) EIVAL(3,3)]./rh))*10. ;
		[V IND] = sort(V_RAW,2,'descend') ;
		EIGVEC = EIVEC ; % for dimensioning
		for i=1:3
			EIGVEC(:,i) = EIVEC(:,IND(i)) ;
		end

      return
%=======================================================================================  