function [ssimap]=hssimap2(frameReference,frameUnderTest)

C1 = 6.5025; %% This values taken from a SSIM code in matlab files can be found on internet
C2 = 58.5225;

n=5;
hsi=0.5;
ind=-floor(n/2):floor(n/2);
[X,Y]=meshgrid(ind,ind);
h=exp(-(X.^2+Y.^2)/(2*hsi*hsi));
hg1=h/sum(h(:));
hg2=h/sum(h(:));

% a=[ 3 14 3; 14 60 14 ; 3 14 3]; 
% a=a/128; % This is how gaussian matrix has been defined in verilog files 
         % This closely resembles gaussian 3x3 matrix for sigma = 0.5

         %The code from this point onwards has been replicated to the maximum
         %possibilty  in the verilog files

frameReference=double(frameReference);
frameUnderTest=double(frameUnderTest);

frameReference_2=frameReference.^2;
frameUnderTest_2=frameUnderTest.^2;
frameReference_frameUnderTest=frameReference.*frameUnderTest;

%///////////////////////////////// PRELIMINARY COMPUTING ////////////////////////////////

mu1=round(conv2(frameReference,hg1,'same'));
mu2=round(conv2(frameUnderTest,hg2,'same'));

mu1_2=mu1.^2;
mu2_2=mu2.^2;
mu1_mu2=mu1.*mu2;

sigma1_2=round(conv2(frameReference_2,hg1,'same'));
sigma1_2=sigma1_2-mu1_2;
sigma2_2=round(conv2(frameUnderTest_2,hg2,'same'));
sigma2_2=sigma2_2-mu2_2;
sigma12=round(conv2(frameReference_frameUnderTest,hg1,'same'));
sigma12=sigma12-mu1_mu2;

%///////////////////////////////// FORMULA ////////////////////////////////

t3 = ((2*mu1_mu2 + C1).*(2*sigma12 + C2)); %% Refer SSIM paper
t1 =((mu1_2 + mu2_2 + C1).*(sigma1_2 + sigma2_2 + C2));
ssimap =  t3./t1;  
