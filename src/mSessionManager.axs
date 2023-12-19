MODULE_NAME='mSessionManager'       (
                                        dev vdvObject
                                    )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#include 'NAVFoundation.ModuleBase.axi'

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

constant char DEFAULT_SESSION_DURATION[] = '2h'

constant long TL_SESSION_TIMER = 1
constant long TL_SESSION_END_WARNING_BEEPER = 2

constant integer NUMBER_OF_EVENTS = 2
constant integer SESSION_EVENT_END_WARNING = 1
constant integer SESSION_EVENT_END = 2

constant integer SESSION_EVENT_END_WARNING_MINUTES_BEFORE = 5

constant long ONE_HOUR = 3600000
constant long ONE_MINUTE = 60000
constant long ONE_SECOND = 1000

constant integer NUMBER_OF_INTERVALS = 1
constant long SESSION_END_WARNING_BEEPER_INTERVAL = (ONE_SECOND * 30)

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

struct _SessionTime {
    sinteger Hour
    sinteger Minute
}


struct _SessionDuration {
    integer Hours
    integer Minutes
    integer Seconds
    long Milliseconds
    char DurationString[NAV_MAX_CHARS]
}


struct _Session {
    _SessionDuration Duration
    _SessionDuration ExtensionDuration
    _SessionTime StartTime
    _SessionTime EndTime
    long Event[NUMBER_OF_EVENTS]
    integer Extend
    char DefaultDuration[NAV_MAX_CHARS]
    long EndWarningBeeperInterval[NUMBER_OF_INTERVALS]
}


