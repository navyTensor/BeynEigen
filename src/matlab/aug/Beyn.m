function [BD, S_bc] = Beyn(fA, BD, S_f, S_bc)
%---------------------------------------------------------------------
%- Beyn contour integration, each Beyn run doubles N and modifies l
%---------------------------------------------------------------------
% Nj, lj : current step, contour points and column size of random matrix M
% Nj1,lj1: previous step (stored in BD)

% BD is updated to current step values at the beginning of the run. 
%---------------------------------------------------------------------    
    usermw = 1;                 % whether to remove Newton converged E
    S_b  = EigenPairs(1);       % declare eigenpairs used to store N/2 run
    %---------------------------------------------------------------------
    %- previous run values Nj1, lj1, krmwj1 
    lj1 = BD.l; 
    Nj1 = BD.N;         
    krmwj1 = BD.krmw;
    kj1 = S_bc.k;
    %---------------------------------------------------------------------
    %- current run values Nj, lj, krmwj 
    Nj  = 2 * Nj1;              % # contour pts, doubled 
    krmwj  = S_f.k;             % # eigvals to remove using rmw, from S_k
    dkrmw  = krmwj-krmwj1;
    if(dkrmw == 0 )             % if krj didn't change
        lj = lj1; 
    else                        % if krj changed         
        lj = lj1 - dkrmw;
    end
    disp(sprintf('   Beyn,   usermw=%d, removable krmw=%d',usermw,krmwj));    
    %---------------------------------------------------------------------
    %- update BD 
    BD.N = Nj;  
    BD.l = lj;         
    BD.krmw = krmwj;
    BD.Ermw = S_f.E;
    %---------------------------------------------------------------------    
    %- Compute data for half run, store in S_b
    %- Run with lj and figure out if lj is sufficient.      
    if( kj1 > 0 && lj == lj1 && BD.NA == Nj1)
        disp('   Beyn,   re-used BeynA for S_b'); 
        S_b = copy(S_b, S_bc); 
    else 
        disp('   Beyn,   new BeynA for S_b by running halfBeynA'); 
        BD  = halfBeynA(BD, fA.funA, usermw);  % create new halfBeynA
        S_b = BeynSVD(BD, S_b);
%     fixl = 1;                  % choose whether to fix l or run while loop      
%     while( fixl == 0 )
%         ljt = lj;               % test value for lj inside while loop                                
%         if( kj1 > 0 && ljt == lj1 && BD.NA == Nj1)
%             disp('   Beyn,   re-used BeynA for S_b'); 
%             S_b = copy(S_b, S_bc); 
%         else 
%             disp('   Beyn,   new BeynA for S_b by running halfBeynA'); 
%             BD  = halfBeynA(BD, fA.funA, usermw);  % create new halfBeynA
%             S_b = BeynSVD(BD, S_b);
%         end 
%         if(ljt > S_b.k); 
%             fixl = 1; 
%             break; 
%         end;
%         if(ljt +10 > BD.n); 
%             break; 
%         end; 
%         lj = ljt + 10; 
%         BD.l = lj;           
%     end    
    end        
    %-----------------------------------------------------------------
    %- Compute data for full run, store in S_bc
    BD  = halfBeynA2(BD, fA.funA, usermw);      % update to fullBeynA
    S_bc= BeynSVD(BD, S_bc);   % get S_bc from current run
    %-----------------------------------------------------------------
          
    %- Check error
    if(S_bc.k>0 && S_b.k>0)   
        S_bc = error(S_bc,S_b);     % update error
        S_bc = sample(S_bc,find(S_bc.err<BD.emax)); % discard unconverged            
    disp(sprintf('   Beyn,   N=%5d to %5d, l=%5d to %5d, k_bc=%5d',Nj1,Nj, lj1,lj,S_bc.k));    
    end
end

