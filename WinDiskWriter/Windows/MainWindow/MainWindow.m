//
//  MainWindow.m
//  WinDiskWriter GUI
//
//  Created by Macintosh on 30.08.2023.
//  Copyright © 2023 TechUnRestricted. All rights reserved.
//

#import "MainWindow.h"
#import "FrameLayout.h"
#import "LabelView.h"
#import "LogView.h"
#import "VibrantTableView.h"

#import "ButtonView.h"
#import "PickerView.h"
#import "TextInputView.h"
#import "CheckBoxView.h"
#import "AdvancedTextView.h"
#import "ProgressBarView.h"

#import "SynchronizedAlertData.h"

#import "NSColor+Common.h"
#import "NSString+Common.h"
#import "NSError+Common.h"

#import "Constants.h"

#import "DiskManager.h"
#import "DiskWriter.h"
#import "HDIUtil.h"

#import "HelperFunctions.h"
#import "SlideShowedLabelView.h"

#import "ModernWindow.h"

#define WriteExitForce()                \
[self setEnabledUIState: YES];          \
return;

#define WriteExitConditionally()      \
if (self.isScheduledForStop) {        \
WriteExitForce();                     \
}

@implementation MainWindow {
    /* Initialized in -setupViews: */
    TextInputView *windowsImageInputView;
    ButtonView *chooseWindowsImageButtonView;
    
    PickerView *devicePickerView;
    ButtonView *updateDeviceListButtonView;
    
    CheckBoxView *patchInstallerRequirementsCheckboxView;
    CheckBoxView *installLegacyBootCheckBoxView;
    NSSegmentedControl *filesystemPickerSegmentedControl;
    NSSegmentedControl *partitionSchemePickerSegmentedControl;
    
    LogView *logsView;
    
    ButtonView *startStopButtonView;
    
    FrameLayoutHorizontal *bytesProgressHorizontalLayout;
    LabelView *currentOperationLabelView;
    LabelView *bytesWrittenLabelView;
    LabelView *slashSeparatorLabelView;
    LabelView *bytesFileSizeLabelView;
    
    ProgressBarView *currentOperationProgressBarView;
    ProgressBarView *totalOperationProgressBarView;
    
    NSMenuItem *quitMenuItem;
    NSMenuItem *closeMenuItem;

    ModernWindow *aboutWindow;
}

- (instancetype)initWithNSRect: (NSRect)nsRect
                         title: (NSString *)title
                       padding: (CGFloat)padding
        paddingIsTitleBarAware: (BOOL)paddingIsTitleBarAware
                   aboutWindow: (AboutWindow *)aboutWindow
                  quitMenuItem: (NSMenuItem *)quitMenuItem
                 closeMenuItem: (NSMenuItem *)closeMenuItem {
    
    self = [super initWithNSRect: nsRect
                           title: title
                         padding: padding
          paddingIsTitleBarAware: paddingIsTitleBarAware];
    
    self->aboutWindow = aboutWindow;
    self->quitMenuItem = quitMenuItem;
    self->closeMenuItem = closeMenuItem;
    
    NSButton *windowZoomButton = [self standardWindowButton:NSWindowZoomButton];
    [windowZoomButton setEnabled: NO];
    
    [self setOnCloseSelector: @selector(exitApplication)
                      target: self];
    
    [self setupViews];
    
    return self;
}

- (void)resetProgress {
    [self setCurrentProgressWithWrittenBytes: 0
                               fileSizeBytes: 0];
    
    [currentOperationProgressBarView resetProgressSynchronously];
    [totalOperationProgressBarView resetProgressSynchronously];
}

