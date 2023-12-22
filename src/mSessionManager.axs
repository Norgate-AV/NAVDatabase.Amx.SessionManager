MODULE_NAME='mSessionManager'       (
                                        dev vdvObject
                                    )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.DateTimeUtils.axi'

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


constant long TL_SESSION_TICKER = 1
constant long TL_SESSION_END_WARNING_BEEPER = 2

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

struct _SessionDuration {
    _NAVTimespec Timespec
    long Milliseconds
    long Seconds
    char DurationString[NAV_MAX_CHARS]
}


struct _Session {
    _SessionDuration Duration
    _SessionDuration ExtensionDuration
    _NAVTimespec StartTime
    _NAVTimespec EndTime
    long Ticker[1]
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
    return timeline_active(TL_SESSION_TICKER)
}


define_function integer SessionEndWarningIsActive() {
    return timeline_active(TL_SESSION_END_WARNING_BEEPER)
}


define_function long SessionDurationInit(_SessionDuration sessionDuration, char duration[]) {
    stack_var long milliseconds

    milliseconds = GetSessionDurationInMilliseconds(duration)

    if (milliseconds == 0) {
        return milliseconds
    }

    sessionDuration.DurationString = duration
    sessionDuration.Milliseconds = milliseconds
    sessionDuration.Seconds = milliseconds / ONE_SECOND
    sessionDuration.Timespec.Hour = type_cast(sessionDuration.Milliseconds / ONE_HOUR)
    sessionDuration.Timespec.Minute = type_cast((sessionDuration.Milliseconds % ONE_HOUR) / ONE_MINUTE)
    sessionDuration.Timespec.Seconds = type_cast((sessionDuration.Milliseconds % ONE_MINUTE) / ONE_SECOND)

    return milliseconds
}


define_function long NewSessionInit(_Session session, char duration[]) {
    stack_var long result
    stack_var long epoch

    result = SessionDurationInit(session.Duration, duration)
    if (result == 0) {
        return result
    }

    // Get the current timespec
    NAVDateTimeGetTimespecNow(session.StartTime)

    // Get the current epoch
    epoch = NAVDateTimeGetEpoch(session.StartTime)

    // Initialize the end timespec using the current epoch and the session duration
    NAVDateTimeEpochToTimespec(epoch + session.Duration.Seconds, session.EndTime)

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

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: StartNewSession: StartTime: ', NAVDateTimeGetTimestamp(session.StartTime)")
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: StartNewSession: EndTime: ', NAVDateTimeGetTimestamp(session.EndTime)")

    SendSessionEndTime(session)
    NAVTimelineStart(TL_SESSION_TICKER, session.Ticker, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
}


define_function ExtendSession(_Session session, char duration[]) {
    if (!SessionIsActive()) {
        return
    }

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

    // EditSession(session, duration)

    // session.Extend = true
    // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: ExtendSession: Session Extended "', duration, '"'")

    DismissSessionEndWarning()
}


define_function EditSession(_Session session, long epoch) {
    if (!SessionIsActive()) {
        return
    }

    NAVDateTimeEpochToTimespec(epoch, session.EndTime)
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: EditSession: EndTime: ', NAVDateTimeGetTimestamp(session.EndTime)")

    SendSessionEndTime(session)
}


define_function SendSessionEndTime(_Session session) {
    send_string vdvObject, "'SESSION-END_TIME,STRING,', GetSessionEndTime(session)"
    send_string vdvObject, "'SESSION-END_TIME,EPOCH,', itoa(NAVDateTimeGetEpoch(session.EndTime))"
}


define_function EndSession() {
    DismissSessionEndWarning()
    send_string vdvObject, "'SESSION-END'"
    NAVTimelineStop(TL_SESSION_TICKER)
}


define_function EndSessionEarly() {
    if (!SessionIsActive()) {
        return
    }

    NAVTimelineStop(TL_SESSION_TICKER)
}


define_function char[NAV_MAX_CHARS] GetSessionEndTime(_Session session) {
    return "format('%02d', session.EndTime.Hour), ':', format('%02d', session.EndTime.Minute)"
}


define_function char[NAV_MAX_CHARS] GetSessionStartTime(_Session session) {
    return "format('%02d', session.StartTime.Hour), ':', format('%02d', session.StartTime.Minute)"
}


define_function char[NAV_MAX_CHARS] GetSessionTimeRemainingString(_NAVTimespec timeRemaining) {
    return "format('%02d', timeRemaining.Hour), ':', format('%02d', timeRemaining.Minute), ':', format('%02d', timeRemaining.Seconds)"
}


define_function char[NAV_MAX_CHARS] GetSessionDuration(_Session session) {
    return session.Duration.DurationString
}


define_function GetSessionTimeRemaining(_Session session, _NAVTimespec result) {
    stack_var long now
    stack_var long end
    stack_var long remaining

    now = NAVDateTimeGetEpochNow()
    end = NAVDateTimeGetEpoch(session.EndTime)

    remaining = end - now

    NAVDateTimeEpochToTimespec(remaining, result)
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


define_function SessionTickerInit(_Session session, long interval) {
    session.Ticker[1] = interval
    set_length_array(session.Ticker, 1)
}


#IF_DEFINED USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
define_function NAVModulePropertyEventCallback(_NAVModulePropertyEvent event) {
    switch (event.Name) {
        case 'DEFAULT_SESSION_DURATION': {
            SetDefaultSessionDuration(session, event.Args[1])
        }
    }
}
#END_IF


define_function long GetSeconds(_NAVTimespec timespec) {
    return (timespec.Hour * NAV_DATETIME_SECONDS_IN_1_HOUR) + (timespec.Minute * NAV_DATETIME_SECONDS_IN_1_MINUTE) + timespec.Seconds
}


define_function SessionTick(ttimeline timeline) {
    stack_var long now
    stack_var long end
    stack_var long warning

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mSessionManager => Session Tick'")

    SendSessionTick(session)

    now = NAVDateTimeGetEpochNow()
    end = NAVDateTimeGetEpoch(session.EndTime)
    warning = end - (NAV_DATETIME_SECONDS_IN_1_MINUTE * SESSION_EVENT_END_WARNING_MINUTES_BEFORE)

    if (now >= warning && !SessionEndWarningIsActive()) {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: Session End Warning'")
        StartSessionEndWarning(session)
    }

    if (now < end) {
        return
    }

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: Session Ended'")
    EndSession()
}


define_function SendSessionTick(_Session session) {
    stack_var _NAVTimespec timeRemaining

    GetSessionTimeRemaining(session, timeRemaining)
    send_string vdvObject, "'SESSION-TICK,STRING,', GetSessionTimeRemainingString(timeRemaining)"
    send_string vdvObject, "'SESSION-TICK,SECONDS,', itoa(GetSeconds(timeRemaining))"
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    SetDefaultSessionDuration(session, DEFAULT_SESSION_DURATION)
    SessionTickerInit(session, ONE_SECOND)
    SetSessionEndWarningBeeperInterval(session, SESSION_END_WARNING_BEEPER_INTERVAL)
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
                    case 'EDIT_END': {
                        switch (message.Parameter[2]) {
                            case 'EPOCH': {
                                EditSession(session, atoi(message.Parameter[3]))
                            }
                        }
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


timeline_event[TL_SESSION_END_WARNING_BEEPER] {
    send_string vdvObject, "'SESSION-END_WARNING,ALERT'"
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'SessionManager: Session End Warning Alert'")
}


timeline_event[TL_SESSION_TICKER] {
    SessionTick(timeline)
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
