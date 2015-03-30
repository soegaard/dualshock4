#lang racket
(require (for-syntax syntax/parse racket/syntax racket/base))
(require ffi/unsafe
         ffi/unsafe/objc
         ffi/unsafe/define)

(define (>> n places) (arithmetic-shift n (- places)))

;;; 
;;; Dualshock 4 by Sony is the standard game controller used with the Playstation 4.
;;; This packages makes it possible to use the Dualshock 4 game controller i Racket games on OS X.
;;; Apple provides a GameController framework, unfortunately the Dualshock 4 controller
;;; is not supported. Therefore this package uses the IOKit framework and in particular the
;;; IOHID part of the framework. Here HID stands for Human Interface Device. It is a general
;;; library used to usb keyboards, joysticks, mice etc.

; 1. Find documentation:
; https://developer.apple.com/library/mac/documentation/IOKit/Reference/IOHIDManager_header_reference/

; Docs
;   OHIDManager defines an Human Interface Device (HID) managment object. 
;   It provides global interaction with managed HID devices such as discovery/removal 
;   and receiving input events. IOHIDManager is also a CFType object and as such 
;   conforms to all the conventions expected such object.


; 2. Find the name of the framework
;    From the url, one sees the framework is called IOKit.
;    We can check that the name is indeed IOKit using the terminal:
;      soegaard$ mdfind GameController
;      ...
;      /System/Library/Frameworks/IOKit.framework/...
;      ...
;    Yep, the framework is called IOKit.

; 3. Import the framework using the ffi.

(define iokit-lib (ffi-lib "/System/Library/Frameworks/IOKit.framework/IOKit"))