- (void)setupViews {
    NSView *spacerView = [[NSView alloc] init];
    
    [self showWindow];
    
    FrameLayoutVertical *mainVerticalLayout = (FrameLayoutVertical *)self.containerView;
    
    [mainVerticalLayout setSpacing: MAIN_CONTENT_SPACING];
    
    FrameLayoutVertical *isoPickerVerticalLayout = [[FrameLayoutVertical alloc] init]; {
        [mainVerticalLayout addView:isoPickerVerticalLayout width:INFINITY height:0];
        
        [isoPickerVerticalLayout setHugHeightFrame: YES];
        
        [isoPickerVerticalLayout setSpacing: CHILD_CONTENT_SPACING];
        
        LabelView *isoPickerLabelView = [[LabelView alloc] init]; {
            [isoPickerVerticalLayout addView:isoPickerLabelView width:INFINITY height:isoPickerLabelView.cell.cellSize.height];
            
            [isoPickerLabelView setStringValue: @"Windows Image"];
            
            [isoPickerLabelView setWantsLayer: YES];
        }
        
        FrameLayoutHorizontal *isoPickerHorizontalLayout = [[FrameLayoutHorizontal alloc] init]; {
            [isoPickerVerticalLayout addView:isoPickerHorizontalLayout width:INFINITY height:0];
            
            [isoPickerHorizontalLayout setHugHeightFrame: YES];
            
            [isoPickerHorizontalLayout setVerticalAlignment: FrameLayoutVerticalCenter];
            
            [isoPickerHorizontalLayout setSpacing: CHILD_CONTENT_SPACING];
            
            windowsImageInputView = [[TextInputView alloc] init]; {
                [isoPickerHorizontalLayout addView:windowsImageInputView width:INFINITY height:windowsImageInputView.cell.cellSize.height];
                
                if (@available(macOS 10.10, *)) {
                    [windowsImageInputView setPlaceholderString: @"Image File or Directory"];
                }
            }
            
            chooseWindowsImageButtonView = [[ButtonView alloc] init]; {
                [isoPickerHorizontalLayout addView:chooseWindowsImageButtonView minWidth:80 maxWidth:100 minHeight:0 maxHeight:INFINITY];
                
                [chooseWindowsImageButtonView setTitle: @"Choose"];
                [chooseWindowsImageButtonView setTarget: self];
                [chooseWindowsImageButtonView setAction: @selector(chooseImageAction)];
            }
        }
    }
    
    FrameLayoutVertical *devicePickerVerticalLayout = [[FrameLayoutVertical alloc] init]; {
        [mainVerticalLayout addView:devicePickerVerticalLayout width:INFINITY height:0];
        
        [devicePickerVerticalLayout setHugHeightFrame: YES];
        
        [devicePickerVerticalLayout setSpacing: CHILD_CONTENT_SPACING];
        
        
        LabelView *devicePickerLabelView = [[LabelView alloc] init]; {
            [devicePickerVerticalLayout addView:devicePickerLabelView width:INFINITY height:devicePickerLabelView.cell.cellSize.height];
            
            [devicePickerLabelView setStringValue: @"Target Device"];
        }
        
        FrameLayoutHorizontal *devicePickerHorizontalLayout = [[FrameLayoutHorizontal alloc] init]; {
            [devicePickerVerticalLayout addView:devicePickerHorizontalLayout width:INFINITY height:0];
            
            [devicePickerHorizontalLayout setHugHeightFrame:YES];
            
            devicePickerView = [[PickerView alloc] init]; {
                [devicePickerHorizontalLayout addView:devicePickerView minWidth:0 maxWidth:INFINITY minHeight:0 maxHeight:devicePickerView.cell.cellSize.height];
                
                [self updateDeviceList];
            }
            
            updateDeviceListButtonView = [[ButtonView alloc] init]; {
                [devicePickerHorizontalLayout addView:updateDeviceListButtonView minWidth:80 maxWidth:100 minHeight:0 maxHeight:INFINITY];
                
                [updateDeviceListButtonView setTitle: @"Update"];
                [updateDeviceListButtonView setTarget: self];
                [updateDeviceListButtonView setAction: @selector(updateDeviceList)];
            }
        }
    }
    
    [mainVerticalLayout addView:spacerView width:INFINITY height: 3];
    
    patchInstallerRequirementsCheckboxView = [[CheckBoxView alloc] init]; {
        [mainVerticalLayout addView:patchInstallerRequirementsCheckboxView width:INFINITY height:patchInstallerRequirementsCheckboxView.cell.cellSize.height];
        
        [patchInstallerRequirementsCheckboxView setTitle: @"Patch Installer Requirements"];
        [patchInstallerRequirementsCheckboxView setToolTip:
             @"Remove TPM, Secure Boot and RAM requirements from the installer." "\n"
             "(Windows 11 only)"
        ];
        
        [patchInstallerRequirementsCheckboxView setState: NSOffState];
    }
    
    installLegacyBootCheckBoxView = [[CheckBoxView alloc] init]; {
        [mainVerticalLayout addView:installLegacyBootCheckBoxView width:INFINITY height:installLegacyBootCheckBoxView.cell.cellSize.height];
        
        [installLegacyBootCheckBoxView setTitle: @"Install Legacy Boot Sector"];
        [installLegacyBootCheckBoxView setToolTip: @"Add support for older firmware that don't support booting from EFI."];
        
        [installLegacyBootCheckBoxView setState: [HelperFunctions hasElevatedRights]];

        if (![HelperFunctions hasElevatedRights]) {
            [installLegacyBootCheckBoxView setAction: @selector(requireRestartAsRoot)];
        } else {
            [NSApp activateIgnoringOtherApps: YES];
            [self makeKeyAndOrderFront: NULL];
            [NSApp activateIgnoringOtherApps: NO];
        }
        
    }
    
    [mainVerticalLayout addView:spacerView width:INFINITY height: 3];
    
    
    FrameLayoutVertical *formattingSectionVerticalLayout = [[FrameLayoutVertical alloc] init]; {
        [mainVerticalLayout addView:formattingSectionVerticalLayout width:INFINITY height:0];
        
        [formattingSectionVerticalLayout setToolTip:
             @"Desired filesystem for the destination device." "\n"
             "(FAT32 is the best choice for compatibility.)"];
        
        [formattingSectionVerticalLayout setHugHeightFrame: YES];
        [formattingSectionVerticalLayout setSpacing: CHILD_CONTENT_SPACING];
        
        FrameLayoutVertical *fileSystemPickerVerticalLayout = [[FrameLayoutVertical alloc] init]; {
            [formattingSectionVerticalLayout addView:fileSystemPickerVerticalLayout width:INFINITY height:0];
            [fileSystemPickerVerticalLayout setHugHeightFrame: YES];
            
            [fileSystemPickerVerticalLayout setSpacing:CHILD_CONTENT_SPACING];
            
            LabelView *filesystemLabelView = [[LabelView alloc] init]; {
                [fileSystemPickerVerticalLayout addView:filesystemLabelView width:INFINITY height:filesystemLabelView.cell.cellSize.height];
                
                [filesystemLabelView setStringValue: @"File System"];
            }
            
            filesystemPickerSegmentedControl = [[NSSegmentedControl alloc] init]; {
                [filesystemPickerSegmentedControl setSegmentCount:2];
                
                [filesystemPickerSegmentedControl setLabel:FILESYSTEM_TYPE_FAT32_TITLE forSegment:0];
                [filesystemPickerSegmentedControl setLabel:FILESYSTEM_TYPE_EXFAT_TITLE forSegment:1];
                
                [filesystemPickerSegmentedControl setSelectedSegment:0];
                
                [fileSystemPickerVerticalLayout addView:filesystemPickerSegmentedControl width:INFINITY height:filesystemPickerSegmentedControl.cell.cellSize.height];
            }
        }
        
        FrameLayoutVertical *partitionSchemePickerVerticalLayout = [[FrameLayoutVertical alloc] init]; {
            [formattingSectionVerticalLayout addView:partitionSchemePickerVerticalLayout width:INFINITY height:0];
            
            [partitionSchemePickerVerticalLayout setHugHeightFrame: YES];
            [partitionSchemePickerVerticalLayout setSpacing: CHILD_CONTENT_SPACING];
            
            /*
            LabelView *partitionSchemeLabelView = [[LabelView alloc] init]; {
                [partitionSchemePickerVerticalLayout addView: partitionSchemeLabelView
                                                    minWidth: 0
                                                    maxWidth: INFINITY
                                                   minHeight: partitionSchemeLabelView.cell.cellSize.height
                                                   maxHeight: partitionSchemeLabelView.cell.cellSize.height];
                
                [partitionSchemeLabelView setStringValue:@"Partition Scheme"];
                [partitionSchemeLabelView setEnabled: NO];
                
            }
            
            partitionSchemePickerSegmentedControl = [[NSSegmentedControl alloc] init]; {
                [partitionSchemePickerSegmentedControl setSegmentCount:2];
                
                [partitionSchemePickerSegmentedControl setEnabled: NO];
                
                [partitionSchemePickerSegmentedControl setLabel: PARTITION_SCHEME_TYPE_MBR_TITLE
                                                     forSegment: 0];
                [partitionSchemePickerSegmentedControl setLabel: PARTITION_SCHEME_TYPE_GPT_TITLE
                                                     forSegment: 1];
                
                [partitionSchemePickerSegmentedControl setSelectedSegment:0];
                
                // [partitionSchemePickerVerticalLayout addView:partitionSchemePickerSegmentedControl minWidth:0 maxWidth:INFINITY minHeight:partitionSchemePickerSegmentedControl.cell.cellSize.height maxHeight:partitionSchemePickerSegmentedControl.cell.cellSize.height];
            }*/
        }
        
    }
    
    [mainVerticalLayout addView:spacerView width:4 height:4];
    
    logsView = [[LogView alloc] init]; {
        [mainVerticalLayout addView:logsView minWidth:0 maxWidth:INFINITY minHeight:120 maxHeight:INFINITY];
    }
    
    [mainVerticalLayout addView:spacerView width:0 height:4];
    
    FrameLayoutVertical *operationMonitoringVerticalLayout = [[FrameLayoutVertical alloc] init]; {
        [mainVerticalLayout addView:operationMonitoringVerticalLayout width:INFINITY height:0];
        
        [operationMonitoringVerticalLayout setHugHeightFrame: YES];
        
        [operationMonitoringVerticalLayout setSpacing: 2];
        
        FrameLayoutHorizontal *textInfoHorizontalLayout = [[FrameLayoutHorizontal alloc] init]; {
            [operationMonitoringVerticalLayout addView:textInfoHorizontalLayout width:INFINITY height:0];
            
            [textInfoHorizontalLayout setAlphaValue: 0.75];
            
            [textInfoHorizontalLayout setHugHeightFrame: YES];
            
            currentOperationLabelView = [[LabelView alloc] init]; {
                [textInfoHorizontalLayout addView:currentOperationLabelView width:INFINITY height:currentOperationLabelView.cell.cellSize.height];
            }
            
            NSString * const LARGEST_BYTES_CHAR_WIDTH_STRING = @"444.44 MB";
            
            bytesProgressHorizontalLayout = [[FrameLayoutHorizontal alloc] init]; {
                [textInfoHorizontalLayout addView:bytesProgressHorizontalLayout width:0 height:0];
                
                [bytesProgressHorizontalLayout setHugHeightFrame: YES];
                [bytesProgressHorizontalLayout setHugWidthFrame: YES];
                
                bytesWrittenLabelView = [[LabelView alloc] init]; {
                    // Reserving a space for symbols in order to get a proper cellSize values
                    [bytesWrittenLabelView setStringValue: LARGEST_BYTES_CHAR_WIDTH_STRING];
                    
                    [bytesWrittenLabelView setAlignment: NSTextAlignmentCenter];
                    
                    [bytesProgressHorizontalLayout addView: bytesWrittenLabelView
                                                     width: bytesWrittenLabelView.cell.cellSize.width
                                                    height: bytesWrittenLabelView.cell.cellSize.height];
                }
                
                slashSeparatorLabelView = [[LabelView alloc] init]; {
                    [slashSeparatorLabelView setStringValue: @"/"];
                    
                    [bytesProgressHorizontalLayout addView: slashSeparatorLabelView
                                                     width: slashSeparatorLabelView.cell.cellSize.width
                                                    height: slashSeparatorLabelView.cell.cellSize.height];
                }
                
                bytesFileSizeLabelView = [[LabelView alloc] init]; {
                    // Reserving a space for symbols in order to get a proper cellSize values
                    [bytesFileSizeLabelView setStringValue: LARGEST_BYTES_CHAR_WIDTH_STRING];
                    
                    [bytesFileSizeLabelView setAlignment: NSTextAlignmentCenter];
                    
                    [bytesProgressHorizontalLayout addView: bytesFileSizeLabelView
                                                     width: bytesFileSizeLabelView.cell.cellSize.width
                                                    height: bytesFileSizeLabelView.cell.cellSize.height];
                }
            }
        }
        
        FrameLayoutVertical *progressBarVerticalLayout = [[FrameLayoutVertical alloc] init]; {
            [operationMonitoringVerticalLayout addView:progressBarVerticalLayout width:INFINITY height:0];
            
            [progressBarVerticalLayout setHugHeightFrame: YES];
            
            currentOperationProgressBarView = [[ProgressBarView alloc] init]; {
                [progressBarVerticalLayout addView:currentOperationProgressBarView width:INFINITY height:14];
            }
            
            totalOperationProgressBarView = [[ProgressBarView alloc] init]; {
                [progressBarVerticalLayout addView:totalOperationProgressBarView width:INFINITY height:14];
            }
        }
        
    }
    
    FrameLayoutVertical *startStopVerticalLayout = [[FrameLayoutVertical alloc] init]; {
        [mainVerticalLayout addView:startStopVerticalLayout width:INFINITY height:50];
        
        [startStopVerticalLayout setHorizontalAlignment: FrameLayoutHorizontalCenter];
        [startStopVerticalLayout setVerticalAlignment: FrameLayoutVerticalCenter];
        
        [startStopVerticalLayout setSpacing:10];
        
        // [startStopVerticalLayout setHugHeightFrame: YES];
        
        startStopButtonView = [[ButtonView alloc] init]; {
            [startStopVerticalLayout addView:startStopButtonView minWidth:40 maxWidth:180 minHeight:startStopButtonView.cell.cellSize.height maxHeight:startStopButtonView.cell.cellSize.height];
            
            [startStopButtonView setTarget: self];
        }
        
    }
    
    NSArray *slideShowTextArray = @[
        [NSString stringWithFormat:@"%@ 2023", DEVELOPER_NAME],
        MENU_DONATE_ME_TITLE
    ];
    
    SlideShowedLabelView *slideShowedLabelView = [[SlideShowedLabelView alloc] initWithStringArray: slideShowTextArray
                                                                                     delayDuration: 8]; {
        [mainVerticalLayout addView:slideShowedLabelView width:INFINITY height:slideShowedLabelView.cell.cellSize.height];
       
        [slideShowedLabelView setAlignment:NSTextAlignmentCenter];
        
        [slideShowedLabelView setIsSlideShowed: YES];

        [slideShowedLabelView registerClickWithTarget: [HelperFunctions class]
                                             selector: @selector(openDonationsPage)];
    }
    
    [self setEnabledUIState: YES];
}

