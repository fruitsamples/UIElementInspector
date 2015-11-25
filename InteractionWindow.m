/*
 File:		InteractionWindow.m

 Description: 	This is the implementation for the InteractionWindow class that handles allowing you to interact with
				(view or change values, or trigger actions) any UIElement that you lock into focus.
 
 This sample demonstrates the Accessibility API introduced in Mac OS X 10.2.

 Copyright: 	© Copyright 2002-2007 Apple Inc. All rights reserved.

 Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Inc.
 ("Apple") in consideration of your agreement to the following terms, and your
 use, installation, modification or redistribution of this Apple software
 constitutes acceptance of these terms.  If you do not agree with these terms,
 please do not use, install, modify or redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and subject
 to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
 copyrights in this original Apple software (the "Apple Software"), to use,
 reproduce, modify and redistribute the Apple Software, with or without
 modifications, in source and/or binary forms; provided that if you redistribute
 the Apple Software in its entirety and without modifications, you must retain
 this notice and the following text and disclaimers in all such redistributions of
 the Apple Software.  Neither the name, trademarks, service marks or logos of
 Apple Inc. may be used to endorse or promote products derived from the
 Apple Software without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or implied,
 are granted by Apple herein, including but not limited to any patent rights that
 may be infringed by your derivative works or by other works in which the Apple
 Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
 WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
 WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
 COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
                        GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
 OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
 (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

 */

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#import "AppShell.h"
#import "InteractionWindow.h"

// -------------------------------------------------------------------------------
//	FlippedScreenBounds:bounds
// -------------------------------------------------------------------------------
static NSRect FlippedScreenBounds(NSRect bounds)
{
    float screenHeight = NSMaxY([[[NSScreen screens] objectAtIndex:0] frame]);
    bounds.origin.y = screenHeight - NSMaxY(bounds);
    return bounds;
}

// -------------------------------------------------------------------------------
//	CreateHighlightWindowForUIElement:element
//
//	Create a borderless status window for te given uiElement.
// -------------------------------------------------------------------------------
static NSWindow* CreateHighlightWindowForUIElement(AXUIElementRef element)
{
    NSWindow *window = nil;
    id elementPosition = [AppShell valueOfExistingAttribute:kAXPositionAttribute ofUIElement:element];
    id elementSize = [AppShell valueOfExistingAttribute:kAXSizeAttribute ofUIElement:element];
    
    if (elementPosition && elementSize) {
		NSRect topLeftWindowRect;
		AXValueGetValue((AXValueRef)elementPosition, kAXValueCGPointType, &topLeftWindowRect.origin);
		AXValueGetValue((AXValueRef)elementSize, kAXValueCGSizeType, &topLeftWindowRect.size);
		window = [[NSWindow alloc] initWithContentRect:FlippedScreenBounds(topLeftWindowRect) styleMask:NSBorderlessWindowMask backing:NSBackingStoreNonretained defer:YES];
		[window setOpaque:NO];
		[window setAlphaValue:0.20];
		[window setBackgroundColor:[NSColor redColor]];
		[window setLevel:NSStatusWindowLevel];
		[window setReleasedWhenClosed:YES];
		[window orderFront:nil];
    }
    return window;
}

@implementation InteractionWindow

// -------------------------------------------------------------------------------
//	initWithContentRect:contentRect:styleMask:backing:defer
// -------------------------------------------------------------------------------
- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)styleMask backing:(NSBackingStoreType)backingType defer:(BOOL)flag
{
    if (self = [super initWithContentRect:contentRect styleMask:styleMask backing:backingType defer:flag]) {
        [self setBecomesKeyOnlyIfNeeded:YES];
    }
    return self;
}

// -------------------------------------------------------------------------------
//	createHighlightWindow:element
// -------------------------------------------------------------------------------
- (void)createHighlightWindow:(AXUIElementRef)element
{
    if (_highlightWindow != nil) {
        [_highlightWindow close];
        _highlightWindow = nil;
    }
    if (element != NULL) {
        _highlightWindow = CreateHighlightWindowForUIElement(element);
    }
}

// -------------------------------------------------------------------------------
//	interactionElement:
// -------------------------------------------------------------------------------
- (AXUIElementRef)interactionElement
{
    return _interactionUIElementRef;
}

