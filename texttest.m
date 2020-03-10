function texttest()
    bgColour = 0.5;
    screen = max(Screen('Screens'));
    screenSize = [];
    ptb = openScreen(screen,bgColour,screenSize);
    text1 = 'Here is working text...';
    text2 = ['FAILS: Here it is 22' char(176) ' to the max'];
    text3 = ['WORKS: Here it is 22° to the max'];
    text4 = ['FAILS: Here it is 22� to the max'];
    text5 = ['WORKS: Here it is 22' char(0) ' to the max'];
    text6 = double(text5);
    text6(text6==0)=176;
    text7 = ['FAILS: Here it is 22' char(176) ' to the max'];
    text7 = double(text7);
    try
        vbl(1)=Screen('Flip', ptb.win);
        while vbl(end) < vbl(1) + 5
            DrawFormattedText2(text1,'win',ptb.win,'sx',100,'sy',100);
            DrawFormattedText2(double(text3),'win',ptb.win,'sx',100,'sy',200);
            %Screen('DrawText',ptb.win,text2,100,100);
            vbl(end+1) = Screen('Flip', ptb.win, vbl(end) + ptb.ifi/2);
        end
        Screen('Flip', ptb.win);
    catch ME
        getReport(ME)
        sca;
    end
end
%----------------------
function ptb = openScreen(screen, bgColour, ws)
    ptb.cleanup = onCleanup(@myCleanup);
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 2);
    if isempty(screen); screen = max(Screen('Screens')); end
    ptb.ScreenID = screen;
    PsychImaging('PrepareConfiguration');
    PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
    [ptb.win, ptb.winRect] = PsychImaging('OpenWindow', ptb.ScreenID, bgColour, ws, [], [], [], 1);
    [ptb.w, ptb.h] = RectSize(ptb.winRect);
    screenWidth = 405; % mm
    viewDistance = 573; % mm
    ptb.ppd = ptb.w/2/atand(screenWidth/2/viewDistance);
    ptb.ifi = Screen('GetFlipInterval', ptb.win);
    ptb.fps = 1 / ptb.ifi;
    Screen('BlendFunction', ptb.win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
end
%----------------------
function myCleanup()
    disp('Clearing up...')
    sca
end