- (void)exitApplication {
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)displayWarningAlertWithTitle: (NSString *)title
                            subtitle: (NSString *_Nullable)subtitle
                                icon: (NSImageName)icon {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText: title];
        
        if (subtitle) {
            [alert setInformativeText: subtitle];
        }
        
        [alert setIcon: [NSImage imageNamed: icon]];
        
        [alert beginSheetModalForWindow: self
                          modalDelegate: NULL
                         didEndSelector: NULL
                            contextInfo: NULL];
    });
}

- (void)alertActionStopPromptDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertSecondButtonReturn) {
        [startStopButtonView setTitle: BUTTON_STOPPING_TITLE];
        
        [startStopButtonView setEnabled: NO];
        
        [self setIsScheduledForStop: YES];
    }
}

- (void)alertWarnAboutErrorDuringWriting: (NSAlert *)alert
                              returnCode: (NSInteger)returnCode
                             contextInfo: (void *)contextInfo {
    SynchronizedAlertData *synchronizedAlertData = (__bridge SynchronizedAlertData *)(contextInfo);
    [synchronizedAlertData setResultCode:returnCode];
    
    dispatch_semaphore_signal(synchronizedAlertData.semaphore);
}

- (void)stopAction {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: STOP_PROCESS_PROMPT_TITLE];
    [alert setInformativeText: STOP_PROCESS_PROMPT_SUBTITLE];
    [alert addButtonWithTitle: BUTTON_DISMISS_TITLE];
    [alert addButtonWithTitle: BUTTON_SCHEDULE_CANCELLATION_TITLE];
    
    [alert beginSheetModalForWindow: self
                      modalDelegate: self
                     didEndSelector: @selector(alertActionStopPromptDidEnd:returnCode:contextInfo:)
                        contextInfo: NULL];
}

