%  function Beyn
% Yoonkyung Eunnie Lee
% Last Updated 2015.06.23

% distinguish first run and repeated runs 
function [k, N, BeynA0, BeynA1, w_Beyn, w_Beyn_err]=...
  Beyn(N_h,k_h,BeynA0_h,BeynA1_h,n,funA,fundA, w_Newt,i_Newt)
    % inputs:  (k, N, BeynA0, BeynA1)_h: Beyn matrix, previous data
    %            int k_h: length(w)
    %            int N_h: quadrature size
    %          n, funA, fundA: problem definition funA=A(w)
    %          w_Newt, i_Newt: converged eigenvalues that need removal
    % outputs: k, N, BeynA0, BeynA1: Beyn matrix data for N=N; 
    %          cdouble w_Beyn[k]: list of eigenvalues found 
    %          cdouble w_Beyn_err[k]: list of corresponding error
    N = N_h*2;

    %--- define nested contour
    g0=0.0; rho=1.0;    %circular contour
    [g, dg] = circcont_nest(g0, rho, N); % construct contour N
    rmw=ones(N,1); % array
    if(w_Newt)
        for j=1:N
            rmw(j) = ones(1,length(w_Newt))(g(j) - w_Newt); %% (z-w0)(z-w1)..
        end
    end %end if(w_Newt)
    %--- decide size of random matrix 
    l = k_h+2;%
    M = rand(n,l);      % dimension of initial arbitrary mat. n x l 

    %--- compute Beyn matrices BeynA0, BeynA1 from M 
    [BeynA0,BeynA1]=getBeyn(BeynA0_h,BeynA1_h,N,M,n,funA,rmw,g,dg);

    l_correct=false;
    while(l_correct==false)
        %--- run svd and check size to see if dimension of M is
        %correct 
        
        
        
        %--- if l_correct is false
        %--- update using an added column for M 
        M_add = rand(n,1); %added column to increase l=l+1; 
        [UpdateA0,UpdateA1,UpdateA0_h,UpdtaeA1_h]=updateBeyn(funA,M_add,N,rmw,g,dg); 
        
        l_correct=true; 
    end
    
    M=[M M_add];   % update M  
    l = size(M,2); % update l ; 
    BeynA0 = BeynA0 + UpdateA0; 
    BeynA1 = BeynA1 + UpdateA1; 
    BeynA0_h = BeynA0_h + UpdateA0_h; 
    BeynA1_h = BeynA1_h + UpdateA1_h; 
    %--- 
    
    %--- SVD of BeyNA0 
    [V,Sigma,W] = svd(BeynA0); 
    s = diag(Sigma(1:l,1:l)); %--- first l elements, column vector s
    k= sum(s > 1e-15);        %--- rank computation 
                              % have to increase l if l<k 
    if(n<k)
        error('n<rank k , use higher order than BeynA1');
    elseif(l<k)
        disp('l<rank k, increase l');
        l=k+2;
        
    else                 %--- compute w_Beyn 
        V0 = V(1:n,1:k);          %% cut size of V0, W0, Sigma0 using k.
        W0 = W(1:l,1:k);
        s0 = s(1:k);              %%sigma is in decending order. 
        Sinv = diag(1./s0);       
        B = conj(V0')*BeynA1*W0*Sinv; %%linearized matrix
        [vlist, wlist]=eig(B);    
        w_Beyn = diag(wlist);     %%convert into vector;
    end
    
    
    %--- Compute w_Beyn, w_Beyn_half, and w_Beyn_error 
    [v_Beyn, w_Beyn, k]=BeynSub(V,Sigma,W,BeynA1, l); 
    [v_Beyn_h, w_Beyn_h, k_h]=BeynSub(BeynA0_h, BeynA1_h, l);

    w_Beyn_err=abs(w_Beyn-w_Beyn_h);                       %% error
    %---------------------------------------------------------------------   
   
function [vlist, wlist] = BeynSub(V0,s0,W0,BeynA1,l)
%--- Beyn subroutine for each given BeynA0, BeynA1     
%---------------------------------------------------------------------   

function [k,N,BeynA0,BeynA1,w_Beyn,w_Beyn_err]=Beyn_initialize(k_in,n,funA,fundA)
%% The first run of Beyn cycle, performs size estimation
    N = 4; %start with N=4 and increase N later. 
    %--- define nested contour
    g0=0.0; rho=1.0;    %circular contour
    [g, dg] = circcont_nest(g0, rho, N); % construct contour N

    %--- decide size of random matrix 
    funsize = @(z) trace(funA(z)\fundA(z));
    k_calc = cint(funsize,g,dg); 
    l = k_calc+2; 
    M = rand(n,l);      % dimension of initial arbitrary mat. n x l 

    %--- compute Beyn matrices BeynA0, BeynA1
    Nlist =1:N;
    for j=Nlist
        invAj = funA(g(j))\M;       
        BeynA0 = BeynA0 + invAj * dg(j); 
        BeynA1 = BeynA1 + invAj * g(j) * dg(j); 
        if(j==N/2)% store the integral from N/2 run 
            BeynA0_h = BeynA0/(N*i/2);  
            BeynA1_h = BeynA1/(N*i/2); 
        end
    end
    BeynA0 = BeynA0 /(N*i); 
    BeynA1 = BeynA1 /(N*i);       
    %--- Compute w_Beyn, w_Beyn_half, and w_Beyn_error 
    [v_Beyn, w_Beyn, k] = BeynSub(BeynA0, BeynA1, l); 
    [v_Beyn_h, w_Beyn_h, k_h] = BeynSub(BeynA0_h, BeynA1_h, l);
    w_Beyn_err = abs(w_Beyn-w_Beyn_h);                       %% error
    
    
    
    
function [BeynA0,BeynA1]=getBeyn(BeynA0_h,BeynA1_h,N,M,n,funA,rmw,g,dg)
%% get Beyn matrices for a given N and data from N/2 
    BeynA0 = BeynA0_h*(N/2)*i; % sum from N/2 run, if they are given 
    BeynA1 = BeynA1_h*(N/2)*i; % sum from N/2 run, if they are given
    Nlist = (N/2+1):N; 
    for j=Nlist
        invAj = funA(g(j))\M;
        BeynA0 = BeynA0 + invAj * rmw(j) * dg(j); 
        BeynA1 = BeynA1 + invAj * rmw(j) * g(j) * dg(j); 
    end
    BeynA0 = BeynA0 /(N*i); 
    BeynA1 = BeynA1 /(N*i);       

    
function [BeynA0, BeynA1, BeynA0_h, BeynA1_h]=getBeyn(N,M,n,funA,rmw,g,dg)
%% get Beyn matrices for a given N without data from N/2
    BeynA0 = zeros(n,n); 
    BeynA1 = zeros(n,n); 
    Nlist = 1:N; 
    for j=Nlist
        invAj = funA(g(j))\M;
        BeynA0 = BeynA0 + invAj * rmw(j) * dg(j); 
        BeynA1 = BeynA1 + invAj * rmw(j) * g(j) * dg(j); 
    end
    BeynA0 = BeynA0 /(N*i); 
    BeynA1 = BeynA1 /(N*i);
    
    
function [UpdateA0,UpdateA1,UpdateA0_h,UpdateA1_h]=updateBeyn(funA,M_add,N,rmw,g,dg); 

    for j=1:N; %should add the change for all quadrature points
        invAj = funA(g(j))\M_add;
        UpdateA0 = UpdateA0 + invAj * rmw(j) * dg(j); 
        UpdateA1 = UpdateA1 + invAj * rmw(j) * g(j) * dg(j); 
        if(j==N/2)
            UpdateA0_h = UpdateA0/(N*i/2); 
            UpdateA1_h = UpdateA1/(N*i/2); 
        end
    end
    UpdateA0 = UpdateA0 /(N*i);
    UpdateA1 = UpdateA1 /(N*i);
    %---

