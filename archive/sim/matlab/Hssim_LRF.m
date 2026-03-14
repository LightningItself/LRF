function [out ] = Hssim_LRF (frames , hcombine)

[X , Y , T] = size(frames); %% T frames of size X x Y

outframes = zeros([X , Y , T-2*hcombine]); 

%a Creation of 2D Gaussian and Sobel filters ------------------------------------------

n = 5; %% dimension of 2d matrix
hsi = 0.5; %% sigma
ind = -floor(n/2):floor(n/2);
[X,Y] = meshgrid(ind,ind);
hgauss = exp(-(X.^2+Y.^2)/(2*hsi*hsi));
size(hgauss)
hgaussianfilter = hgauss/sum(hgauss(:)); % gaussian matrix
%hgaussianfilter = [1 2 1; 2 4 2; 1 2 1]/16;

hsobely = [ -1 0 1; -2 0 2; -1 0 1]; % sobel filters for horizontal and vertical edges
hsobelx = [ -1 -2 -1; 0 0 0; 1 2 1];

%a -------------------------------------------------------------------------


 %% hcombine=16; % no of images you want to combine to create one image

for j = hcombine : T-hcombine      % Clearly no of output frames = T - 2*hcombine
                                   % Start from hcombine since we need last hcombine frames for avg calculation
                                   % End at T-hcombine since we use n upto hcombine+j, which shud be <= T
    
    hfuse = frames(:,:,j); % first image in the set of 'hcombine' no of images is chosen as 
                           % the starting fused image                                       
    
    for n = j+1 : hcombine+j % create an output image from 'hcombine' number of images starting from jth image 
        
        
%         avg_now=double(hfuse-hfuse); % creating a ZERO 2d matrix of size hfuse
%         for r = n-hcombine : 1 : n-1 % Calculating avg of last hcombine images (Last corresponding to nth index)
%                                       % Present image corresponding to nth index also included in avg calculation
%                                       % This avg calculation occurs everytime n changes
%                                   
%              w = frames(:,:,r);
%              avg_now = double(w) + avg_now; % first sum
%          
%          end

        avg_now = double(hfuse-hfuse);
        for r = j : 1 : n-1
            w = frames(:,:,r);
            avg_now = double(w) + avg_now;
        end
        
        
        avg_now = (avg_now)/(n-j);  % sum then divide
    
        newim = frames(:,:,n);
    
        %% EDGE MAP CALCULATION-------------------------------------------
    
        avg_now_x = conv2(avg_now,hsobelx,'same'); % Calculation of horizontal and vertical edge maps individually
        avg_now_y = conv2(avg_now,hsobely,'same');
        avg_now_net=sqrt(avg_now_x.*avg_now_x + avg_now_y.*avg_now_y); % Calculation of final edge map for avg image
    
    
        fuse_now_x=conv2(hfuse,hsobelx,'same');        
        fuse_now_y=conv2(hfuse,hsobely,'same');
        fuse_now_net=sqrt(fuse_now_x.*fuse_now_x + fuse_now_y.*fuse_now_y ); % Calculation of final edge map for PRESENT fused image
    
        newim_x=conv2(newim,hsobelx,'same');
        newim_y=conv2(newim,hsobely,'same');
        newim_net=sqrt(newim_x.*newim_x + newim_y.*newim_y); % Calculation of final edge map for NEW INCOMING image
    
        %%-----------------------------------------------------------------
    
        %% HSSIM calculation of present fused image and new incoming image wrt to present Average image
    
        [hssimap_fuse] = hssimap2(fuse_now_net,avg_now_net);
        [hssimap_newim] = hssimap2(newim_net,avg_now_net);

        % hssimap_fuse_iqm = conv2(hssimap_fuse,hgaussianfilter,'same');
        % hssimap_newim_iqm = conv2(hssimap_newim,hgaussianfilter,'same');
        % 
        %%-----------------------------------------------------------------
    
        %% DELTA calculation-----------------------------------------------

        hdeltemp = (hssimap_newim - hssimap_fuse) > 0 ; 
  
        %hdeltemp =(hdeltemp+abs(hdeltemp))/2;  
  
        hdelta = double(hdeltemp);
        %hdelta = hdelta/max(hdelta, [], "all");
  
        hdelta = conv2(hdelta,hgaussianfilter,'same'); %% Spreading out values by gaussian filtering for smoother varaition in delta
    
        %%---------------------------------------------------------------
  
        
        hfuse = (ones(size(newim))-hdelta).*double(hfuse)+hdelta.*double(newim);
        hfuse = uint8(hfuse);
        %hfuse = uint8((hfuse>255)*255 + (hfuse<=255)*hfuse);

    end
 
outframes(:,:,j+1-hcombine) = hfuse; % ' j+1-hcombine ' -TH output image

end

out = outframes;