- (void)alertActionStartPromptDidEnd: (NSAlert *)alert
                          returnCode: (NSInteger)returnCode
                         contextInfo: (void *)contextInfo {
    if (returnCode == NSAlertSecondButtonReturn) {
        [self writeAction];
    }
}

- (void)alertActionRestartAsRootDidEnd: (NSAlert *)alert
                            returnCode: (NSInteger)returnCode
                           contextInfo: (void *)contextInfo {
    NSError *restartError = NULL;
    
    if (returnCode == NSAlertFirstButtonReturn) {
        [HelperFunctions restartWithElevatedPermissionsWithError: &restartError];
    }
    
    if (restartError != NULL) {
        [self displayWarningAlertWithTitle: @"Failed to restart"
                                  subtitle: [restartError stringValue]
                                      icon: NSImageNameCaution];
    }
}

- (void)requireRestartAsRoot {
    [installLegacyBootCheckBoxView setState: NSOffState];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: @"This option requires the application to be relaunched with Root Permissions"];
    [alert setInformativeText: @"All unsaved changes will be lost"];
    [alert addButtonWithTitle: @"Relaunch"];
    [alert addButtonWithTitle: BUTTON_DISMISS_TITLE];
    
    [alert beginSheetModalForWindow: self
                      modalDelegate: self
                     didEndSelector: @selector(alertActionRestartAsRootDidEnd:returnCode:contextInfo:)
                        contextInfo: NULL];
}