(unless iokit-lib 
  (error 'dualshock4.rkt "The IOKit framework didn't load"))

(define-ffi-definer define-iokit iokit-lib)

; 4. Create an IOHIDManager object
; Docs
;   Objective-C
;     IOHIDManagerRef IOHIDManagerCreate ( CFAllocatorRef allocator, IOOptionBits options );
;   Discussion
;     The IOHIDManager object is meant as a global management system for communicating with 
;     HID devices.

; The function takes two inputs:
;   The allocator has the type CFAllocatorRef.
;   The prefix CF means the type is defined in the CoreFoundation, which
;   is automatically imported by the FFI.

;   The documentation for CFAllocatorRef says 
;      i) Swift:  typealias CFAllocatorRef = CFAllocator
;     ii) to use kCFAllocatorDefault unless there are special circumstances. 
;   Furthermore kCFAllocatorDefault is a synonym for NULL.
(define CFAllocatorRef (_or-null (_cpointer 'CFAllocatorRef)))

(define kCFAllocatorDefault #f) ; the FFI represents NULL as #f

;   The second argument, options, has the type IOOptionBits.
(define IOOptionBits _int)
;   The values are found in 
;     /System/Library/Frameworks/Kernel.framework/Versions/A/Headers/IOKit/hid/IOHIDKeys.h        
;   which were found by:
;     mdfind kIOHIDOptionsTypeNone
(define kIOHIDOptionsTypeNone        #x00) ; 0
(define kIOHIDOptionsTypeSeizeDevice #x01) ; 1
;   In general constants that begin with a lower case k are defined in .h files.
;   The easiest way to find the header file is to use mdfind.

;   The return value of IOHIDManagerCreate has the type IOHIDManagerRef.
;   Let's import the class (from IOKit):

;(import-class IOHIDManager)
;(unless IOHIDManager (error 'imort-class "IOHIDManager wasn't imported"))

; A reference to a IOHIDManger is called IOHIDManagerRef:
(define IOHIDManagerRef (_cpointer 'IOHIDManagerRef))

; We are now ready to import IOHIDManagerCreate.
(define-iokit IOHIDManagerCreate
  (_fun CFAllocatorRef IOOptionBits -> IOHIDManagerRef))

(define tIOHIDManagerRef (IOHIDManagerCreate kCFAllocatorDefault kIOHIDOptionsTypeNone))

; 4. Find devices to manage.
; Docs
;   Objective-C
;     void IOHIDManagerSetDeviceMatching ( IOHIDManagerRef manager, CFDictionaryRef matching );
;   Discussion
;     Matching keys are prefixed by kIOHIDDevice and declared in <IOKit/hid/IOHIDKeys.h>. 
;     Passing a NULL dictionary will result in all devices being enumerated. ...
(define CFDictionaryRef (_cpointer/null 'CFDictionaryRef))

(define-iokit IOHIDManagerSetDeviceMatching
  (_fun IOHIDManagerRef CFDictionaryRef -> _void))

(IOHIDManagerSetDeviceMatching tIOHIDManagerRef #f)

; 5. Open the manager
; Docs
;   Objective-C
;     IOReturn IOHIDManagerOpen ( IOHIDManagerRef manager, IOOptionBits options );
;   Parameters
;     manager : reference to an IOHIDManager
;     options : Option bits to be sent down to the manager and device.
;   Return Value
;     Returns kIOReturnSuccess if successful.
;   Discussion
;     This will open both current and future devices that are enumerated. 
;     To establish an exclusive link use the kIOHIDOptionsTypeSeizeDevice option.

(define IOReturn _int)
(define kIOReturnSuccess 0)
(define-iokit IOHIDManagerOpen
  (_fun IOHIDManagerRef IOOptionBits -> IOReturn))

(define tIOReturn (IOHIDManagerOpen tIOHIDManagerRef kIOHIDOptionsTypeNone))
(unless (equal? tIOReturn kIOReturnSuccess)
  (error 'dualshock4.rkt "Manager didn't open successfully"))

; 6. Obtain the currently enumerated devices
; Docs
;   Objective-C
;     CFSetRef IOHIDManagerCopyDevices ( IOHIDManagerRef manager );
;   Parameters
;     manager : Reference to an IOHIDManager.
;   Return Value
;     CFSetRef containing IOHIDDeviceRefs.

; Notes: 
;   Swift: typealias CFSetRef = CFSet
;   A CFSetRef is a reference to an immutable set obect
(define CFSetRef (_cpointer 'CFSetRef))

(define-iokit IOHIDManagerCopyDevices
  (_fun IOHIDManagerRef -> CFSetRef))

(define device-set (IOHIDManagerCopyDevices tIOHIDManagerRef))

; 7. Get the number of devices returned
; Docs
;   Objective-C
;     CFIndex CFSetGetCount ( CFSetRef theSet );
; Notes
;  An CFIndex is just a long integer:
;    typedef signed long CFIndex;

(define CFIndex _long)
(define-iokit CFSetGetCount
  (_fun CFSetRef -> CFIndex))

(define device-count (CFSetGetCount device-set))


; 8. Get all values
; Docs
;   Objective-C
;     void CFSetGetValues ( CFSetRef theSet, const void **values );
;   

(define IOHIDDeviceRef (_cpointer 'IOHIDDeviceRef))

; allocate an array of pointers to devices
(define tIOHIDDeviceRefs (cast (malloc IOHIDDeviceRef device-count 'eternal)
                               _pointer IOHIDDeviceRef))

(define-iokit CFSetGetValues
  (_fun CFSetRef (_cpointer 'IOHIDDeviceRef) -> _void))

(CFSetGetValues device-set tIOHIDDeviceRefs)


; 9. Get properties

; Docs
;   Objective-C
;     CFTypeRef IOHIDManagerGetProperty ( IOHIDManagerRef manager, CFStringRef key );
;   Parameters
;     key = CFStringRef containing key to be used when querying the manager.
;   Discussion
;     Property keys are prefixed by kIOHIDDevice and declared in <IOKit/hid/IOHIDKeys.h>
;   Notes:
;      Use:  mdfind IOHIDKeys.h | less
;      to the find the file where the keys are defined.

; Some of the keys:

(define kIOHIDTransportKey                  "Transport")
(define kIOHIDVendorIDKey                   "VendorID")
(define kIOHIDVendorIDSourceKey             "VendorIDSource")
(define kIOHIDProductIDKey                  "ProductID")
(define kIOHIDVersionNumberKey              "VersionNumber")
(define kIOHIDManufacturerKey               "Manufacturer")
(define kIOHIDProductKey                    "Product")
(define kIOHIDSerialNumberKey               "SerialNumber")
(define kIOHIDCountryCodeKey                "CountryCode")
(define kIOHIDStandardTypeKey               "StandardType")
(define kIOHIDLocationIDKey                 "LocationID")
(define kIOHIDDeviceUsageKey                "DeviceUsage")
(define kIOHIDDeviceUsagePageKey            "DeviceUsagePage")
(define kIOHIDDeviceUsagePairsKey           "DeviceUsagePairs")
(define kIOHIDPrimaryUsageKey               "PrimaryUsage")
(define kIOHIDPrimaryUsagePageKey           "PrimaryUsagePage")
(define kIOHIDMaxInputReportSizeKey         "MaxInputReportSize")
(define kIOHIDMaxOutputReportSizeKey        "MaxOutputReportSize")
(define kIOHIDMaxFeatureReportSizeKey       "MaxFeatureReportSize")
(define kIOHIDReportIntervalKey             "ReportInterval")
(define kIOHIDSampleIntervalKey             "SampleInterval")
(define kIOHIDRequestTimeoutKey             "RequestTimeout")
(define kIOHIDReportDescriptorKey           "ReportDescriptor")
(define kIOHIDResetKey                      "Reset")
(define kIOHIDKeyboardLanguageKey           "KeyboardLanguage")
(define kIOHIDAltHandlerIdKey               "alt_handler_id")
(define kIOHIDBuiltInKey                    "Built-In")
(define kIOHIDDisplayIntegratedKey          "DisplayIntegrated")
(define kIOHIDProductIDMaskKey              "ProductIDMask")
(define kIOHIDProductIDArrayKey             "ProductIDArray")
(define kIOHIDPowerOnDelayNSKey             "HIDPowerOnDelayNS")
(define kIOHIDCategoryKey                   "Category")
(define kIOHIDMaxResponseLatencyKey         "MaxResponseLatency")

(define kIOHIDTransportUSBValue                 "USB")
(define kIOHIDTransportBluetoothValue           "Bluetooth")
(define kIOHIDTransportBluetoothLowEnergyValue  "BluetoothLowEnergy")
(define kIOHIDTransportAIDBValue                "AIDB")
(define kIOHIDTransportI2CValue                 "I2C")
(define kIOHIDTransportSPIValue                 "SPI")
(define kIOHIDTransportSerialValue              "Serial")
(define kIOHIDTransportIAPValue                 "IAP")
(define kIOHIDTransportAirPlayValue             "AirPlay")
(define kIOHIDTransportSPUValue                 "SPU")

; Reminder:
;   Objective-C
;     CFTypeRef IOHIDManagerGetProperty ( IOHIDManagerRef manager, CFStringRef key );

; Strings are in ffi/unsafe/nsstring:
(require ffi/unsafe/nsstring)
(define CFStringRef _NSString)
; The CFTypeRef is a fancy void:
(define CFTypeRef (_cpointer/null _void))

(define-iokit IOHIDDeviceGetProperty
  (_fun IOHIDDeviceRef CFStringRef -> CFTypeRef))

(define (get-property device key type)
  (define value (IOHIDDeviceGetProperty  device key))
  (and value (cast value CFTypeRef type)))
  

(define CFTypeID _ulong)

(require mred/private/wx/cocoa/utils) ; for CoreFoundation (define-cf)
(define-cf CFGetTypeID (_fun CFTypeRef -> CFTypeID))
(define (get-type-id type-ref) 
  (and type-ref (CFGetTypeID type-ref)))


(define (get-vendor-id device)
  (match (get-property device kIOHIDVendorIDKey CFTypeID)
    [#f #f]
    [p  (>> p 8)]))

(define sony-vendor-id  1356) ; #x54c
(define apple-vendor-id 1452) ; #x5ac

(define (get-product-id device)
  (match (get-property device kIOHIDProductIDKey CFTypeID)
    [#f #f]
    [p  (>> p 8)]))

(define dualshock4-product-id #x5c4)

(define (find-dualshock4)
  (for/or ([i device-count])
    (define dev (ptr-ref tIOHIDDeviceRefs IOHIDDeviceRef i))
    (and (equal? (get-vendor-id  dev)        sony-vendor-id)
         (equal? (get-product-id dev) dualshock4-product-id)
         dev)))



(displayln (list device-count))
(for/list ([i device-count])
  (define dev (ptr-ref tIOHIDDeviceRefs IOHIDDeviceRef i))
  (list i 
        (get-property dev kIOHIDManufacturerKey _NSString)
        (get-vendor-id dev)
        (get-product-id dev)))

(find-dualshock4)


; typedef void ( *IOHIDReportCallback) ( void *context, IOReturn result, void *sender, 
;                   IOHIDReportType type, uint32_t reportID, uint8_t *report, CFIndex reportLength);

(define IOHIDReportType 
  (_enum '(kIOHIDReportTypeInput = 0
           kIOHIDReportTypeOutput
           kIOHIDReportTypeFeature
           kIOHIDReportTypeCount)))

(define _context (_cpointer/null _void))
(define _report  (_cpointer _uint8))
(define _sender  (_cpointer/null _void))
(define _report-id _uint32)

(define IOHIDReportCallback
  (_fun _context IOReturn _sender IOHIDReportType _report-id _report CFIndex
        -> _void))

(define report-size 64)
(define report (cast (malloc _byte report-size 'eternal)
                     _pointer _report))

(define foo 42)
(define (device-report-callback context return sender report-type report-id report report-length)
  (set! foo 'called))
                                
; void IOHIDDeviceRegisterInputReportCallback ( 
;   IOHIDDeviceRef device, uint8_t *report, CFIndex reportLength, 
;   IOHIDReportCallback callback, void *context );

; CFindex = signed long

(define-iokit IOHIDDeviceRegisterInputReportCallback
  (_fun IOHIDDeviceRef _report CFIndex IOHIDReportCallback _context -> _void))

; IOHIDDeviceRegisterInputReportCallback(
;   inIOHIDDeviceRef, report, reportSize, Handle_IOHIDDeviceIOHIDReportCallback, inContext);

(define dualshock4-dev (find-dualshock4))
(when dualshock4-dev
  (IOHIDDeviceRegisterInputReportCallback 
   dualshock4-dev ; device
   report 
   report-size
   device-report-callback
   #f))


   


; PS3SixAxis *context = (PS3SixAxis*)inContext;


; context->hidDeviceRef = inIOHIDDeviceRef;
	
;	CFIndex reportSize = 64;
;	uint8_t *report = malloc(reportSize);
;	IOHIDDeviceRegisterInputReportCallback(inIOHIDDeviceRef, report, reportSize, Handle_IOHIDDeviceIOHIDReportCallback, inContext);
	
;	[context sendDeviceConnected];

; TODO: release device-set

;   CFStringRef IOHIDDevice_GetManufacturer(IOHIDDeviceRef inIOHIDDeviceRef) {
;    assert( IOHIDDeviceGetTypeID() == CFGetTypeID(inIOHIDDeviceRef) );
;    return ( IOHIDDeviceGetProperty( inIOHIDDeviceRef, CFSTR(kIOHIDManufacturerKey) ) );
;} 

