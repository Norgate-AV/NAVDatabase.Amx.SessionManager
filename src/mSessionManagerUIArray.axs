MODULE_NAME='mSessionManagerUIArray'    (
                                            dev dvTP[],
                                            dev vdvObject
                                        )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.UIUtils.axi'
#include 'NAVFoundation.DateTimeUtils.axi'
#include 'NAVFoundation.StringUtils.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant integer TIME_END_ADDRESS               = 1
constant integer TIME_END_HOUR_ADDRESS          = 2
constant integer TIME_END_MINUTE_ADDRESS        = 3
constant integer TIME_REMAINING_ADDRESS         = 4
constant integer TIME_REMAINING_HOUR_ADDRESS    = 5
constant integer TIME_REMAINING_MINUTE_ADDRESS  = 6
constant integer TIME_END_EDIT_HOUR_ADDRESS     = 7
constant integer TIME_END_EDIT_MINUTE_ADDRESS   = 8
constant integer TIME_END_EDIT_LIMIT_ADDRESS    = 9

constant integer BUTTON_SESSION_END_WARNING_DISMISS     = 1

constant integer BUTTON_SESSION_EXTEND_30_MIN           = 11
constant integer BUTTON_SESSION_EXTEND_1_HOUR           = 12
constant integer BUTTON_SESSION_EXTEND_2_HOUR           = 13
constant integer BUTTON_SESSION_EXTEND[]                =   {
                                                                BUTTON_SESSION_EXTEND_30_MIN,
                                                                BUTTON_SESSION_EXTEND_1_HOUR,
                                                                BUTTON_SESSION_EXTEND_2_HOUR
                                                            }


// constant char SESSION_EXTENSION[][NAV_MAX_CHARS]        =   {
//                                                                 '30m',
//                                                                 '1h',
//                                                                 '2h'
//                                                             }

constant long SESSION_EXTENSION[]   =   {
                                            NAV_DATETIME_SECONDS_IN_1_HOUR / 2,
                                            NAV_DATETIME_SECONDS_IN_1_HOUR,
                                            NAV_DATETIME_SECONDS_IN_1_HOUR * 2
                                        }

constant integer BUTTON_SESSION_EDIT_1_HOUR_PLUS        = 21
constant integer BUTTON_SESSION_EDIT_1_HOUR_MINUS       = 22
constant integer BUTTON_SESSION_EDIT_15_MINUTE_PLUS     = 23
constant integer BUTTON_SESSION_EDIT_15_MINUTE_MINUS    = 24
constant integer BUTTON_SESSION_EDIT[]  =   {
                                                BUTTON_SESSION_EDIT_1_HOUR_PLUS,
                                                BUTTON_SESSION_EDIT_1_HOUR_MINUS,
                                                BUTTON_SESSION_EDIT_15_MINUTE_PLUS,
                                                BUTTON_SESSION_EDIT_15_MINUTE_MINUS
                                            }

constant integer BUTTON_SESSION_EDIT_APPLY              = 31
constant integer BUTTON_SESSION_EDIT_CANCEL             = 32

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile char popupName[NAV_MAX_CHARS] = 'Dialogs - SessionEndWarning'

volatile long endEpoch
volatile _NAVTimespec endTimespec

volatile long remainingSeconds

volatile long endEditEpoch

volatile char endEditLimit[NAV_MAX_CHARS] = '22:00'
volatile long endEditLimitEpoch

(***********************************************************)
(*               BUTTON DEFINITIONS GO BELOW              *)
(***********************************************************)

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

#IF_DEFINED USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
define_function NAVModulePropertyEventCallback(_NAVModulePropertyEvent event) {
    switch (event.Name) {
        case 'POPUP_NAME': {
            popupName = event.Args[1]
        }
        case 'SESSION_EDIT_LIMIT': {
            endEditLimit = event.Args[1]
            InitializeEndTimeEditLimit(endEditLimit)
        }
    }
}
#END_IF


