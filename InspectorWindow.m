/*
 File:		InspectorWindow.m

 Description: 	This is the implementation for the InspectorWindow class that handles displaying
				information about whatever UI element the mouse cursor is over
				(or whatever element has been locked into focus).
 
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
#import "InspectorWindow.h"

@implementation InspectorWindow


// -------------------------------------------------------------------------------
//	awakeFromNib:
// -------------------------------------------------------------------------------
- (void)awakeFromNib
{
    // In this example we're using Cocoa's mouseMoved: message to trigger updating
	//[self setAcceptsMouseMovedEvents:true];
}

// -------------------------------------------------------------------------------
//	mouseMoved:theEvent
// -------------------------------------------------------------------------------
- (void)mouseMoved:(NSEvent *)theEvent
{
    // Tell AppShell that the mouse moved
	[AppShell updateCurrentUIElement];
}

// -------------------------------------------------------------------------------
//	displayInfoForUIElement:uiElement
//	Report to our console view the uiElement's descriptive string.
// -------------------------------------------------------------------------------
- (void)displayInfoForUIElement:(AXUIElementRef)uiElement
{
    [_consoleView setString:[self stringDescriptionOfUIElement:uiElement]];
    [_consoleView display];
}

// -------------------------------------------------------------------------------
//	lineageOfUIElement:element
//
//	Return the lineage array or inheritance of a given uiElement.
// -------------------------------------------------------------------------------
- (NSArray *)lineageOfUIElement:(AXUIElementRef)element
{
    NSArray *lineage = [NSArray array];
    NSString *elementDescr = [AppShell descriptionOfValue:element beingVerbose:NO];
    AXUIElementRef parent = (AXUIElementRef)[AppShell valueOfExistingAttribute:kAXParentAttribute ofUIElement:element];

    if (parent != NULL) {
        lineage = [self lineageOfUIElement:parent];
    }
    return [lineage arrayByAddingObject:elementDescr];
}

// -------------------------------------------------------------------------------
//	lineageDescriptionOfUIElement:element
//
//	Return the descriptive string of a uiElement's lineage.
// -------------------------------------------------------------------------------
- (NSString *)lineageDescriptionOfUIElement:(AXUIElementRef)element
{
    NSMutableString *result = [NSMutableString string];
    NSMutableString *indent = [NSMutableString string];
    NSArray *lineage = [self lineageOfUIElement:element];
    NSString *ancestor;
    NSEnumerator *e = [lineage objectEnumerator];
    while (ancestor = [e nextObject]) {
        [result appendFormat:@"%@%@\n", indent, ancestor];
        [indent appendString:@" "];
    }
    return result;
}

// -------------------------------------------------------------------------------
//	stringDescriptionOfUIElement:inElement
//
//	Return a descriptive string of attributes and actions of a given uiElement.
// -------------------------------------------------------------------------------
- (NSString *)stringDescriptionOfUIElement:(AXUIElementRef)inElement
{
    NSMutableString * 	theDescriptionStr = [[NSMutableString new] autorelease];
    NSArray *		theNames;
    CFIndex			nameIndex;
    CFIndex			numOfNames;

    [theDescriptionStr appendFormat:@"%@", [self lineageDescriptionOfUIElement:inElement]];
    
    // display attributes
    AXUIElementCopyAttributeNames( inElement, (CFArrayRef *)&theNames );
    if (theNames) {
    
        numOfNames = [theNames count];
        
        if (numOfNames)
            [theDescriptionStr appendString:@"\nAttributes:\n"];

        for( nameIndex = 0; nameIndex < numOfNames; nameIndex++ ) {
            
            NSString *	theName = NULL;
            id		theValue = NULL;
            Boolean	theSettableFlag = false;
            
            // Grab name
            theName = [theNames objectAtIndex:nameIndex];
                
            // Grab settable field
          	AXUIElementIsAttributeSettable( inElement, (CFStringRef)theName, &theSettableFlag );
            
            // Add string        
            [theDescriptionStr appendFormat:@"   %@%@:  “%@”\n", theName, (theSettableFlag?@" (W)":@""), [AppShell descriptionForUIElement:inElement attribute:theName beingVerbose:false]];
        
            [theValue release];
        }
    
        [theNames release];
    }
    
    // display actions
	AXUIElementCopyActionNames( inElement, (CFArrayRef *)&theNames );
    if (theNames) {
    
        numOfNames = [theNames count];
        
        if (numOfNames)
            [theDescriptionStr appendString:@"\nActions:\n"];

        for( nameIndex = 0; nameIndex < numOfNames; nameIndex++ ) {
            
            NSString *	theName 		= NULL;
           	NSString *	theDesc 		= NULL;
            
            // Grab name
            theName = [theNames objectAtIndex:nameIndex];
            
            // Grab description
        	AXUIElementCopyActionDescription( inElement, (CFStringRef)theName, (CFStringRef *)&theDesc );
            
            // Add string        
            [theDescriptionStr appendFormat:@"   %@ - %@\n", theName, theDesc];
            
            [theDesc release];
        }
    
        [theNames release];
    }
    
    return theDescriptionStr;
}

// -------------------------------------------------------------------------------
//	stringDescriptionOfCFArray:inArray
// -------------------------------------------------------------------------------
- (NSString *)stringDescriptionOfCFArray:(NSArray *)inArray
{
    NSMutableString * 	theDescriptionStr = [[NSMutableString new] autorelease];
    CFIndex				theIndex;
    CFIndex				numOfElements = [inArray count];

    [theDescriptionStr appendFormat:@"{"];
        
    for( theIndex = 0; theIndex < numOfElements; theIndex++ ) {
    
        id theObject = [inArray objectAtIndex:theIndex];
    
    	if (CFGetTypeID(theObject) == CFDictionaryGetTypeID()) {
    
            if (theIndex == 0)
                [theDescriptionStr appendFormat:@"(<UI Element: %d>)", theObject];
            else
                [theDescriptionStr appendFormat:@", (<UI Element: %d>)", theObject];
        }
        else {
            if (theIndex == 0)
                [theDescriptionStr appendFormat:@"%@", [inArray objectAtIndex:theIndex]];
            else
                [theDescriptionStr appendFormat:@", %@", [inArray objectAtIndex:theIndex]];
        }
    }
    
    [theDescriptionStr appendFormat:@"}"];
    
    return theDescriptionStr;
}

// -------------------------------------------------------------------------------
//	close:
//
//	Closing our window forces this application to quit.
// -------------------------------------------------------------------------------
- (void)close
{
    [super close];

    [NSApp terminate:NULL];
}

// -------------------------------------------------------------------------------
//	fontSizeSelected:sender
//
//	The use chose a new font size from the font size popup.  In turn change the
//	console view's font size.
// -------------------------------------------------------------------------------
- (void)fontSizeSelected:(id)sender
{
	[_consoleView setFont:[NSFont userFontOfSize:[[sender titleOfSelectedItem] floatValue]]];
    [_consoleView display];
}

// -------------------------------------------------------------------------------
//	indicateUIElementIsLocked:flag
//
//	To show that we are locked into a uiElement, draw the console view's text in red.
// -------------------------------------------------------------------------------
- (void)indicateUIElementIsLocked:(BOOL)flag
{
	[_consoleView setTextColor:(flag)?[NSColor redColor]:[NSColor blackColor]];
    [_consoleView display];
}

@end
