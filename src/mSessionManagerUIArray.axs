MODULE_NAME='mSessionManagerUIArray'    (
                                            dev dvTP[],
                                            dev vdvObject
                                        )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.UIUtils.axi'

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

constant integer BUTTON_SESSION_END_WARNING_DISMISS     = 1

constant integer BUTTON_SESSION_EXTEND_30_MIN           = 11
constant integer BUTTON_SESSION_EXTEND_1_HOUR           = 12
constant integer BUTTON_SESSION_EXTEND_2_HOUR           = 13
constant integer BUTTON_SESSION_EXTEND[]                =   {
                                                                BUTTON_SESSION_EXTEND_30_MIN,
                                                                BUTTON_SESSION_EXTEND_1_HOUR,
                                                                BUTTON_SESSION_EXTEND_2_HOUR
                                                            }


constant char SESSION_EXTENSION[][NAV_MAX_CHARS]        =   {
                                                                '30m',
                                                                '1h',
                                                                '2h'
                                                            }


(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile char popupName[NAV_MAX_CHARS] = 'Dialogs - SessionEndWarning'


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
    }
}
#END_IF


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
    command: {
        stack_var _NAVSnapiMessage message

        NAVParseSnapiMessage(data.text, message)

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM,
                                                    data.device,
                                                    data.text))

        switch (message.Header) {
            default: {

            }
        }
    }
    string: {
        stack_var _NAVSnapiMessage message

        NAVParseSnapiMessage(data.text, message)

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM,
                                                    data.device,
                                                    data.text))

        switch (message.Header) {
            case 'SESSION': {
                switch (message.Parameter[1]) {
                    case 'END_WARNING': {
                        switch (message.Parameter[2]) {
                            case 'START': {
                                NAVTextArray(dvTP, 1, '0', message.Parameter[3])
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

        NAVCommand(vdvObject, "'SESSION-EXTEND,', SESSION_EXTENSION[extension]")
    }
}


data_event[dvTP] {
    online: {

    }
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