define_function UpdateSessionTimeEndEdit(long epoch) {
    stack_var _NAVTimespec timespec

    if (epoch < endEpoch) {
        epoch = endEpoch
    }

    if (epoch > endEditLimitEpoch) {
        epoch = endEditLimitEpoch
    }

    endEditEpoch = epoch

    NAVDateTimeEpochToTimespec(epoch, timespec)

    NAVTextArray(dvTP, TIME_END_EDIT_HOUR_ADDRESS, '0', "format('%02d', timespec.Hour)")
    NAVTextArray(dvTP, TIME_END_EDIT_MINUTE_ADDRESS, '0', "format('%02d', timespec.Minute)")

    NAVEnableButtonArray(dvTP, BUTTON_SESSION_EDIT_APPLY, (epoch > endEpoch))

    NAVEnableButtonArray(dvTP, BUTTON_SESSION_EDIT_1_HOUR_PLUS, (epoch != endEditLimitEpoch))
    NAVEnableButtonArray(dvTP, BUTTON_SESSION_EDIT_1_HOUR_MINUS, ((epoch - endEpoch) >= NAV_DATETIME_SECONDS_IN_1_HOUR))
    NAVEnableButtonArray(dvTP, BUTTON_SESSION_EDIT_15_MINUTE_PLUS, (epoch != endEditLimitEpoch))
    NAVEnableButtonArray(dvTP, BUTTON_SESSION_EDIT_15_MINUTE_MINUS, ((epoch - endEpoch) >= (NAV_DATETIME_SECONDS_IN_1_MINUTE * 15)))
}


define_function UpdateSessionTimeEnd(long epoch) {
    endEpoch = epoch
    NAVDateTimeEpochToTimespec(epoch, endTimespec)

    NAVTextArray(dvTP, TIME_END_ADDRESS, '0', "format('%02d', endTimespec.Hour), ':', format('%02d', endTimespec.Minute)")
    NAVTextArray(dvTP, TIME_END_HOUR_ADDRESS, '0', "format('%02d', endTimespec.Hour)")
    NAVTextArray(dvTP, TIME_END_MINUTE_ADDRESS, '0', "format('%02d', endTimespec.Minute)")

    UpdateSessionTimeEndEdit(epoch)
}


define_function UpdateSessionTimeRemaining(long seconds) {
    stack_var _NAVTimespec timespec

    remainingSeconds = seconds

    timespec.Hour = type_cast(seconds / NAV_DATETIME_SECONDS_IN_1_HOUR)
    timespec.Minute = type_cast((seconds % NAV_DATETIME_SECONDS_IN_1_HOUR) / NAV_DATETIME_SECONDS_IN_1_MINUTE)
    timespec.Seconds = type_cast(seconds % NAV_DATETIME_SECONDS_IN_1_MINUTE)

    NAVTextArray(dvTP, TIME_REMAINING_ADDRESS, '0', "itoa(timespec.Hour), ' hr, ', format('%02d', timespec.Minute), ' min'")
    NAVTextArray(dvTP, TIME_REMAINING_HOUR_ADDRESS, '0', "format('%02d', timespec.Hour)")
    NAVTextArray(dvTP, TIME_REMAINING_MINUTE_ADDRESS, '0', "format('%02d', timespec.Minute)")
}


define_function SessionEditApply(long epoch) {
    NAVPopupKillArray(dvTP, popupName)
    NAVCommand(vdvObject, "'SESSION-EDIT_END,EPOCH,', itoa(epoch)")
}


define_function SessionEditCancel() {
    NAVPopupKillArray(dvTP, popupName)
    UpdateSessionTimeEndEdit(endEpoch)
}


define_function UpdateSessionEndEditLimit(char limit[]) {
    NAVTextArray(dvTP, TIME_END_EDIT_LIMIT_ADDRESS, '0', limit)
}


define_function long GetSessionEndEditLimitEpoch(char limit[]) {
    stack_var _NAVTimespec timespec
    stack_var char timeSegment[3][2]

    NAVDateTimeGetTimespecNow(timespec)

    NAVSplitString(limit, ':', timeSegment)

    timespec.Hour = atoi(timeSegment[1])
    timespec.Minute = atoi(timeSegment[2])
    timespec.Seconds = 0

    return NAVDateTimeGetEpoch(timespec)
}


