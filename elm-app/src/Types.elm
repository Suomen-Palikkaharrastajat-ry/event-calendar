module Types exposing
    ( AuthState(..)
    , AuthUser
    , CalendarPage
    , CalendarViewMode(..)
    , Event
    , EventDetailPage
    , EventEditPage
    , EventFormData
    , EventListPage
    , EventState(..)
    , EventsPage
    , Flags
    , FormStatus(..)
    , GeoPoint
    , KmlImportStatus(..)
    , KmlPlacemark
    , Model
    , Msg(..)
    , Page(..)
    , PbList
    , Toast
    , ToastKind(..)
    , emptyEventFormData
    , emptyPbList
    , eventStateFromString
    , eventStateToString
    , getToken
    , isAuthenticated
    )

import Browser
import Browser.Navigation as Nav
import File exposing (File)
import Http
import Json.Decode as Json
import RemoteData exposing (RemoteData)
import Route exposing (Route)
import Time
import Url exposing (Url)



-- FLAGS


type alias Flags =
    { authToken : Maybe String
    , authModel : Maybe String
    , now : Int
    }



-- AUTH


type AuthState
    = NotAuthenticated
    | Authenticated AuthUser


type alias AuthUser =
    { id : String
    , name : String
    , email : String
    , token : String
    }


isAuthenticated : AuthState -> Bool
isAuthenticated authState =
    case authState of
        Authenticated _ ->
            True

        NotAuthenticated ->
            False


getToken : AuthState -> Maybe String
getToken authState =
    case authState of
        Authenticated user ->
            Just user.token

        NotAuthenticated ->
            Nothing



-- DOMAIN TYPES


type alias GeoPoint =
    { lat : Float
    , lon : Float
    }


type EventState
    = Draft
    | Pending
    | Published
    | Deleted


eventStateFromString : String -> Maybe EventState
eventStateFromString s =
    case s of
        "draft" ->
            Just Draft

        "pending" ->
            Just Pending

        "published" ->
            Just Published

        "deleted" ->
            Just Deleted

        _ ->
            Nothing


eventStateToString : EventState -> String
eventStateToString state =
    case state of
        Draft ->
            "draft"

        Pending ->
            "pending"

        Published ->
            "published"

        Deleted ->
            "deleted"


type alias Event =
    { id : String
    , title : String
    , description : Maybe String
    , startDate : String
    , endDate : Maybe String
    , allDay : Bool
    , url : Maybe String
    , location : Maybe String
    , state : EventState
    , image : Maybe String
    , imageDescription : Maybe String
    , point : Maybe GeoPoint
    , created : String
    , updated : String
    }



-- POCKETBASE LIST


type alias PbList a =
    { items : List a
    , totalItems : Int
    , totalPages : Int
    , page : Int
    , perPage : Int
    }



-- FORM DATA


type alias EventFormData =
    { title : String
    , description : String
    , location : String
    , lat : String
    , lon : String
    , geocodingEnabled : Bool
    , url : String
    , startDate : String
    , startTime : String
    , endDate : String
    , endTime : String
    , allDay : Bool
    , state : EventState
    , imageFile : Maybe File
    , imageDescription : String
    , hasExistingImage : Bool
    , existingImageUrl : Maybe String
    , imagePreviewUrl : Maybe String
    }


emptyPbList : PbList a
emptyPbList =
    { items = []
    , totalItems = 0
    , totalPages = 0
    , page = 1
    , perPage = 100
    }


emptyEventFormData : EventFormData
emptyEventFormData =
    { title = ""
    , description = ""
    , location = ""
    , lat = ""
    , lon = ""
    , geocodingEnabled = True
    , url = ""
    , startDate = ""
    , startTime = ""
    , endDate = ""
    , endTime = ""
    , allDay = False
    , state = Draft
    , imageFile = Nothing
    , imageDescription = ""
    , hasExistingImage = False
    , existingImageUrl = Nothing
    , imagePreviewUrl = Nothing
    }



-- FORM STATUS


type FormStatus
    = FormIdle
    | FormSubmitting
    | FormSuccess
    | FormError String


type KmlImportStatus
    = KmlIdle
    | KmlParsing
    | KmlImporting Int Int
    | KmlDone Int
    | KmlError String



-- PAGE MODELS


type alias CalendarPage =
    { events : RemoteData Http.Error (List Event)
    , year : Int
    , month : Int
    , todayYear : Int
    , todayMonth : Int
    , todayDay : Int
    , viewMode : CalendarViewMode
    }


type CalendarViewMode
    = MonthGrid
    | ListView