- (void)startAction {
    NSString *imagePath = [windowsImageInputView.stringValue copy];
    if (imagePath.length == 0) {
        
        [self displayWarningAlertWithTitle: FORGOT_SOMETHING_TITLE
                                  subtitle: PATH_FIELD_IS_EMPTY_SUBTITLE
                                      icon: NSImageNameCaution];
        
        [logsView appendRow: PATH_FIELD_IS_EMPTY_SUBTITLE
                                              logType: ASLogTypeAssertionError];
        WriteExitForce();
    }
    
    BOOL imagePathIsDirectory = NO;
    BOOL imageExists = [[NSFileManager defaultManager] fileExistsAtPath: imagePath
                                                            isDirectory: &imagePathIsDirectory];
    
    if (!imageExists) {
        [self displayWarningAlertWithTitle: CHECK_DATA_CORRECTNESS_TITLE
                                  subtitle: PATH_DOES_NOT_EXIST_SUBTITLE
                                      icon: NSImageNameCaution];
        
        [logsView appendRow: PATH_DOES_NOT_EXIST_SUBTITLE
                                              logType: ASLogTypeAssertionError];
        
        WriteExitForce();
    }
    
    if ([devicePickerView numberOfItems] <= 0) {
        [self displayWarningAlertWithTitle: NO_AVAILABLE_DEVICES_TITLE
                                  subtitle: PRESS_UPDATE_BUTTON_SUBTITLE
                                      icon: NSImageNameCaution];
        
        [logsView appendRow: NO_AVAILABLE_DEVICES_TITLE
                                              logType: ASLogTypeAssertionError];
        WriteExitForce();
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: START_PROCESS_PROMPT_TITLE];
    [alert setInformativeText: START_PROCESS_PROMPT_SUBTITLE];
    [alert addButtonWithTitle: BUTTON_CANCEL_TITLE];
    [alert addButtonWithTitle: BUTTON_START_TITLE];
    
    [alert beginSheetModalForWindow: self
                      modalDelegate: self
                     didEndSelector: @selector(alertActionStartPromptDidEnd:returnCode:contextInfo:)
                        contextInfo: NULL];
}

- (void)setCurrentProgressWithWrittenBytes: (UInt64)writtenBytes
                             fileSizeBytes: (UInt64)fileSizeBytes {
    dispatch_async(dispatch_get_main_queue(), ^{
        // We don't need to display progress in bytes if the file size is 0 bytes.
        if (fileSizeBytes == 0) {
            [self->bytesProgressHorizontalLayout setHidden: YES];
            return;
        }
        
        // Otherwise, show the bytes progress layout (if hidden)
        if (self->bytesProgressHorizontalLayout.isHidden) {
            [self->bytesProgressHorizontalLayout setHidden: NO];
        }
        
        // Setting the progress bytes formatted string
        [self->bytesWrittenLabelView setStringValue: [HelperFunctions unitFormattedSizeFor: writtenBytes]];
        [self->bytesFileSizeLabelView setStringValue: [HelperFunctions unitFormattedSizeFor: fileSizeBytes]];
        
        // Setting the progress bar current operation progress
        [self->currentOperationProgressBarView setMaxValue: fileSizeBytes];
        [self->currentOperationProgressBarView setDoubleValue: writtenBytes];
    });
}

- (void)setCurrentProgressTitle: (NSString *)progressTitle {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->currentOperationLabelView setStringValue: progressTitle];
    });
}

