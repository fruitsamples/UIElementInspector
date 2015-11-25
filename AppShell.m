/*
 File:		AppShell.m

 Description: 	This is the implementation for our "controller" AppShell class that handles the bulk of the real
				accessibility work of finding out what is under the cursor.
 
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
#import <AppKit/NSAccessibility.h>
#import <Carbon/Carbon.h>
#import "AppShell.h"

const UInt32 kLockUIElementHotKeyIdentifier = 'lUIk';
const UInt32 kLockUIElementHotKey			= 98; // F7 will be the key to hit, in combo with Cmd
const int kLockUIElementModifierKey			= cmdKey;

AppShell*		gAppShell = NULL;

EventHotKeyRef	gMyHotKeyRef;
EventHotKeyID	gMyHotKeyID;
EventHandlerUPP	gAppHotKeyFunction;

// Forwards
pascal OSStatus LockUIElementHotKeyHandler(EventHandlerCallRef nextHandler,EventRef theEvent, void *userData);

@implementation AppShell

// -------------------------------------------------------------------------------
//	updateCurrentUIElement:
// -------------------------------------------------------------------------------
+ (void)updateCurrentUIElement
{
    [gAppShell updateCurrentUIElement];
}

// -------------------------------------------------------------------------------
//	descriptionOfValue:theValue:beVerbose
//
//	Called from "descriptionForUIElement", return a descripting string (role and title)
//	of the given value (AXUIElementRef).
// -------------------------------------------------------------------------------
+ (NSString *)descriptionOfValue:(CFTypeRef)theValue beingVerbose:(BOOL)beVerbose
{
    NSString *	theValueDescString	= NULL;

    if (theValue) {
    
        if (AXValueGetType(theValue) != kAXValueIllegalType) {
            theValueDescString = [AppShell stringDescriptionOfAXValue:theValue beingVerbose:beVerbose];
        }
        else if (CFGetTypeID(theValue) == CFArrayGetTypeID()) {
            theValueDescString = [NSString stringWithFormat:@"<array of size %d>", [(NSArray *)theValue count]];
        }
        else if (CFGetTypeID(theValue) == AXUIElementGetTypeID()) {
            
            NSString *	uiElementRole  	= NULL;
        
            if (AXUIElementCopyAttributeValue( (AXUIElementRef)theValue, kAXRoleAttribute, (CFTypeRef *)&uiElementRole ) == kAXErrorSuccess) {
                NSString *	uiElementTitle  = NULL;
                
                uiElementTitle = [AppShell valueOfExistingAttribute:kAXTitleAttribute ofUIElement:(AXUIElementRef)theValue];
                
                #if 0
                // hack to work around cocoa app objects not having titles yet
                if (uiElementTitle == nil && [uiElementRole isEqualToString:(NSString *)kAXApplicationRole]) {
                    pid_t				theAppPID = 0;
                    ProcessSerialNumber	theAppPSN = {0,0};
                    NSString *			theAppName = NULL;
                    
                    if (AXUIElementGetPid( (AXUIElementRef)theValue, &theAppPID ) == kAXErrorSuccess
                        && GetProcessForPID( theAppPID, &theAppPSN ) == noErr
                        && CopyProcessName( &theAppPSN, (CFStringRef *)&theAppName ) == noErr ) {
                        uiElementTitle = theAppName;
                    }
                }
                #endif

                if (uiElementTitle != nil) {
                    theValueDescString = [NSString stringWithFormat:@"<%@: “%@”>", uiElementRole, uiElementTitle];
                }
                else {
                    theValueDescString = [NSString stringWithFormat:@"<%@>", uiElementRole];
                }
                [uiElementRole release];
            }
            else {
                theValueDescString = [(id)theValue description];
            }
        }
        else {
            theValueDescString = [(id)theValue description];
        }
    }
    
    return theValueDescString;
}

// -------------------------------------------------------------------------------
//	descriptionForUIElement:uiElement:beingVerbose
//
//	Return a descripting string (role and title) of the given uiElement (AXUIElementRef).
// -------------------------------------------------------------------------------
+ (NSString *)descriptionForUIElement:(AXUIElementRef)uiElement attribute:(NSString *)name beingVerbose:(BOOL)beVerbose
{
    NSString *	theValueDescString	= NULL;
    CFTypeRef	theValue;
    CFIndex	count;
    if (([name isEqualToString:NSAccessibilityChildrenAttribute]
            ||
         [name isEqualToString:NSAccessibilityRowsAttribute]
        )
            &&
        AXUIElementGetAttributeValueCount(uiElement, (CFStringRef)name, &count) == kAXErrorSuccess) {
        // No need to get the value of large arrays - we just display their size.
		// We don't want to do this with every attribute because AXUIElementGetAttributeValueCount on non-array valued
		// attributes will cause debug spewage.
        theValueDescString = [NSString stringWithFormat:@"<array of size %d>", count];
    } else if (AXUIElementCopyAttributeValue ( uiElement, (CFStringRef)name, &theValue ) == kAXErrorSuccess && theValue) {
        theValueDescString = [self descriptionOfValue:theValue beingVerbose:beVerbose];
    }
    return theValueDescString;
}

// -------------------------------------------------------------------------------
//	valueOfExistingAttribute:attribute:element
//
//	Given a uiElement and its attribute, return the value of an accessibility object's attribute.
// -------------------------------------------------------------------------------
+ (id)valueOfExistingAttribute:(CFStringRef)attribute ofUIElement:(AXUIElementRef)element
{
    id result = nil;
    NSArray *attrNames;
    
    if (AXUIElementCopyAttributeNames(element, (CFArrayRef *)&attrNames) == kAXErrorSuccess) {
        if ( [attrNames indexOfObject:(NSString *)attribute] != NSNotFound
                &&
        	AXUIElementCopyAttributeValue(element, attribute, (CFTypeRef *)&result) == kAXErrorSuccess
        ) {
            [result autorelease];
        }
        [attrNames release];
    }
    return result;
}

// -------------------------------------------------------------------------------
//	stringDescriptionOfAXValue:valueRef:beVerbose
//
//	Returns a descriptive string according to the values' structure type.
// -------------------------------------------------------------------------------
+ (NSString *)stringDescriptionOfAXValue:(CFTypeRef)valueRef beingVerbose:(BOOL)beVerbose
{
    NSString *result = @"AXValue???";
    
    switch (AXValueGetType(valueRef)) {
        case kAXValueCGPointType: {
            CGPoint point;
            if (AXValueGetValue(valueRef, kAXValueCGPointType, &point)) {
                if (beVerbose)
                    result = [NSString stringWithFormat:@"<AXPointValue x=%g y=%g>", point.x, point.y];
                else
                    result = [NSString stringWithFormat:@"x=%g y=%g", point.x, point.y];
            }
            break;
        }
        case kAXValueCGSizeType: {
            CGSize size;
            if (AXValueGetValue(valueRef, kAXValueCGSizeType, &size)) {
                if (beVerbose)
                    result = [NSString stringWithFormat:@"<AXSizeValue w=%g h=%g>", size.width, size.height];
                else
                    result = [NSString stringWithFormat:@"w=%g h=%g", size.width, size.height];
            }
            break;
        }
        case kAXValueCGRectType: {
            CGRect rect;
            if (AXValueGetValue(valueRef, kAXValueCGRectType, &rect)) {
                if (beVerbose)
                    result = [NSString stringWithFormat:@"<AXRectValue  x=%g y=%g w=%g h=%g>", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
                else
                    result = [NSString stringWithFormat:@"x=%g y=%g w=%g h=%g", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
            }
            break;
        }
        case kAXValueCFRangeType: {
            CFRange range;
            if (AXValueGetValue(valueRef, kAXValueCFRangeType, &range)) {
                if (beVerbose)
                    result = [NSString stringWithFormat:@"<AXRangeValue pos=%ld len=%ld>", range.location, range.length];
                else
                    result = [NSString stringWithFormat:@"pos=%ld len=%ld", range.location, range.length];
            }
            break;
        }
        default:
            break;
    }
    return result;
}

// -------------------------------------------------------------------------------
//	awakeFromNib:
//
//	At launch time this app checks if accessibility is turned on.  If not we ask
//	the user to turn it on using System Preferences.  We also register our hot key
//	to turn on/off accessibility lock on a particular uiElement.
// -------------------------------------------------------------------------------
- (void)awakeFromNib
{
    EventTypeSpec eventType;
    gAppShell = self;

    // We first have to check if the Accessibility APIs are turned on.  If not, we have to tell the user to do it (they'll need to authenticate to do it).  If you are an accessibility app (i.e., if you are getting info about UI elements in other apps), the APIs won't work unless the APIs are turned on.	
    if (!AXAPIEnabled())
    {
        int ret = NSRunAlertPanel (@"UI Element Inspector requires that the Accessibility API be enabled.  Would you like me to launch System Preferences so that you can turn on \"Enable access for assistive devices\".", @"", @"OK", @"Quit UI Element Inspector", @"Cancel");
        
        switch (ret)
        {
            case NSAlertDefaultReturn:
                [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/UniversalAccessPref.prefPane"];
                break;
                
            case NSAlertAlternateReturn:
            
                [NSApp terminate:self];
                return;
                break;
            case NSAlertOtherReturn: // just continue
            default:
                break;
        
        }
    }

    [_inspectorWindow setHidesOnDeactivate:NO];
    [_interactionWindow setHidesOnDeactivate:NO];
    
    _systemWideElement = AXUIElementCreateSystemWide();
    
    gAppHotKeyFunction = NewEventHandlerUPP(LockUIElementHotKeyHandler);
    eventType.eventClass = kEventClassKeyboard;
//    eventType.eventKind = kEventHotKeyPressed;
    eventType.eventKind = kEventHotKeyReleased;
    InstallApplicationEventHandler(gAppHotKeyFunction,1,&eventType,NULL,NULL);
    
    gMyHotKeyID.signature = kLockUIElementHotKeyIdentifier;
    gMyHotKeyID.id = 1;

    RegisterEventHotKey(kLockUIElementHotKey, kLockUIElementModifierKey, gMyHotKeyID, GetApplicationEventTarget(), 0, &gMyHotKeyRef);

    [self performTimerBasedUpdate];
}

// -------------------------------------------------------------------------------
//	performTimerBasedUpdate:
//
//	Timer to continually update the current uiElement being examined.
// -------------------------------------------------------------------------------
- (void)performTimerBasedUpdate
{
    [gAppShell updateCurrentUIElement];
    
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(performTimerBasedUpdate) userInfo:nil repeats:NO];
}

// -------------------------------------------------------------------------------
//	isCurrentUIElementLocked:
// -------------------------------------------------------------------------------
- (BOOL)isCurrentUIElementLocked
{
    return [_interactionWindow isVisible];
}

// -------------------------------------------------------------------------------
//	setCurrentUIElement:uiElement
// -------------------------------------------------------------------------------
- (void)setCurrentUIElement:(AXUIElementRef)uiElement
{
    if (uiElement)
        CFRetain( uiElement );
    
    if (_currentUIElementRef)
        CFRelease( _currentUIElementRef );
        
	_currentUIElementRef = uiElement;
}

// -------------------------------------------------------------------------------
//	currentUIElement:
// -------------------------------------------------------------------------------
- (AXUIElementRef)currentUIElement
{
    return _currentUIElementRef;
}

// -------------------------------------------------------------------------------
//	updateCurrentUIElement:
// -------------------------------------------------------------------------------
- (void)updateCurrentUIElement
{
    if (![self isCurrentUIElementLocked]) {
    
        Point		pointAsCarbonPoint;

        // The current mouse position with origin at top left.
        GetMouse( &pointAsCarbonPoint );
        
        // Only ask for the UIElement under the mouse if has moved since the last check.
        if (pointAsCarbonPoint.h != _lastMousePoint.h || pointAsCarbonPoint.v != _lastMousePoint.v) {
        
            CGPoint				pointAsCGPoint;
            AXUIElementRef 		newElement		= NULL;

            pointAsCGPoint.x = pointAsCarbonPoint.h;
            pointAsCGPoint.y = pointAsCarbonPoint.v;
    
            // Ask Accessibility API for UI Element under the mouse
            // And update the display if a different UIElement
            if (AXUIElementCopyElementAtPosition( _systemWideElement, pointAsCGPoint.x, pointAsCGPoint.y, &newElement ) == kAXErrorSuccess
                && newElement
                && ([self currentUIElement] == NULL || ! CFEqual( [self currentUIElement], newElement ))) {
                    
                [self setCurrentUIElement:newElement];
                [_inspectorWindow displayInfoForUIElement:newElement];
            }
            
            if (_currentlyInteracting) {
                _currentlyInteracting = ! _currentlyInteracting;
                [_inspectorWindow indicateUIElementIsLocked:_currentlyInteracting];
            }
            
            _lastMousePoint = pointAsCarbonPoint;
        }
    }
}

// -------------------------------------------------------------------------------
//	interactWithCurrentUIElement:sender
//
//	This gets called when our hot key is pressed which means the user wants to lock
//	onto a particular uiElement.  This also means open the interaction window
//	titled "Lock on <???>".
// -------------------------------------------------------------------------------
- (void)interactWithCurrentUIElement:(id)sender
{
    _currentlyInteracting = true;
    [_inspectorWindow indicateUIElementIsLocked:true];
    [_interactionWindow interactWithUIElement:[self currentUIElement]];
}

// -------------------------------------------------------------------------------
//	interactWithParentOfLockedUIElement:sender
// -------------------------------------------------------------------------------
- (void)interactWithParentOfLockedUIElement:(id)sender
{
    if (_currentlyInteracting) {
	AXUIElementRef parent = [_interactionWindow interactWithParent];
        if (parent) {
            [_inspectorWindow displayInfoForUIElement:parent];
        }
    }
}

// -------------------------------------------------------------------------------
//	interactWithUIElement:sender
// -------------------------------------------------------------------------------
- (void)interactWithUIElement:(id)sender
{
    if (_currentlyInteracting) {
	AXUIElementRef elt = (AXUIElementRef)[sender representedObject];
        [_inspectorWindow displayInfoForUIElement:elt];
	[_interactionWindow interactWithUIElement:elt];
    }
}

// -------------------------------------------------------------------------------
//	interactWithUIElementAfterDelay:uiElement
// -------------------------------------------------------------------------------
- (void)interactWithUIElementAfterDelay:(id)uiElement
{
    [self performSelector:@selector(interactWithUIElement:) withObject:uiElement afterDelay:0];
}

// -------------------------------------------------------------------------------
//	refreshInteractionUIElement:sender
// -------------------------------------------------------------------------------
- (void)refreshInteractionUIElement:(id)sender
{
    if (_currentlyInteracting) {
	AXUIElementRef elt = [_interactionWindow interactionElement];
        [_inspectorWindow displayInfoForUIElement:elt];
	[_interactionWindow interactWithUIElement:elt];
    }
}

// -------------------------------------------------------------------------------
//	unlockCurrentUIElement:sender
// -------------------------------------------------------------------------------
- (void)unlockCurrentUIElement:(id)sender
{
    _currentlyInteracting = false;
    [_inspectorWindow indicateUIElementIsLocked:false];
    [_interactionWindow close];
}

// -------------------------------------------------------------------------------
//	setHighlightLockedUIElement:highlightOn
// -------------------------------------------------------------------------------
- (void)setHighlightLockedUIElement:(BOOL)highlightOn
{
    if (_highlightLockedUIElement != highlightOn) {
        _highlightLockedUIElement = highlightOn;
        if (_currentlyInteracting) {
            [_interactionWindow setHighlighting:highlightOn];
        }
    }
}

// -------------------------------------------------------------------------------
//	highlightLockedUIElement:
// -------------------------------------------------------------------------------
- (BOOL)highlightLockedUIElement
{
    return _highlightLockedUIElement;
}

// -------------------------------------------------------------------------------
//	takeHighlightLockedUIElementValue:sender
// -------------------------------------------------------------------------------
- (void)takeHighlightLockedUIElementValue:(id)sender
{
    [self setHighlightLockedUIElement:[sender intValue] != 0];
}

// -------------------------------------------------------------------------------
//	highlightLockedUIElement:
// -------------------------------------------------------------------------------
+ (BOOL)highlightLockedUIElement
{
    return [gAppShell highlightLockedUIElement];
}

@end

// -------------------------------------------------------------------------------
//	LockUIElementHotKeyHandler:
//
//	We only register for one hotkey, so if we get here we know the hotkey combo was pressed
//	and we should go ahead and lock/unlock the current UIElement as needed
// -------------------------------------------------------------------------------
pascal OSStatus LockUIElementHotKeyHandler(EventHandlerCallRef nextHandler,EventRef theEvent, void *userData)
{
    if ([gAppShell isCurrentUIElementLocked])
		[NSTimer scheduledTimerWithTimeInterval:0.1 target:gAppShell selector:@selector(unlockCurrentUIElement:) userInfo:nil repeats:NO];
    else
		[NSTimer scheduledTimerWithTimeInterval:0.1 target:gAppShell selector:@selector(interactWithCurrentUIElement:) userInfo:nil repeats:NO];
    return noErr;
}


