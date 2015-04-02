#lang racket
(require ffi/unsafe) ; for _enum

(provide (all-defined-out))

; From IOKit.framework/Versions/A/Headers/hid/IOHIDUsageTables.h

; /* ******************************************************************************************
;  * HID Usage Tables
;  *
;  * The following constants are from the USB 'HID Usage Tables' specification, revision 1.1rc3
;  * ****************************************************************************************** */

(define kHIDPage_Button #x09)
(define kHIDPage_GenericDesktop #x01)


; /* Usage Pages */
(define IOHIDUsageTable
  (_enum 
 '(kHIDPage_Undefined      = #x00
   kHIDPage_GenericDesktop = #x01
   kHIDPage_Simulation     = #x02
   kHIDPage_VR     = #x03
   kHIDPage_Sport  = #x04
   kHIDPage_Game   = #x05
   ; /* Reserved #x06 */
   ; /* USB Device Class Definition for Human Interface Devices (HID). 
   ; Note: the usage type for all key codes is Selector (Sel). */
   kHIDPage_KeyboardOrKeypad = #x07    
   kHIDPage_LEDs   = #x08
   kHIDPage_Button = #x09
   kHIDPage_Ordinal        = #x0A
   kHIDPage_Telephony      = #x0B
   kHIDPage_Consumer       = #x0C
   kHIDPage_Digitizer      = #x0D
   ; /* Reserved #x0E */
   kHIDPage_PID    = #x0F ; /* USB Physical Interface Device definitions for force feedback and related devices. */
   kHIDPage_Unicode = #x10
   ; /* Reserved #x11 - #x13 */
   kHIDPage_AlphanumericDisplay    = #x14
   ; /* Reserved #x15 - #x7F */
   ; /* Monitor #x80 - #x83   USB Device Class Definition for Monitor Devices */
   ; /* Power #x84 - #x87     USB Device Class Definition for Power Devices */
   kHIDPage_PowerDevice = #x84            ;                /* Power Device Page */
   kHIDPage_BatterySystem = #x85           ;               /* Battery System Page */
   ; /* Reserved #x88 - #x8B */
   kHIDPage_BarCodeScanner = #x8C ; /* (Point of Sale) USB Device Class Definition for Bar Code Scanner Devices */
   kHIDPage_WeighingDevice = #x8D ; /* (Point of Sale) USB Device Class Definition for Weighing Devices */
   kHIDPage_Scale  = #x8D ; /* (Point of Sale) USB Device Class Definition for Scale Devices */
   kHIDPage_MagneticStripeReader = #x8E
   ; /* ReservedPointofSalepages #x8F */
   kHIDPage_CameraControl  = #x90 ;/* USB Device Class Definition for Image Class Devices */
   kHIDPage_Arcade = #x91   ; /* OAAF Definitions for arcade and coinop related Devices */
   ; /* Reserved #x92 - #xFEFF */
   ; /* VendorDefined #xFF00 - #xFFFF */
   kHIDPage_VendorDefinedStart     = #xFF00
   )))