(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile _Session session


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

define_function integer SessionIsActive() {
    return timeline_active(TL_SESSION_TIMER)
}


define_function integer SessionEndWarningIsActive() {
    return timeline_active(TL_SESSION_END_WARNING_BEEPER)
}


define_function integer SessionEventsAreInitialized(_Session session) {
    return (session.Event[SESSION_EVENT_END] != 0 && session.Event[SESSION_EVENT_END_WARNING] != 0)
}


define_function long SessionDurationInit(_SessionDuration sessionDuration, char duration[]) {
    stack_var long milliseconds

    milliseconds = GetSessionDurationInMilliseconds(duration)

    if (milliseconds == 0) {
        return milliseconds
    }

    sessionDuration.DurationString = duration
    sessionDuration.Milliseconds = milliseconds
    sessionDuration.Hours = type_cast(sessionDuration.Milliseconds / ONE_HOUR)
    sessionDuration.Minutes = type_cast((sessionDuration.Milliseconds % ONE_HOUR) / ONE_MINUTE)
    sessionDuration.Seconds = type_cast((sessionDuration.Milliseconds % ONE_MINUTE) / ONE_SECOND)

    return milliseconds
}


define_function long NewSessionInit(_Session session, char duration[]) {
    stack_var long result

    result = SessionDurationInit(session.Duration, duration)
    if (result == 0) {
        return result
    }

    session.StartTime.Hour = time_to_hour(time)
    session.StartTime.Minute = time_to_minute(time)

    session.EndTime.Hour = (session.StartTime.Hour + type_cast(session.Duration.Hours)) % 24
    session.EndTime.Minute = (session.StartTime.Minute + type_cast(session.Duration.Minutes)) % 60

    session.Event[SESSION_EVENT_END_WARNING] = session.Duration.Milliseconds - (SESSION_EVENT_END_WARNING_MINUTES_BEFORE * ONE_MINUTE)
    session.Event[SESSION_EVENT_END] = session.Duration.Milliseconds

    session.Extend = false

    return result
}


define_function StartNewSession(_Session session, char duration[]) {
    if (SessionIsActive()) {
        return
    }

    if (!length_array(duration)) {
        duration = session.DefaultDuration
    }

    if (NewSessionInit(session, duration) == 0) {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: StartNewSession: Unable to start new session. Invalid duration: "', duration, '"'")
        return
    }

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: StartNewSession: EndTime: "', itoa(session.EndTime.Hour), ':', itoa(session.EndTime.Minute), '"'")
    NAVTimelineStart(TL_SESSION_TIMER, session.Event, TIMELINE_ABSOLUTE, TIMELINE_ONCE)
}


define_function ExtendSession(_Session session, char duration[]) {
    // if (!SessionIsActive()) {
    //     return
    // }

    if (!length_array(duration)) {
        duration = session.DefaultDuration
    }

    // if (!length_array(duration)) {
    //     duration = session.DefaultDuration
    // }

    // if (SessionDurationInit(session.ExtensionDuration, duration) == 0) {
    //     NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: ExtendSession: Unable to extend session. Invalid duration: "', duration, '"'")
    //     return
    // }

    EditSession(session, duration)

    // session.Extend = true
    // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: ExtendSession: Session Extended "', duration, '"'")

    DismissSessionEndWarning()
}


define_function EditSession(_Session session, char duration[]) {
    stack_var _SessionDuration sessionDuration

    if (!SessionIsActive()) {
        return
    }

    if (!length_array(duration)) {
        duration = session.DefaultDuration
    }

    if (SessionDurationInit(sessionDuration, duration) == 0) {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: EditSession: Invalid duration: "', duration, '"'")
        return
    }

    session.EndTime.Hour = session.EndTime.Hour + type_cast(sessionDuration.Hours)
    session.EndTime.Minute = session.EndTime.Minute + type_cast(sessionDuration.Minutes)

    session.Event[SESSION_EVENT_END_WARNING] = session.Event[SESSION_EVENT_END_WARNING] + sessionDuration.Milliseconds
    session.Event[SESSION_EVENT_END] = session.Event[SESSION_EVENT_END] + sessionDuration.Milliseconds

    // session.Extend = false
    NAVTimelineReload(TL_SESSION_TIMER, session.Event)
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: EditSession: EndTime: "', itoa(session.EndTime.Hour), ':', itoa(session.EndTime.Minute), '"'")
}


define_function EndSession() {
    DismissSessionEndWarning()
    send_string vdvObject, "'SESSION-END'"
}


define_function EndSessionEarly() {
    if (!SessionIsActive()) {
        return
    }

    NAVTimelineStop(TL_SESSION_TIMER)
}


define_function char[NAV_MAX_CHARS] GetSessionEndTime(_Session session) {
    return "format('%02d', session.EndTime.Hour), ':', format('%02d', session.EndTime.Minute)"
}


define_function char[NAV_MAX_CHARS] GetSessionStartTime(_Session session) {
    return "format('%02d', session.StartTime.Hour), ':', format('%02d', session.StartTime.Minute)"
}


define_function char[NAV_MAX_CHARS] GetSessionDuration(_Session session) {
    return session.Duration.DurationString
}


define_function StartSessionEndWarning(_Session session) {
    if (!SessionIsActive()) {
        return
    }

    send_string vdvObject, "'SESSION-END_WARNING,START,', GetSessionEndTime(session)"
    send_string vdvObject, "'SESSION-END_WARNING,ALERT'"

    NAVTimelineStart(TL_SESSION_END_WARNING_BEEPER, session.EndWarningBeeperInterval, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
}


define_function DismissSessionEndWarning() {
    if (!SessionEndWarningIsActive()) {
        return
    }

    send_string vdvObject, "'SESSION-END_WARNING,DISMISS'"

    NAVTimelineStop(TL_SESSION_END_WARNING_BEEPER)
}


define_function long GetSessionDurationInMilliseconds(char duration[]) {
    stack_var char durationFormat[1]
    stack_var char durationTime[NAV_MAX_CHARS]
    stack_var long result

    result = 0

    durationFormat = lower_string(right_string(duration, 1))
    durationTime = NAVStripCharsFromRight(duration, 1)

    switch (durationFormat) {
        case 'h': {
            result = atoi(durationTime) * ONE_HOUR
        }
        case 'm': {
            result = atoi(durationTime) * ONE_MINUTE
        }
        default: {
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: Invalid session time format: "', durationFormat, '"'")
        }
    }

    return result
}


define_function SetDefaultSessionDuration(_Session session, char duration[]) {
    if (!GetSessionDurationInMilliseconds(duration)) {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: Failed to set default session duration => Invalid duration: "', duration, '"'")
        return
    }

    session.DefaultDuration = duration
}


define_function SetSessionEndWarningBeeperInterval(_Session session, long interval) {
    session.EndWarningBeeperInterval[1] = interval
    set_length_array(session.EndWarningBeeperInterval, NUMBER_OF_INTERVALS)
}


define_function SessionEventsInit(_Session session) {
    session.Event[SESSION_EVENT_END_WARNING] = 0
    session.Event[SESSION_EVENT_END] = 0
    set_length_array(session.Event, NUMBER_OF_EVENTS)
}


#IF_DEFINED USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
define_function NAVModulePropertyEventCallback(_NAVModulePropertyEvent event) {
    switch (event.Name) {
        case 'DEFAULT_SESSION_DURATION': {
            SetDefaultSessionDuration(session,  event.Args[1])
        }
    }
}
#END_IF


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    SetDefaultSessionDuration(session, DEFAULT_SESSION_DURATION)
    SetSessionEndWarningBeeperInterval(session, SESSION_END_WARNING_BEEPER_INTERVAL)
    SessionEventsInit(session)
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
            case 'SESSION': {
                switch (message.Parameter[1]) {
                    case 'START': {
                        stack_var char duration[NAV_MAX_CHARS]

                        duration = message.Parameter[2]

                        StartNewSession(session, duration)
                    }
                    case 'EDIT': {
                        stack_var char duration[NAV_MAX_CHARS]

                        duration = message.Parameter[2]

                        EditSession(session, duration)
                    }
                    case 'EXTEND': {
                        stack_var char duration[NAV_MAX_CHARS]

                        duration = message.Parameter[2]

                        ExtendSession(session, duration)
                    }
                    case 'END_EARLY': {
                        EndSessionEarly()
                    }
                    case 'END_WARNING_DISMISS': {
                        DismissSessionEndWarning()
                    }
                }
            }
        }
    }
}


timeline_event[TL_SESSION_TIMER] {
    switch (timeline.sequence) {
        case SESSION_EVENT_END_WARNING: {
            StartSessionEndWarning(session)
        }
        case SESSION_EVENT_END: {
            EndSession()
        }
    }
}


timeline_event[TL_SESSION_END_WARNING_BEEPER] {
    send_string vdvObject, "'SESSION-END_WARNING,ALERT'"
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: Session End Warning Alert'")
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
