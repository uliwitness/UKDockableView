// =============================================================================
//  UKDockableView.h
//  UKDockableWindow
//
//  Created by Uli Kusterer on Tue Feb 03 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//
//  PURPOSE:
//		UKDockableView attempts to provide advanced window management with a
//		simple user interface. Some people prefer applications with one large
//		window that contains everything they work with. Others prefer having
//		lots of small windows they can move around and resize.
//
//		Since in many cases there isn't really any "right way" to do it, this
//		class intends to allow splitting each NSindow into several smaller
//		"windows". These smaller parts can be grabbed and dragged out of the
//		NSWindow they are in. Drop them in another window and they end up there,
//		drop them on the desktop and you get a new NSWindow containing only this
//		one "window".
//
//		This allows "tearing apart" a window and re-assembling it as one sees
//		fit.
//
//	DIRECTIONS:
//		UKDockableView is a container view. For each of the "windows" your
//		application has, you create one UKDockableView that contains the views
//		that should be in that "window".
//		Then distribute those UKDockableViews over all the NSWindows you want
//		the user to initially have. Usually, these are several windows, but
//		there'd still be several UKDockableViews in most NSWindows.
// =============================================================================

// -----------------------------------------------------------------------------
//	Headers:
// -----------------------------------------------------------------------------

#import <AppKit/AppKit.h>


// -----------------------------------------------------------------------------
//	Preprocessor flags:
// -----------------------------------------------------------------------------

// Make dockable view look different in brushed metal windows:
#ifndef UKDOCKABLEVIEW_SUPPORT_METAL
#define UKDOCKABLEVIEW_SUPPORT_METAL		1
#endif

// -----------------------------------------------------------------------------
//	Constants:
// -----------------------------------------------------------------------------

// Size for the "title bar" area inside the UKDockableView, by which you can grab it to drag it:
#define UKDOCKABLEVIEW_TITLE_BAR_SIZE		15

// Radius for the rounded corners UKDockableViews use in brushed-metal windows:
#define UKDOCKABLEVIEW_CORNER_RADIUS		8


// -----------------------------------------------------------------------------
//	UKDockableView class:
// -----------------------------------------------------------------------------

@interface UKDockableView : NSView
{
	NSRectEdge		titleEdge;		// The edge of the box to display the title on. I suggest NSMinXEdge (default) or NSMaxYEdge, i.e. left or top. It feels kinda weird to grab a window by its bottom.
}

-(NSRectEdge)	titleEdge;
-(void)			setTitleEdge: (NSRectEdge)newTitleEdge;

@end
