classdef vpaTimeline_EEGArtefacts < vpaTimeline
    
    properties
        Data EEGVis_data
    end
    
%     properties (Dependent, SetAccess = private)
%         Valid
%     end    
    
%     properties (Dependent, SetAccess = protected)
%         AOIScoresValid
%     end
    
    methods
        
        function obj = vpaTimeline_EEGArtefacts(data)
            obj.DrawHeight = 100;
            obj.Data = data;
            obj.Duration = obj.Data.NumTrials;
            obj.GapFromEdge_H = 40;
            obj.CursorStringFormat = '%.0f';
        end           
     
        function Draw(obj)
                                    
%             % don't try to draw if invalid
%             if ~obj.Valid, return, end
            
            % clear texture
            obj.Clear
            obj.DrawBackground
            obj.DrawArtefactMarks
            obj.DrawControls
            
            % fire event
            notify(obj, 'HasDrawn')
                
        end
               
        function DrawArtefactMarks(obj)
            
            disp(obj.prRect)
            
            x1 = obj.prRect(1) + obj.BorderWidth;
            y1 = obj.prRect(2) + obj.BorderWidth;
            x2 = obj.prRect(3) - obj.BorderWidth;
            y2 = obj.prRect(4) - obj.BorderWidth;
            
            w = x2 - x1;
            h = y2 - y1;
            
            % width of one trial segment
            tw = w / obj.Data.NumTrials;
            
            % for each trial, set the height to be proportionate to the
            % number of artefacts
            any_art = any(obj.Data.Art, 3);
            trial_art = sum(any_art, 1) ./ obj.Data.NumChannels;
            trial_art_px = round(trial_art * h);                
            
            % trial coords
            tx1 = round(x1:tw:x2 - tw);
            tx2 = round(tx1 + tw);
            ty1 = y2 - trial_art_px;
            ty2 = repmat(y2, 1, obj.Data.NumTrials);
            coords_prop = [tx1; ty1; tx2; ty2];
            
            % line coords
            lx1 = tx1;
            lx2 = tx2;
            ly1 = repmat(y1, 1, obj.Data.NumTrials);
            ly2 = ty2;
            coords_line = [lx1; ly1; lx2; ly2];
            
%             % break the timeline up in to trials. Calculate width of each
%             % trial in pixels
%             w = (obj.prRect(3) - obj.prRect(1)) - (obj.BorderWidth * 2);
%             h = obj.DrawHeight - (obj.BorderWidth * 4);
%             tw = w / obj.Data.NumTrials;
%             
%             % for each trial, set the height to be proportionate to the
%             % number of artefacts
%             any_art = any(obj.Data.Art, 3);
%             trial_art = sum(any_art, 1) ./ obj.Data.NumChannels;
%             trial_art_px = round(trial_art * h);
%             
%             % make vectors for each element of a rect, for each trial
%             tx1 = round(0:tw:w - tw);
%             ty1 = repmat(h, 1, obj.Data.NumTrials) - trial_art_px;
%             tx2 = round(tx1 + tw);
%             ty2 = repmat(h, 1, obj.Data.NumTrials);
%             
%             % position rect on top of timeline area
%             tx1 = tx1 + obj.prRect(1);
%             tx2 = tx2 + obj.prRect(1);
%             ty1 = ty1 + obj.prRect(2) + (obj.BorderWidth * 2);
%             ty2 = ty2 + obj.prRect(2);
%             
%             % make a matric of rects (each element being a row) for each
%             % trial
%             coords_prop = [tx1; ty1; tx2; ty2];
%             
%             % make coords for vertical dividing lines between trials
%             lx1 = tx1;
%             lx2 = tx2;
%             ly1 = repmat(obj.prRect(2) + (obj.BorderWidth * 2), 1, obj.Data.NumTrials);
%             ly2 = repmat(h, 1, obj.Data.NumTrials)+ obj.prRect(2)
%             coords_line = [lx1; ly1; lx2; ly2];
            
            % draw
            Screen('FillRect', obj.Ptr, [200, 50, 50], coords_prop, 2);
            Screen('FrameRect', obj.Ptr, [obj.ForeColour(1:3), 128], coords_line, 1);
            
        end
        
        
%         function val = get.Valid(obj)
%             val = ~isempty(obj.Data) && isa(obj.Data, 'EEGVis_data');
%         end
        
    end
    
end