Dry exercise:

1. The class SnappingSheetController. 
   using that class the developer can control the snappingSheet widget scrolling features:
   - Get the current position of the snappingSheet scroller or set to new position (pixels or factor value).
   - Get the current widget's snapping status (boolean).
   - Get whether the widget is currently attached to a father snappingSheet widget.
   - Snap to new position or stop immediately the snapping.  
   
2. The parameter that controls this behavior is snappingPositions which determines the
   fixed positions to whom the scroller can be snapped. every position can be customized
   with its own Curve (the process of animating from one position to another) and duration.
    
3. Advantage of InkWell:
   this widget includes ripple effect when tapping.

   Advantage of GestureDetector:
   This widget detects various types of user interactions like double press, long press, dragging, etc. 