// -------------------------------------------------------------------------------
//	setInteractionElement:uiElement
// -------------------------------------------------------------------------------
- (void)setInteractionElement:(AXUIElementRef)uiElement
{
    [(id)_interactionUIElementRef autorelease];
    _interactionUIElementRef = (AXUIElementRef)[(id)uiElement retain];
}

// -------------------------------------------------------------------------------
//	interactWithUIElement:uiElement
//
//	Open the interaction window which is locked onto the given uiElement.
// -------------------------------------------------------------------------------
- (void)interactWithUIElement:(AXUIElementRef)uiElement
{
    NSArray* theNames = NULL;

    [self setInteractionElement:uiElement];
    
    // populate attributes pop-up menus
    [_attributesPopup removeAllItems];
    
	// reset the contents of the elements popup
    [_elementsPopup removeAllItems];
    [_elementsPopup addItemWithTitle:@"goto"];

    if (AXUIElementCopyAttributeNames( [self interactionElement], (CFArrayRef *)&theNames ) == kAXErrorSuccess && theNames && [theNames count]) {
    
        int		nameIndex;
        int		numOfNames = [theNames count];
        for( nameIndex = 0; nameIndex < numOfNames; nameIndex++ ) {
            
            Boolean	theSettableFlag = false;
            NSString *	theName 	= [theNames objectAtIndex:nameIndex];
            CFTypeRef	theValue;
            
            // Grab settable field
            AXUIElementIsAttributeSettable( [self interactionElement], (CFStringRef)theName, &theSettableFlag );
            
            // Add name to pop-up menu     
			[[_attributesPopup menu] addItemWithTitle:[NSString stringWithFormat:@"%@%@", theName, (theSettableFlag?@" (W)":@"")] action:nil keyEquivalent:@""];;
            
            if (AXUIElementCopyAttributeValue([self interactionElement], (CFStringRef)theName, &theValue) == kAXErrorSuccess) {
                if (CFGetTypeID(theValue) == AXUIElementGetTypeID()) {
                    NSMenuItem *item;
                    [_elementsPopup addItemWithTitle:theName];
                    item = [_elementsPopup lastItem];
                    [item setRepresentedObject:(id)theValue];
                    [item setAction:@selector(interactWithUIElementAfterDelay:)];
                    [item setTarget:[_elementsPopup target]];
                } else if (CFGetTypeID(theValue) == CFArrayGetTypeID()) {
                    NSArray *values = (NSArray *)theValue;
                    if ([values count] > 0 && CFGetTypeID([values objectAtIndex:0]) == AXUIElementGetTypeID()) {
                        NSMenu *menu = [[NSMenu alloc] init];
                        NSEnumerator *e = [values objectEnumerator];
                        int i = 0;
                        id elt;
                        while (elt = [e nextObject]) {
                            NSString *role  = [AppShell valueOfExistingAttribute:kAXRoleAttribute ofUIElement:(AXUIElementRef)elt];
                            NSString *title  = [AppShell valueOfExistingAttribute:kAXTitleAttribute ofUIElement:(AXUIElementRef)elt];
                            NSString *itemTitle = [NSString stringWithFormat:title ? @"%@-\"%@\"" : @"%@", role, title];
                            NSMenuItem *item = [menu addItemWithTitle:itemTitle action:@selector(interactWithUIElementAfterDelay:) keyEquivalent:@""];
                            [item setTarget:[_elementsPopup target]];
                            [item setRepresentedObject:elt];
                            ++i;
                        }
                        [_elementsPopup addItemWithTitle:theName];
                        [[_elementsPopup lastItem] setSubmenu:menu];
                        [menu release];
                    }
                }
                CFRelease(theValue);
            }
        }
    
        [theNames release];
        [_actionsPopup setEnabled:true];
        [_elementsPopup setEnabled:true];
        [self attributeSelected:NULL];
    }
    else {
    	[_attributesPopup setEnabled:false];
    	[_elementsPopup setEnabled:false];
    	[_attributeValueTextField setEnabled:false];
    	[_setAttributeButton setEnabled:false];
    }

    // populate the popup with the actions for the element
    [_actionsPopup removeAllItems];
    if (AXUIElementCopyActionNames( [self interactionElement], (CFArrayRef *)&theNames ) == kAXErrorSuccess && theNames && [theNames count]) {
    
        int	nameIndex;
        int	numOfNames = [theNames count];
        for( nameIndex = 0; nameIndex < numOfNames; nameIndex++ )
            [_actionsPopup addItemWithTitle:[theNames objectAtIndex:nameIndex]];
    
        [theNames release];

    	[_actionsPopup setEnabled:true];
        [self actionSelected:NULL];
    }
    else {
    	[_actionsPopup setEnabled:false];
    	[_performActionButton setEnabled:false];
    }
    
    // set the title of the interaction window
    {
        NSString *uiElementRole  = NULL;
        NSString *uiElementTitle  = [AppShell valueOfExistingAttribute:kAXTitleAttribute ofUIElement:[self interactionElement]];
    
        if (AXUIElementCopyAttributeValue( [self interactionElement], kAXRoleAttribute, (CFTypeRef *)&uiElementRole ) == kAXErrorSuccess) {
            
            if (uiElementTitle && [uiElementTitle length])
                [self setTitle:[NSString stringWithFormat:@"Locked on <%@ “%@”>", uiElementRole, uiElementTitle]];
            else
                [self setTitle:[NSString stringWithFormat:@"Locked on <%@>", uiElementRole]];
        }
        else
            [self setTitle:@"Locked on UIElement"];
            
        [uiElementRole release];
    }
        
    // show the window
    [self orderFront:NULL];
    
    if ([AppShell highlightLockedUIElement]) {
        [self createHighlightWindow:uiElement];
    }
}

