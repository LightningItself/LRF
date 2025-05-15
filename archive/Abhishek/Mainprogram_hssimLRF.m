clc;
close all;

%himfold='E:\MATLAB2017trial\bin\OTIS_PNG_Gray\Fixed Backgrounds\Door'; %% Folder containing turbluence affected images
himfold='OTIS_PNG_Gray\Fixed Patterns\Pattern1';
hfile=dir(fullfile(himfold,'*.png'));
htotim=numel(hfile); % Total no of images in folder

h=fullfile(himfold,hfile(1).name);
w=imread(h); % reading a image for getting size of image

[ X , Y ] = size(w); % size of image stored in X and Y

frames = zeros (X,Y,htotim); % Creating frames for passing as input for Hssim_LRF 

for k = 1:htotim % Input formatting
    
    h=fullfile(himfold,hfile(k).name);
    w=imread(h);
    
    frames(:,:,k) = w; % Store images one by one in frames
    
end

hcombine = 16;  % No of images combined to produce a single output image

[out] = Hssim_LRF (frames , hcombine); %Calling the required function

writerObj = VideoWriter('hpattern1.avi'); % Craeting video object, Saved in bin of MATLAB folder
writerObj.FrameRate = 10; % setting frame rate
open(writerObj);

 for i=1:htotim-2*hcombine
 frame=im2frame(out(:,:,i), gray(256));
 writeVideo(writerObj, frame);
 end
 
 close(writerObj);