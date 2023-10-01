MODULE_NAME='mSessionManagerUIArray'    (
                                            dev dvTP[],
                                            dev vdvSessionManager
                                        )

(***********************************************************)
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

volatile char cPopupName[NAV_MAX_CHARS] = 'Dialogs - SessionEndWarning'


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


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {

}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[vdvSessionManager] {
    command: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
        stack_var char cCmdParam[2][NAV_MAX_CHARS]

        NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))

        cCmdHeader = DuetParseCmdHeader(data.text)
        cCmdParam[1] = DuetParseCmdParam(data.text)
        cCmdParam[2] = DuetParseCmdParam(data.text)

        switch (cCmdHeader) {
            case 'PROPERTY': {
                switch (cCmdParam[1]) {
                    case 'POPUP_NAME': {
                        cPopupName = cCmdParam[2]
                    }
                }
            }
        }
    }
    string: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
        stack_var char cCmdParam[3][NAV_MAX_CHARS]

        NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM, data.device, data.text))

        cCmdHeader = DuetParseCmdHeader(data.text)
        cCmdParam[1]    = DuetParseCmdParam(data.text)
        cCmdParam[2]    = DuetParseCmdParam(data.text)
        cCmdParam[3]    = DuetParseCmdParam(data.text)

        switch (cCmdHeader) {
            case 'SESSION': {
                switch (cCmdParam[1]) {
                    case 'END_WARNING': {
                        switch (cCmdParam[2]) {
                            case 'START': {
                                NAVTextArray(dvTP, 1, '0', cCmdParam[3])
                                NAVPopupShowArray(dvTP, cPopupName, '')
                            }
                            case 'DISMISS': {
                                NAVPopupKillArray(dvTP, cPopupName)
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
        NAVCommand(vdvSessionManager, "'SESSION-END_WARNING_DISMISS'")
    }
}


button_event[dvTP, BUTTON_SESSION_EXTEND] {
    push: {
        stack_var integer iExtension

        iExtension = get_last(BUTTON_SESSION_EXTEND)

        NAVCommand(vdvSessionManager, "'SESSION-EXTEND,', SESSION_EXTENSION[iExtension]")
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