- (void)writeAction {
    [self setIsScheduledForStop: NO];
    [self setEnabledUIState: NO];
    
    // Saved information from the last device scanning operation
    DiskInfo *destinationSavedDiskInfo = [(IdentifiableMenuItem *)devicePickerView.selectedItem diskInfo];
    
    // Making sure that the selected BSD Device name is still available
    DiskManager *secondVerifyingStageDiskManager = [[DiskManager alloc] initWithBSDName:destinationSavedDiskInfo.BSDName];
    DiskInfo *secondVerifyingStageDiskInfo = [secondVerifyingStageDiskManager diskInfo];

    if (secondVerifyingStageDiskManager == NULL || !destinationSavedDiskInfo.isDeviceUnit) {
        [self displayWarningAlertWithTitle: BSD_DEVICE_IS_NO_LONGER_AVAILABLE_TITLE
                                  subtitle: PRESS_UPDATE_BUTTON_SUBTITLE
                                      icon: NSImageNameCaution];
        
        [logsView appendRow: BSD_DEVICE_IS_NO_LONGER_AVAILABLE_TITLE
                                              logType: ASLogTypeFatal];
        WriteExitForce();
    }
    
    /* !!DATA-LOSS PREVENTION!!
    - We need to make sure that we will format exactly the device that was selected in the list
    of available devices, and not the one that managed to occupy the vacated BSD Name.
    - The most adequate way in this case is to verify the initialization date of the bsd device. */
    
    if (destinationSavedDiskInfo.appearanceTime.doubleValue != secondVerifyingStageDiskInfo.appearanceTime.doubleValue) {
        [self displayWarningAlertWithTitle: BSD_DEVICE_INFO_IS_OUTDATED_OR_INVALID
                                  subtitle: PRESS_UPDATE_BUTTON_SUBTITLE
                                      icon: NSImageNameCaution];
        
        [logsView appendRow: BSD_DEVICE_INFO_IS_OUTDATED_OR_INVALID
                                              logType: ASLogTypeFatal];
        
        WriteExitForce();
    }
    
    NSError *imageMountError = NULL;
    NSString *mountedImagePath = [HelperFunctions windowsSourceMountPath: windowsImageInputView.stringValue
                                                                      error: &imageMountError];
    if (imageMountError != NULL) {
        NSString *errorSubtitle = imageMountError.stringValue;
        NSString *logText = [NSString stringWithFormat:@"%@ (%@)", IMAGE_VERIFICATION_ERROR_TITLE, errorSubtitle];
        
        [self displayWarningAlertWithTitle: IMAGE_VERIFICATION_ERROR_TITLE
                                  subtitle: errorSubtitle
                                      icon: NSImageNameCaution];
        
        [logsView appendRow: logText
                                              logType: ASLogTypeFatal];
        
        WriteExitForce();
    }
    
    Filesystem selectedFileSystem;
    if (filesystemPickerSegmentedControl.selectedSegment == 0) {
        selectedFileSystem = FilesystemFAT32;
    } else {
        selectedFileSystem = FilesystemExFAT;
    }
    
    /*
     ! We don't need anything other than MBR !
     
     [Reason №1]: If GPT is selected, diskutil creates an additional EFI partition for UEFI system.
     But there is a problem: Windows Installer is very buggy.
     If the installation media has a EFI partition, it will just crash with an error:
     "Windows could not prepare the computer to boot into the next phase of installation".
     
     [Reason №2]: Why GPT? There is no any benefit from it.
     It less compatible with some firmwares/operating systems.
     For example, my Lenovo Q67 motherboard can't even boot from GPT-formatted disks in UEFI mode.
     */
    
    PartitionScheme selectedPartitionScheme = PartitionSchemeMBR;
     
    [logsView appendRow: [NSString stringWithFormat: @"Image was mounted successfully on \"%@\".", mountedImagePath]
                                            logType: ASLogTypeSuccess];
    
    NSString *newPartitionName = [NSString stringWithFormat: @"WDW_%@", [HelperFunctions randomStringWithLength:7]];
    [logsView appendRow: [NSString stringWithFormat: @"Generated partition name: \"%@\".", newPartitionName]
                                            logType: ASLogTypeLog];
    
    NSString *targetPartitionPath = [NSString stringWithFormat: @"/Volumes/%@", newPartitionName];
    [logsView appendRow: [NSString stringWithFormat: @"Target partition path: \"%@\".", targetPartitionPath]
                                            logType: ASLogTypeLog];
    
    BOOL patchInstallerRequirements = patchInstallerRequirementsCheckboxView.state == NSOnState;
    BOOL installLegacyBoot = installLegacyBootCheckBoxView.state == NSOnState;
    
    NSString *diskEraseOperationText = [NSString stringWithFormat:
                                        @"Device %@ (%@ %@) is ready to be erased with the following properties: ("
                                        "partition_name: \"%@\", "
                                        "partition_scheme: \"%@\", "
                                        "filesystem: \"%@\", "
                                        "patch_security_checks: \"%d\", "
                                        "install_legacy_boot: \"%d\""
                                        ").",
                                        destinationSavedDiskInfo.BSDName,
                                        destinationSavedDiskInfo.deviceVendor,
                                        destinationSavedDiskInfo.deviceModel,
                                        newPartitionName,
                                        selectedPartitionScheme,
                                        selectedFileSystem,
                                        patchInstallerRequirements,
                                        installLegacyBoot];
    
    [logsView appendRow: diskEraseOperationText
                logType: ASLogTypeLog];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self setCurrentProgressTitle: @"Formatting the drive"];
        
        NSError *diskEraseError = NULL;
        [secondVerifyingStageDiskManager diskUtilEraseDiskWithPartitionScheme: selectedPartitionScheme
                                                     filesystem: selectedFileSystem
                                                        newName: newPartitionName
                                                          error: &diskEraseError];
        
        if (diskEraseError != NULL) {
            [self displayWarningAlertWithTitle: DISK_ERASE_FAILURE_TITLE
                                      subtitle: diskEraseError.stringValue
                                          icon: NSImageNameCaution];
            
            [self->logsView appendRow: [DISK_ERASE_FAILURE_TITLE stringByAppendingFormat: @" (Error message: %@)", diskEraseError.stringValue]
                                                        logType: ASLogTypeFatal];
            
            WriteExitForce();
        }
        
        [self setCurrentProgressTitle: DISK_ERASE_SUCCESS_TITLE];
        
        [self->logsView appendRow: DISK_ERASE_SUCCESS_TITLE
                                                    logType: ASLogTypeSuccess];
        
        WriteExitConditionally();
        
        DWFilesContainer *filesContainer = [DWFilesContainer containerFromContainerPath: mountedImagePath
                                                                               callback: ^enum DWAction(DWFile * _Nonnull fileInfo, enum DWFilesContainerMessage message) {
            if (self.isScheduledForStop) {
                return DWActionStop;
            }
            
            return DWActionContinue;
        }];
        
        WriteExitConditionally();
        
        [self->totalOperationProgressBarView setMaxValueSynchronously: filesContainer.files.count + 4 /* Magic number "Just-in-case" */];
        
        DiskWriter *diskWriter = [[DiskWriter alloc] initWithDWFilesContainer: filesContainer
                                                              destinationPath: targetPartitionPath
                                                       destinationDiskManager: secondVerifyingStageDiskManager
        ];
        
        [diskWriter setDestinationFilesystem: selectedFileSystem];
        [diskWriter setPatchInstallerRequirements: patchInstallerRequirements];
        [diskWriter setInstallLegacyBoot: installLegacyBoot];
        
        NSError *writeError = NULL;
        
        [diskWriter startWritingWithError: &writeError
                         progressCallback: ^DWAction(DWFile * _Nonnull dwFile, uint64 copiedBytes, DWOperationType operationType, DWOperationResult operationResult, NSError *_Nullable error) {
            if (self.isScheduledForStop) {
                return DWActionStop;
            }
            
            // This way we can determine that we are starting a new operation. (We can also use a DWOperationResultStart for it.)
            if (copiedBytes == 0) {
                [self->currentOperationProgressBarView resetProgressSynchronously];
                
                [self setCurrentProgressTitle: [dwFile.sourcePath lastPathComponent]];
            }
            
            [self setCurrentProgressWithWrittenBytes: copiedBytes
                                       fileSizeBytes: dwFile.size];
            
            NSString *destinationCurrentFilePath = [targetPartitionPath stringByAppendingPathComponent: dwFile.sourcePath];
            NSMutableString *onscreenLogText = [NSMutableString string];
            
            switch (operationType) {
                case DWOperationTypeCreateDirectory:
                    [onscreenLogText appendString: @"Create directory: "];
                    break;
                case DWOperationTypeWriteFile:
                    [onscreenLogText appendString: @"Write File: "];
                    break;
                case DWOperationTypeSplitWindowsImage:
                    [onscreenLogText appendString: @"Split Image: "];
                    break;
                case DWOperationTypeExtractWindowsBootloader:
                    [onscreenLogText appendString: @"Extract Bootloader: "];
                    break;
                case DWOperationTypePatchWindowsInstallerRequirements:
                    [onscreenLogText appendString: @"Patch Installer Requirements: "];
                    break;
                case DWOperationTypeInstallLegacyBootSector:
                    [onscreenLogText appendString: @"Install Legacy Bootloader: "];
                    break;
            }
            
            [onscreenLogText appendString: destinationCurrentFilePath];
            
            switch (operationResult) {
                case DWOperationResultStart:
                    [self->logsView appendRow:onscreenLogText logType:ASLogTypeStart];
                    break;
                case DWOperationResultProcess: {
                    // Don't need to do anything ¯\_(ツ)_/¯
                    break;
                }
                case DWOperationResultSuccess:
                    [self->logsView appendRow:onscreenLogText logType:ASLogTypeSuccess];
                    
                    [self->totalOperationProgressBarView incrementBySynchronously: 1];
                    break;
                case DWOperationResultFailure:
                    if (error != NULL) {
                        [onscreenLogText appendString: [NSString stringWithFormat: @" (Error message: %@)", error.stringValue]];
                    }
                    
                    [self->logsView appendRow:onscreenLogText logType:ASLogTypeFailure];
                    break;
                case DWOperationResultSkipped:
                    [self->logsView appendRow:onscreenLogText logType:ASLogTypeSkipped];
                    break;
            }
            
            // Handling a situation when an error occurred during writing
            if (operationResult == DWOperationResultFailure) {
                /*
                 Old Cocoa is crap.
                 Can't do anything better ¯\_(ツ)_/¯.
                 I need to support old OS X releases and maintain the modern look.
                 */
                
                SynchronizedAlertData *synchronizedAlertData = [[SynchronizedAlertData alloc] initWithSemaphore: dispatch_semaphore_create(0)];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    // Closing the currently displayed alert (if required).
                    [self removeAttachedSheetWithReturnCode: NSAlertFirstButtonReturn];
                    
                    NSAlert *alert = [[NSAlert alloc] init];
                    
                    [alert setMessageText: @"A problem occurred when writing the file to disk"];
                    
                    NSMutableString *errorReasonMutableString = [NSMutableString stringWithString: @"Would you like to skip this file, or stop writing?"];
                    
                    if (error != NULL) {
                        [errorReasonMutableString appendFormat: @"\n(Reason: %@)", [error stringValue]];
                    }
                    
                    [errorReasonMutableString appendFormat: @"\n[%@]", destinationCurrentFilePath];
                    
                    [alert setInformativeText: errorReasonMutableString];
                    
                    [alert addButtonWithTitle: @"Stop Writing"];
                    [alert addButtonWithTitle: @"Skip File"];
                    
                    [alert setIcon: [NSImage imageNamed: NSImageNameCaution]];
                    
                    [alert beginSheetModalForWindow: self
                                      modalDelegate: self
                                     didEndSelector: @selector(alertWarnAboutErrorDuringWriting:returnCode:contextInfo:)
                                        contextInfo: (__bridge void * _Nullable)(synchronizedAlertData)];
                });
                
                // Using semaphores in order to get this in sync with this thread.
                dispatch_semaphore_wait(synchronizedAlertData.semaphore, DISPATCH_TIME_FOREVER);
                
                if (synchronizedAlertData.resultCode == NSAlertFirstButtonReturn) {
                    [self setIsScheduledForStop: YES];
                    
                    return DWActionStop;
                } else {
                    return DWActionSkip;
                }
            }
            
            return DWActionContinue;
        }];
        
        WriteExitConditionally();
        
        if (writeError) {
            [self displayWarningAlertWithTitle:IMAGE_WRITING_FAILURE_TITLE subtitle:writeError.stringValue icon:NSImageNameCaution];
            [self->logsView appendRow:writeError.stringValue logType:ASLogTypeFatal];
            
            WriteExitForce();
        }
        
        [self displayWarningAlertWithTitle:IMAGE_WRITING_SUCCESS_TITLE subtitle:IMAGE_WRITING_SUCCESS_SUBTITLE icon: NSImageNameStatusAvailable];
        
        [self->logsView appendRow:IMAGE_WRITING_SUCCESS_TITLE logType:ASLogTypeSuccess];
        
        WriteExitForce();
    });
    
}

