module I18n exposing (MsgKey(..), contentAttrs, dayLabel, importedCount, kmlDone, locale, stateLabel, submitEventMailto, t)

{-| UI strings per language, keyed by MsgKey, plus event state labels.
-}

import Html
import Lang exposing (Lang(..))
import Locale exposing (Locale)
import Types exposing (EventState(..))
import Url


type MsgKey
    = NavHome
    | A11yFeedLinks
    | NavEvents
    | CalToday
    | CalNoEvents
    | StateDraft
    | StatePending
    | StatePublished
    | StateDeleted
    | FormEditTitle
    | FormTitle
    | FormLocation
    | FormDescription
    | FormUrl
    | FormImage
    | FormImageAlt
    | FormStartDate
    | FormStartTime
    | FormEndDate
    | FormEndTime
    | FormAllDay
    | FormCancelled
    | FormStatus
    | FormTag
    | TagNone
    | TagExhibition
    | TagEvent
    | TagCompetition
    | FormSave
    | FormCancel
    | FormGeocode
    | FormLat
    | FormLon
    | DetailEdit
    | DetailDelete
    | DetailDeleteConfirm
    | DetailDeleteCancel
    | DetailBack
    | DetailLocation
    | DetailMoreInfo
    | EventListEmpty
    | EventListNewEvent
    | EventListEdit
    | EventListPage
    | KmlImport
    | KmlImporting
    | KmlError
    | Loading
    | Saving
    | SubmitByEmailText
    | SubmitByEmailLinkText
    | Retry
    | DateAtTime
    | FeedIcalDescription
    | FeedHtmlDescription
    | FeedsTitle
    | FeedsDescription
    | CalMore
    | CalPrevMonth
    | CalNextMonth
    | CalWeek
    | ListShowOnMap
    | ListOpenWebsite
    | FormCurrentImage
    | ErrBadUrl
    | ErrTimeout
    | ErrNetwork
    | ErrBadStatus
    | ErrBadBody
    | LoginRequired
    | LoginSuccess
    | LoginFailed
    | EventSaved
    | EventDeleted
    | DetailDeleteQuestion
    | PageLoadingText
    | PageNotFoundText
    | BackToCalendar
    | TitleUpcoming
    | TitleEvent
    | TitleEditEvent
    | CancelledPrefix


{-| The text of a key in a language.
-}
t : Lang -> MsgKey -> String
t lang key =
    case lang of
        Fi ->
            fi key

        En ->
            en key