// -------------------------------------------------------------------------------
//	interactWithParent:
// -------------------------------------------------------------------------------
- (AXUIElementRef)interactWithParent
{
    AXUIElementRef parent = (AXUIElementRef)[AppShell valueOfExistingAttribute:kAXParentAttribute ofUIElement:[self interactionElement]];
    if (parent != NULL) {
        [self interactWithUIElement:parent];
    }
    return parent;
}

// -------------------------------------------------------------------------------
//	setHighlighting:on
// -------------------------------------------------------------------------------
- (void)setHighlighting:(BOOL)on
{
    [self createHighlightWindow:on ? [self interactionElement] : NULL];
}

// -------------------------------------------------------------------------------
//	orderOut:sender
// -------------------------------------------------------------------------------
- (void)orderOut:(id)sender
{
    [self createHighlightWindow:NULL];
    [super orderOut:sender];
}

// -------------------------------------------------------------------------------
//	stopInteracting:notification
// -------------------------------------------------------------------------------
- (void)stopInteracting:(NSNotification *)notification
{
    [self orderOut:NULL];    
}

// -------------------------------------------------------------------------------
//	attributeSelected:sender
// -------------------------------------------------------------------------------
- (void)attributeSelected:(id)sender
{
    NSString *	theName			= NULL;
    NSArray *	theNames		= NULL;
    Boolean		theSettableFlag = false;

    // Set text field with value
    if (AXUIElementCopyAttributeNames( [self interactionElement], (CFArrayRef *)&theNames ) == kAXErrorSuccess && theNames) {
        theName = [theNames objectAtIndex:[_attributesPopup indexOfSelectedItem]];
        [_attributeValueTextField setStringValue:[AppShell descriptionForUIElement:[self interactionElement] attribute:theName beingVerbose:false]];
    }
    // Update text fields and button based on settable flag
    AXUIElementIsAttributeSettable( [self interactionElement], (CFStringRef)theName, &theSettableFlag );
    [_attributeValueTextField setEnabled:theSettableFlag];
    [_attributeValueTextField setEditable:theSettableFlag];
    [_setAttributeButton setEnabled:theSettableFlag];

 	[theNames release];
}