- (void)chooseImageAction {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    
    [openPanel setCanChooseFiles: YES];
    [openPanel setCanChooseDirectories: YES];
    [openPanel setAllowsMultipleSelection: NO];
    [openPanel setAllowedFileTypes: @[@"iso"]];
    
    [openPanel runModal];
    
    NSString *path = openPanel.URL.path;
    if (path == NULL) {
        return;
    }
    
    [windowsImageInputView setStringValue:path];
    
}

- (void)updateDeviceList {
    [devicePickerView removeAllItems];
    
    [logsView appendRow:@"Clearing the device picker list." logType:ASLogTypeLog];
    
    NSArray<NSString *> *bsdNames = [DiskManager BSDDrivesNames];
    
    NSString *textLog = [NSString stringWithFormat: @"Found devices: %@", [bsdNames componentsJoinedByString:@", "]];
    [logsView appendRow:textLog logType:ASLogTypeLog];
    
    for (NSString *bsdName in bsdNames) {
        DiskManager *diskManager = [[DiskManager alloc] initWithBSDName: bsdName];
        DiskInfo *diskInfo = [diskManager diskInfo];
        
        if (diskInfo.isNetworkVolume || diskInfo.isInternal ||
            !diskInfo.isDeviceUnit || !diskInfo.isWholeDrive || !diskInfo.isWritable) {
            continue;
        }
        
        IdentifiableMenuItem *identifiableMenuItem = [[IdentifiableMenuItem alloc] initWithDiskInfo:diskInfo];
        
        [devicePickerView.menu addItem:identifiableMenuItem];
    }
}