type alias KmlPlacemark =
    { name : String
    , description : String
    , lat : Maybe Float
    , lon : Maybe Float
    , dateStr : Maybe String
    }


type alias EventsPage =
    { events : RemoteData Http.Error (PbList Event)
    , currentPage : Int
    , form : EventFormData
    , formStatus : FormStatus
    , kmlImportStatus : KmlImportStatus
    , kmlQueue : List KmlPlacemark
    , showNewForm : Bool
    }


type alias EventDetailPage =
    { event : RemoteData Http.Error Event
    , deleteConfirm : Bool
    }


type alias EventEditPage =
    { event : RemoteData Http.Error Event
    , form : EventFormData
    , formStatus : FormStatus
    }


type alias EventListPage =
    { events : RemoteData Http.Error (List Event)
    }



-- TOP-LEVEL PAGE


type Page
    = PageCalendar CalendarPage
    | PageEvents EventsPage
    | PageEventList EventListPage
    | PageEventDetail String EventDetailPage
    | PageEventEdit String EventEditPage
    | PageAuthCallback
    | PageNotFound
    | PageLoading



-- TOASTS


type ToastKind
    = ToastSuccess
    | ToastError
    | ToastInfo


type alias Toast =
    { id : Int
    , message : String
    , kind : ToastKind
    }



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url
    , page : Page
    , authState : AuthState
    , toasts : List Toast
    , nextToastId : Int
    , now : Time.Posix
    }



-- MSG
--
-- Naming convention
-- ─────────────────
-- Page-scoped messages are prefixed with the page name:
--   Calendar*   → CalendarPage
--   Events*     → EventsPage
--   Detail*     → EventDetailPage
--   Edit*       → EventEditPage
--   EventList*  → EventListPage
--
-- App-wide messages have no page prefix:
--   AddToast, DismissToast, Tick, NavigateTo, LoginClicked, LogOut, …
--
-- RemoteData initialisation convention
-- ─────────────────────────────────────
-- Use `NotAsked` when the data is intentionally not yet requested
-- (e.g. EventsPage when the user is not authenticated).
-- Use `Loading` when the request is kicked off immediately on page init.


type
    Msg
    -- Navigation
    = UrlChanged Url
    | LinkClicked Browser.UrlRequest
    | NavigateTo Route
      -- Auth
    | GotOAuthUrl (Result Http.Error String)
    | GotAuthResult (Result Http.Error AuthUser)
    | OAuthPopupResult { token : String, model : String }
    | ReceivedAuthToken (Maybe String)
    | AuthCallbackReceived String String
    | LogOut
    | LoginClicked
      -- Event list page (public)
    | EventListGotEvents (Result Http.Error (List Event))
      -- Calendar page
    | CalendarGotEvents (Result Http.Error (List Event))
    | CalendarSetMonth Int Int
    | CalendarSetView CalendarViewMode
    | CalendarClickEvent String
      -- Events page
    | EventsGotEvents (Result Http.Error (PbList Event))
    | EventsSetPage Int
    | EventsFormFieldChanged String String
    | EventsFormDateChanged String String
    | EventsFormFileSelected File
    | EventsFormToggleAllDay
    | EventsFormToggleGeocode
    | EventsFormGeocode
    | EventsFormGotGeocode (Result Http.Error (Maybe GeoPoint))
    | EventsFormSubmit
    | EventsFormGotSave (Result Http.Error Event)
    | EventsStatusChanged String EventState
    | EventsGotStatusChange (Result Http.Error Event)
    | EventsKmlFileSelected File
    | EventsKmlGotContent String
    | EventsKmlParsed Json.Value
    | EventsKmlImportNext
    | EventsKmlGotImport (Result Http.Error Event)
      -- Event detail page
    | DetailGotEvent (Result Http.Error Event)
    | DetailRequestDelete
    | DetailConfirmDelete
    | DetailGotDelete (Result Http.Error ())
    | DetailKeyPressed String
      -- Event edit page
    | EditGotEvent (Result Http.Error Event)
    | EditFormFieldChanged String String
    | EditFormDateChanged String String
    | EditFormFileSelected File
    | EditFormToggleAllDay
    | EditFormToggleGeocode
    | EditFormGeocode
    | EditFormGotGeocode (Result Http.Error (Maybe GeoPoint))
    | EditFormSubmit
    | EditFormGotSave (Result Http.Error Event)
      -- Maps (via ports)
    | MapMarkerMoved Float Float
    | GotReverseGeocode (Result Http.Error String)
      -- Image preview
    | GotImagePreview String
      -- Toasts
    | AddToast ToastKind String
    | DismissToast Int
      -- Subscriptions
    | Tick Time.Posix