fi : MsgKey -> String
fi key =
    case key of
        NavHome ->
            "Kalenteri"

        A11yFeedLinks ->
            "Tilaa tai vie kalenteri"

        NavEvents ->
            "Tulevat tapahtumat"

        CalToday ->
            "Tänään"

        CalNoEvents ->
            "Ei tapahtumia tällä kuulla"

        StateDraft ->
            "Luonnos"

        StatePending ->
            "Odottaa"

        StatePublished ->
            "Julkaistu"

        StateDeleted ->
            "Poistettu"

        FormEditTitle ->
            "Muokkaa tapahtumaa"

        FormTitle ->
            "Tapahtuman nimi"

        FormLocation ->
            "Sijainti"

        FormDescription ->
            "Kuvaus"

        FormUrl ->
            "Verkkosivu"

        FormImage ->
            "Kuva"

        FormImageAlt ->
            "Kuvan vaihtoehtoinen teksti"

        FormStartDate ->
            "Alkamispäivä"

        FormStartTime ->
            "Alkamisaika"

        FormEndDate ->
            "Päättymispäivä"

        FormEndTime ->
            "Päättymisaika"

        FormAllDay ->
            "Koko päivän tapahtuma"

        FormCancelled ->
            "Peruttu"

        FormStatus ->
            "Tila"

        FormTag ->
            "Tunniste"

        TagNone ->
            "Ei mikään"

        TagExhibition ->
            "Näyttely"

        TagEvent ->
            "Tapahtuma"

        TagCompetition ->
            "Kilpailu"

        FormSave ->
            "Tallenna"

        FormCancel ->
            "Peruuta"

        FormGeocode ->
            "Hae koordinaatit"

        FormLat ->
            "Leveysaste"

        FormLon ->
            "Pituusaste"

        DetailEdit ->
            "Muokkaa"

        DetailDelete ->
            "Poista"

        DetailDeleteConfirm ->
            "Vahvista poisto"

        DetailDeleteCancel ->
            "Peruuta"

        DetailBack ->
            "Takaisin"

        DetailLocation ->
            "Sijainti"

        DetailMoreInfo ->
            "Lisätietoja"

        EventListEmpty ->
            "Ei tapahtumia"

        EventListNewEvent ->
            "Luo uusi tapahtuma"

        EventListEdit ->
            "Muokkaa"

        EventListPage ->
            "Sivu"

        KmlImport ->
            "Tuo KML-tiedosto"

        KmlImporting ->
            "Tuodaan..."

        KmlError ->
            "Tuontivirhe"

        Loading ->
            "Ladataan..."

        Saving ->
            "Tallennetaan..."

        SubmitByEmailText ->
            "Jos et ole Suomen Palikkaharrastajat ry:n jäsen,"

        SubmitByEmailLinkText ->
            "lähetä tapahtumasi meille sähköpostilla."

        Retry ->
            "Yritä uudelleen"

        DateAtTime ->
            " klo "

        FeedIcalDescription ->
            "Kalenterivienti (ICS) tilaa tai integroi koko kalenterin helposti. Klikkaa kalenteri puhelimeesi!"

        FeedHtmlDescription ->
            "Upota tai tulosta valmis tapahtumalistaus. Sisältää kalenterilinkit yksittäisiin tapahtumiin."

        FeedsTitle ->
            "Syötteet"

        FeedsDescription ->
            "Syötteet integroivat uudet tapahtumat verkkosivuille. Nämäkin sisältävät kalenterilinkit."

        CalMore ->
            " lisää"

        CalPrevMonth ->
            "Edellinen kuukausi"

        CalNextMonth ->
            "Seuraava kuukausi"

        CalWeek ->
            "Viikko "

        ListShowOnMap ->
            "Näytä kartalla"

        ListOpenWebsite ->
            "Avaa tapahtuman verkkosivu"

        FormCurrentImage ->
            "Nykyinen kuva"

        ErrBadUrl ->
            "Virheellinen URL: "

        ErrTimeout ->
            "Pyyntö aikakatkaistiin"

        ErrNetwork ->
            "Verkkovirhe"

        ErrBadStatus ->
            "Palvelinvirhe: "

        ErrBadBody ->
            "Vastausvirhe: "

        LoginRequired ->
            "Kirjaudu sisään päästäksesi hallintanäkymään"

        LoginSuccess ->
            "Kirjautuminen onnistui"

        LoginFailed ->
            "Kirjautuminen epäonnistui"

        EventSaved ->
            "Tapahtuma tallennettu"

        EventDeleted ->
            "Tapahtuma poistettu"

        DetailDeleteQuestion ->
            "Poistetaanko tapahtuma?"

        PageLoadingText ->
            "Ladataan..."

        PageNotFoundText ->
            "Sivua ei löydy"

        BackToCalendar ->
            "Takaisin kalenteriin"

        TitleUpcoming ->
            "Tulevat tapahtumat"

        TitleEvent ->
            "Tapahtuma"

        TitleEditEvent ->
            "Muokkaa tapahtumaa"

        CancelledPrefix ->
            "PERUTTU: "


en : MsgKey -> String
en key =
    case key of
        NavHome ->
            "Calendar"

        A11yFeedLinks ->
            "Subscribe to or export the calendar"

        NavEvents ->
            "Upcoming events"

        CalToday ->
            "Today"

        CalNoEvents ->
            "No events this month"

        StateDraft ->
            "Draft"

        StatePending ->
            "Pending"

        StatePublished ->
            "Published"

        StateDeleted ->
            "Deleted"

        FormEditTitle ->
            "Edit event"

        FormTitle ->
            "Event name"

        FormLocation ->
            "Location"

        FormDescription ->
            "Description"

        FormUrl ->
            "Website"

        FormImage ->
            "Image"

        FormImageAlt ->
            "Alternative text for the image"

        FormStartDate ->
            "Start date"

        FormStartTime ->
            "Start time"

        FormEndDate ->
            "End date"

        FormEndTime ->
            "End time"

        FormAllDay ->
            "All-day event"

        FormCancelled ->
            "Cancelled"

        FormStatus ->
            "Status"

        FormTag ->
            "Tag"

        TagNone ->
            "None"

        TagExhibition ->
            "Exhibition"

        TagEvent ->
            "Event"

        TagCompetition ->
            "Competition"

        FormSave ->
            "Save"

        FormCancel ->
            "Cancel"

        FormGeocode ->
            "Look up coordinates"

        FormLat ->
            "Latitude"

        FormLon ->
            "Longitude"

        DetailEdit ->
            "Edit"

        DetailDelete ->
            "Delete"

        DetailDeleteConfirm ->
            "Confirm deletion"

        DetailDeleteCancel ->
            "Cancel"

        DetailBack ->
            "Back"

        DetailLocation ->
            "Location"

        DetailMoreInfo ->
            "More information"

        EventListEmpty ->
            "No events"

        EventListNewEvent ->
            "Create a new event"

        EventListEdit ->
            "Edit"

        EventListPage ->
            "Page"

        KmlImport ->
            "Import a KML file"

        KmlImporting ->
            "Importing..."

        KmlError ->
            "Import error"

        Loading ->
            "Loading..."

        Saving ->
            "Saving..."

        SubmitByEmailText ->
            "If you are not a member of Suomen Palikkaharrastajat ry,"

        SubmitByEmailLinkText ->
            "send us your event by email."

        Retry ->
            "Try again"

        DateAtTime ->
            " at "

        FeedIcalDescription ->
            "The calendar export (ICS) lets you subscribe to or integrate the whole calendar. Add it to your phone with one click!"

        FeedHtmlDescription ->
            "Embed or print a ready-made event listing. Includes calendar links to the individual events."

        FeedsTitle ->
            "Feeds"

        FeedsDescription ->
            "Feeds bring new events to other websites. They include the calendar links too."

        CalMore ->
            " more"

        CalPrevMonth ->
            "Previous month"

        CalNextMonth ->
            "Next month"

        CalWeek ->
            "Week "

        ListShowOnMap ->
            "Show on map"

        ListOpenWebsite ->
            "Open the event's website"

        FormCurrentImage ->
            "Current image"

        ErrBadUrl ->
            "Invalid URL: "

        ErrTimeout ->
            "The request timed out"

        ErrNetwork ->
            "Network error"

        ErrBadStatus ->
            "Server error: "

        ErrBadBody ->
            "Response error: "

        LoginRequired ->
            "Sign in to manage events"

        LoginSuccess ->
            "Signed in"

        LoginFailed ->
            "Sign-in failed"

        EventSaved ->
            "Event saved"

        EventDeleted ->
            "Event deleted"

        DetailDeleteQuestion ->
            "Delete the event?"

        PageLoadingText ->
            "Loading..."

        PageNotFoundText ->
            "Page not found"

        BackToCalendar ->
            "Back to the calendar"

        TitleUpcoming ->
            "Upcoming events"

        TitleEvent ->
            "Event"

        TitleEditEvent ->
            "Edit event"

        CancelledPrefix ->
            "CANCELLED: "