function BD= halfBeynA(BD,funA,usermw)
    NA = BD.N/2; 
    g  = BD.g; 
    dg = BD.dg; 
    M  = BD.M; 
    disp(sprintf('   Beyn,   halfBeyNA, N=%5d, NA=%5d',BD.N, NA));
    BeynA0sum = zeros(size(M)); 
    BeynA1sum = zeros(size(M)); 
    
    rmwj = 1; 
    for jj=1:NA;                 
        if(usermw && BD.krmw>0)
            rmwj = BD.rmw(BD.g(jj));
        end
        invAj = funA(g(jj))\M;
        BeynA0sum = BeynA0sum  + invAj * rmwj * dg(jj);
        BeynA1sum = BeynA1sum  + invAj * rmwj * dg(jj) * g(jj) ;
    end 
    BD.NA = NA; 
    BD.BeynA0sum = BeynA0sum;
    BD.BeynA1sum = BeynA1sum;
end

function BD= halfBeynA2(BD,funA,usermw)
    %- update summation of BeynA0, BeynA1 for whole of N, 
    %- using halfBeynA or data from previous run             
    if(BD.NA ~= BD.N/2)
        error('run halfBeynA before proceeding');
    end
    
    NA = BD.N; 
    g  = BD.g; 
    dg = BD.dg; 
    M  = BD.M; 
    disp(sprintf('   Beyn,   halfBeyNA2, N=%5d, NA=%5d',BD.N, NA));
    BeynA0sum = BD.BeynA0sum;
    BeynA1sum = BD.BeynA1sum;
    
    rmwj = 1; 
    for jj=NA/2+1:NA;                 
        if(usermw && BD.krmw>0)
            rmwj = BD.rmw(BD.g(jj));
        end
        invAj = funA(g(jj))\M;
        BeynA0sum = BeynA0sum  + invAj * rmwj * dg(jj);
        BeynA1sum = BeynA1sum  + invAj * rmwj * dg(jj) * g(jj) ;
    end 
    BD.NA = NA; 
    BD.BeynA0sum = BeynA0sum;
    BD.BeynA1sum = BeynA1sum;    
end%%function 
        
function BD= totalBeynA(BD,funA,usermw)
    NA = BD.N; 
    g  = BD.g; 
    dg = BD.dg; 
    M  = BD.M; 
    disp(sprintf('   Beyn,   totalBeyNA, N=%5d, NA=%5d',BD.N, NA));
    BeynA0sum = zeros(size(M)); 
    BeynA1sum = zeros(size(M)); 
    
    rmwj = 1; 
    for jj=1:NA;                 
        if(usermw && BD.krmw>0)
            rmwj = BD.rmw(BD.g(jj));
        end
        invAj = funA(g(jj))\M;
        BeynA0sum = BeynA0sum  + invAj * rmwj * dg(jj);
        BeynA1sum = BeynA1sum  + invAj * rmwj * dg(jj) * g(jj) ;
    end 
    BD.NA = NA; 
    BD.BeynA0sum = BeynA0sum;
    BD.BeynA1sum = BeynA1sum;
end

function S_b = BeynSVD(BD, S_b)    
    %- load data from BD 
    l    = BD.l; 
    n    = BD.n;     
    NA   = BD.NA; 
    tolw = BD.tolw;
    
    BeynA0 = BD.BeynA0sum/(NA * 1i);
    BeynA1 = BD.BeynA1sum/(NA * 1i);    
    
    [V,Sigma,W]=svd(BeynA0);            % SVD 
    k=sum(diag(Sigma(1:l,1:l))>tolw); % check rank k 
        
    V0 = V(1:n, 1:k);                % cut size down to  V0(n,k)
    S0 = Sigma(1:k,1:k);                %                   S0(k,k) 
    W0 = W(1:l, 1:k);                %                   W0(l,k)

    Sinv = diag(1./diag(S0));           % Sinv = inv(S0) 
    B = (V0') * BeynA1 * W0 * Sinv; % linearized matrix 
    [vtemp, wtemp]=eig(B);
    E = diag(wtemp);                    % convert to single column   
    disp(sprintf('   Beyn,   BeynSVD, l=%5d, NA=%5d, k=%5d',l,NA,k));
    disp(sprintf('   Beyn,   BeynSVD, length(E)=%5d,k=%5d',length(E),k));    
    V = V0*vtemp;                       % size of V should be (n,k); 
    % cfig=figure();plot(BD);  hold on; 
    % scatter(real(E),imag(E),40,'m*'); 
    % title('BeynSVD check');
    if(k==0)
        S_b=zero(S_b); 
    else
        S_b = update(S_b, k, E, V); 
    end
end