define_function InitializeEndTimeEditLimit(char limit[]) {
    endEditLimitEpoch = GetSessionEndEditLimitEpoch(limit)
    UpdateSessionEndEditLimit(limit)
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {

}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[vdvObject] {
    string: {
        stack_var _NAVSnapiMessage message

        NAVParseSnapiMessage(data.text, message)

        switch (message.Header) {
            case 'SESSION': {
                switch (message.Parameter[1]) {
                    case 'START': {
                        InitializeEndTimeEditLimit(endEditLimit)
                    }
                    case 'END_WARNING': {
                        switch (message.Parameter[2]) {
                            case 'START': {
                                NAVTextArray(dvTP, TIME_END_ADDRESS, '0', message.Parameter[3])
                                NAVPopupShowArray(dvTP, popupName, '')
                            }
                            case 'DISMISS': {
                                NAVPopupKillArray(dvTP, popupName)
                            }
                            case 'ALERT': {
                                NAVDoubleBeepArray(dvTP)
                            }
                        }
                    }
                    case 'END_TIME': {
                        switch (message.Parameter[2]) {
                            case 'STRING': {}
                            case 'EPOCH': {
                                UpdateSessionTimeEnd(atoi(message.Parameter[3]))
                            }
                        }
                    }
                    case 'TICK': {
                        switch (message.Parameter[2]) {
                            case 'STRING': {}
                            case 'SECONDS': {
                                UpdateSessionTimeRemaining(atoi(message.Parameter[3]))
                            }
                        }
                    }
                }
            }
        }
    }
}


button_event[dvTP, BUTTON_SESSION_END_WARNING_DISMISS] {
    push: {
        NAVCommand(vdvObject, "'SESSION-END_WARNING_DISMISS'")
    }
}


button_event[dvTP, BUTTON_SESSION_EXTEND] {
    push: {
        stack_var integer extension

        extension = get_last(BUTTON_SESSION_EXTEND)

        NAVCommand(vdvObject, "'SESSION-EDIT_END,EPOCH,', itoa(endEpoch + SESSION_EXTENSION[extension])")
    }
}


data_event[dvTP] {
    online: {
        UpdateSessionTimeEnd(endEpoch)
        UpdateSessionTimeRemaining(remainingSeconds)
        UpdateSessionEndEditLimit(endEditLimit)
    }
}


button_event[dvTP, BUTTON_SESSION_EDIT] {
    push: {
        stack_var long epoch

        switch (button.input.channel) {
            case BUTTON_SESSION_EDIT_1_HOUR_PLUS: {
                epoch = endEditEpoch + NAV_DATETIME_SECONDS_IN_1_HOUR
            }
            case BUTTON_SESSION_EDIT_1_HOUR_MINUS: {
                epoch = endEditEpoch - NAV_DATETIME_SECONDS_IN_1_HOUR
            }
            case BUTTON_SESSION_EDIT_15_MINUTE_PLUS: {
                // Add 15 minutes to the epoch but round up to the nearest 15 minutes
                epoch = endEditEpoch + (NAV_DATETIME_SECONDS_IN_1_MINUTE * 15)
                // epoch = epoch - (epoch % (NAV_DATETIME_SECONDS_IN_1_MINUTE * 15))
            }
            case BUTTON_SESSION_EDIT_15_MINUTE_MINUS: {
                // Subtract 15 minutes from the epoch but round down to the nearest 15 minutes
                epoch = endEditEpoch - (NAV_DATETIME_SECONDS_IN_1_MINUTE * 15)
                // epoch = epoch - (epoch % (NAV_DATETIME_SECONDS_IN_1_MINUTE * 15))
            }
        }

        UpdateSessionTimeEndEdit(epoch)
    }
}


button_event[dvTP, BUTTON_SESSION_EDIT_APPLY] {
    push: {
        SessionEditApply(endEditEpoch)
    }
}


button_event[dvTP, BUTTON_SESSION_EDIT_CANCEL] {
    push: {
        SessionEditCancel()
    }
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