stateLabel : Lang -> EventState -> String
stateLabel lang state =
    case state of
        Draft ->
            t lang StateDraft

        Pending ->
            t lang StatePending

        Published ->
            t lang StatePublished

        Deleted ->
            t lang StateDeleted


{-| The date and time conventions of a language.
-}
locale : Lang -> Locale
locale lang =
    Locale.forCode (Lang.toString lang)


{-| Accessible name of a calendar day that has events, e.g.
"17. lokakuuta, 2 tapahtumaa" or "17 October, 2 events".
-}
dayLabel : Lang -> { day : Int, month : Int, count : Int } -> String
dayLabel lang { day, month, count } =
    let
        monthName =
            (locale lang).monthName month
    in
    case lang of
        Fi ->
            String.fromInt day
                ++ ". "
                ++ String.toLower monthName
                ++ "ta, "
                ++ String.fromInt count
                ++ (if count == 1 then
                        " tapahtuma"

                    else
                        " tapahtumaa"
                   )

        En ->
            String.fromInt day
                ++ " "
                ++ monthName
                ++ ", "
                ++ String.fromInt count
                ++ (if count == 1 then
                        " event"

                    else
                        " events"
                   )


{-| Status line after a KML import of `count` events.
-}
kmlDone : Lang -> Int -> String
kmlDone lang count =
    case lang of
        Fi ->
            String.fromInt count ++ " Tuonti valmis"

        En ->
            "Import finished: " ++ String.fromInt count


{-| `mailto:` link with which a non-member sends an event to the given
address, with a subject and a body template in the language.
-}
submitEventMailto : Lang -> String -> String
submitEventMailto lang address =
    let
        ( subject, fields ) =
            case lang of
                Fi ->
                    ( "Uusi tapahtuma Palikkakalenteriin"
                    , [ "Tapahtuman nimi:", "Tarkempi kuvaus:", "Paikkakunta:", "Alkaa:", "Päättyy:", "Kotisivut:" ]
                    )

                En ->
                    ( "New event for Palikkakalenteri"
                    , [ "Event name:", "Description:", "Town:", "Starts:", "Ends:", "Website:" ]
                    )
    in
    "mailto:"
        ++ address
        ++ "?subject="
        ++ Url.percentEncode subject
        ++ "&body="
        ++ Url.percentEncode (String.concat (List.map (\field -> field ++ "\u{000D}\n\u{000D}\n") fields))


{-| Message after a KML import of `count` events.
-}
importedCount : Lang -> Int -> String
importedCount lang count =
    case lang of
        Fi ->
            String.fromInt count ++ " tapahtumaa tuotu"

        En ->
            String.fromInt count
                ++ (if count == 1 then
                        " event imported"

                    else
                        " events imported"
                   )


{-| Attributes for content the organisers wrote. Events and places are entered
in Finnish, so inside another interface language they are marked as Finnish for
screen readers.
-}
contentAttrs : Lang -> List (Html.Attribute msg)
contentAttrs lang =
    Lang.attributeFor { interface = lang, content = Fi }