- (void)setEnabledUIState:(BOOL)enabledUIState {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_enabledUIState = enabledUIState;
        
        [self->startStopButtonView setEnabled: YES];
        
        if (enabledUIState) {
            [self resetProgress];
            [self->currentOperationLabelView setStringValue: @"Ready for action"];
            
            [self->quitMenuItem setAction:@selector(terminate:)];
            [self->closeMenuItem setAction:@selector(close)];
            
            [self->bytesWrittenLabelView setStringValue: @""];
            [self->bytesFileSizeLabelView setStringValue: @""];
            
            [self->startStopButtonView setTitle: BUTTON_START_TITLE];
            [self->startStopButtonView setAction: @selector(startAction)];
        } else {
            [self->quitMenuItem setAction: NULL];
            [self->closeMenuItem setAction: NULL];
            
            [self->startStopButtonView setTitle: BUTTON_STOP_TITLE];
            [self->startStopButtonView setAction: @selector(stopAction)];
        }
        
        [self->updateDeviceListButtonView setEnabled: enabledUIState];
        [self->patchInstallerRequirementsCheckboxView setEnabled: enabledUIState];
        [self->installLegacyBootCheckBoxView setEnabled: enabledUIState];
        [self->windowsImageInputView setEnabled: enabledUIState];
        [self->devicePickerView setEnabled: enabledUIState];
                
        [self->chooseWindowsImageButtonView setEnabled: enabledUIState];
        [self->filesystemPickerSegmentedControl setEnabled: enabledUIState];
        
        NSButton *windowCloseButton = [self standardWindowButton: NSWindowCloseButton];
        [windowCloseButton setEnabled: enabledUIState];
    });
}

@end