// -------------------------------------------------------------------------------
//	setAttributeValue:sender
// -------------------------------------------------------------------------------
- (void)setAttributeValue:(id)sender
{
    CFTypeRef	theCurrentValue 	= NULL;
    NSString*	theAttributeName	= NULL;
    NSArray*	theNames			= NULL;

    // Get attribute name
    if (AXUIElementCopyAttributeNames( [self interactionElement], (CFArrayRef *)&theNames ) == kAXErrorSuccess && theNames)
        theAttributeName = [theNames objectAtIndex:[_attributesPopup indexOfSelectedItem]];
    
    // First, found out what type of value it is.
    if ( theAttributeName
        && AXUIElementCopyAttributeValue( [self interactionElement], (CFStringRef)theAttributeName, &theCurrentValue ) == kAXErrorSuccess
        && theCurrentValue) {
    
        CFTypeRef	valueRef = NULL;

        // Set the value using based on the type
        if (AXValueGetType(theCurrentValue) == kAXValueCGPointType) {		// CGPoint

            CGPoint point;
            sscanf( [[_attributeValueTextField stringValue] cString], "x=%g y=%g", &(point.x), &(point.y) );
            valueRef = AXValueCreate( kAXValueCGPointType, (const void *)&point );
            if (valueRef) {
                AXUIElementSetAttributeValue( [self interactionElement], (CFStringRef)theAttributeName, valueRef );
                CFRelease( valueRef );
            }
        }
     	else if (AXValueGetType(theCurrentValue) == kAXValueCGSizeType) {	// CGSize
            CGSize size;
            sscanf( [[_attributeValueTextField stringValue] cString], "w=%g h=%g", &(size.width), &(size.height) );
            valueRef = AXValueCreate( kAXValueCGSizeType, (const void *)&size );
            if (valueRef) {
                AXUIElementSetAttributeValue( [self interactionElement], (CFStringRef)theAttributeName, valueRef );
                CFRelease( valueRef );
            }
        }
     	else if (AXValueGetType(theCurrentValue) == kAXValueCGRectType) {	// CGRect
            CGRect rect;
            sscanf( [[_attributeValueTextField stringValue] cString], "x=%g y=%g w=%g h=%g", &(rect.origin.x), &(rect.origin.y), &(rect.size.width), &(rect.size.height) );
            valueRef = AXValueCreate( kAXValueCGRectType, (const void *)&rect );
            if (valueRef) {
                AXUIElementSetAttributeValue( [self interactionElement], (CFStringRef)theAttributeName, valueRef );
                CFRelease( valueRef );
            }
        }
     	else if (AXValueGetType(theCurrentValue) == kAXValueCFRangeType) {	// CFRange
            CFRange range;
            sscanf( [[_attributeValueTextField stringValue] cString], "pos=%ld len=%ld", &(range.location), &(range.length) );
            valueRef = AXValueCreate( kAXValueCFRangeType, (const void *)&range );
            if (valueRef) {
                AXUIElementSetAttributeValue( [self interactionElement], (CFStringRef)theAttributeName, valueRef );
                CFRelease( valueRef );
            }
        }
        else if ([(id)theCurrentValue isKindOfClass:[NSString class]]) {	// NSString
            AXUIElementSetAttributeValue( [self interactionElement], (CFStringRef)theAttributeName, [_attributeValueTextField stringValue] );
        }
        else if ([(id)theCurrentValue isKindOfClass:[NSValue class]]) {		// NSValue
            AXUIElementSetAttributeValue( [self interactionElement], (CFStringRef)theAttributeName, [NSNumber numberWithLong:[_attributeValueTextField intValue]] );
        }
    }
}

// -------------------------------------------------------------------------------
//	actionSelected:sender
//
//	Enables or disables the Action popup depending on the given uiElement.
// -------------------------------------------------------------------------------
- (void)actionSelected:(id)sender
{
    [_performActionButton setEnabled:true];
}

// -------------------------------------------------------------------------------
//	performAction:sender
//
//	User clicked the "Perform" button in the locked on window.
// -------------------------------------------------------------------------------
- (void)performAction:(id)sender
{
    pid_t				theTgtAppPID	= 0;
    ProcessSerialNumber	theTgtAppPSN	= {0,0};
   
    // pull the target app forward
	if (AXUIElementGetPid ( [self interactionElement], &theTgtAppPID ) == kAXErrorSuccess
        && GetProcessForPID( theTgtAppPID, &theTgtAppPSN) == noErr
        && SetFrontProcess( &theTgtAppPSN ) == noErr ) {
    
        // perform the action
    	NSArray* theNames = NULL;
        if (AXUIElementCopyActionNames( [self interactionElement], (CFArrayRef *)&theNames ) == kAXErrorSuccess && theNames) {
            AXUIElementPerformAction( [self interactionElement], (CFStringRef)[theNames objectAtIndex:[_actionsPopup indexOfSelectedItem]]);
            [theNames release];
        }
    }
}

@end
