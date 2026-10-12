module I18n exposing (MsgKey(..), locale, stateLabel, t)

{-| UI strings per language, keyed by MsgKey, plus event state labels.
-}

import Lang exposing (Lang(..))
import Locale exposing (Locale)
import Types exposing (EventState(..))


type MsgKey
    = NavHome
    | A11yFeedLinks
    | NavEvents
    | CalMonthGrid
    | CalListView
    | CalToday
    | CalNoEvents
    | CalPrev
    | CalNext
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
    | FormManualCoords
    | FormLat
    | FormLon
    | DetailEdit
    | DetailDelete
    | DetailDeleteConfirm
    | DetailDeleteCancel
    | DetailBack
    | DetailLocation
    | DetailMoreInfo
    | EventListTitle
    | EventListEmpty
    | EventListNewEvent
    | EventListEdit
    | EventListPage
    | EventListOf
    | KmlImport
    | KmlImporting
    | KmlDone
    | KmlError
    | LoginPrompt
    | LoginButton
    | LogoutButton
    | AuthFailed
    | ContactEmail
    | FeedIcal
    | FeedHtml
    | FeedRss
    | FeedAtom
    | FeedJson
    | FeedGeoJson
    | ErrorNetwork
    | ErrorNotFound
    | ErrorUnknown
    | Loading
    | Saving
    | GeocodingSearching
    | GeocodingNotFound
    | GeocodingError
    | SaveSuccess
    | DeleteSuccess
    | ImportSuccess
    | SubmitByEmailText
    | SubmitByEmailLinkText
    | Retry
    | DateAtTime
    | LoggedInAs
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
    | PageSigningIn
    | PageNotFoundText
    | BackToCalendar
    | TitleLogin
    | TitleUpcoming
    | TitleEvent
    | TitleEditEvent


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

        CalMonthGrid ->
            "Kuukausinäkymä"

        CalListView ->
            "Listanäkymä"

        CalToday ->
            "Tänään"

        CalNoEvents ->
            "Ei tapahtumia tällä kuulla"

        CalPrev ->
            "Edellinen"

        CalNext ->
            "Seuraava"

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

        FormManualCoords ->
            "Syötä koordinaatit käsin"

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

        EventListTitle ->
            "Omat tapahtumat"

        EventListEmpty ->
            "Ei tapahtumia"

        EventListNewEvent ->
            "Luo uusi tapahtuma"

        EventListEdit ->
            "Muokkaa"

        EventListPage ->
            "Sivu"

        EventListOf ->
            "/"

        KmlImport ->
            "Tuo KML-tiedosto"

        KmlImporting ->
            "Tuodaan..."

        KmlDone ->
            "Tuonti valmis"

        KmlError ->
            "Tuontivirhe"

        LoginPrompt ->
            "Etkö ole jäsen? Lähetä tapahtuma sähköpostilla."

        LoginButton ->
            "Kirjaudu sisään"

        LogoutButton ->
            "Kirjaudu ulos"

        AuthFailed ->
            "Kirjautuminen epäonnistui"

        ContactEmail ->
            "palikkaharrastajatry@outlook.com"

        FeedIcal ->
            "iCalendar-syöte"

        FeedHtml ->
            "Tulostettava versio"

        FeedRss ->
            "RSS-syöte"

        FeedAtom ->
            "Atom-syöte"

        FeedJson ->
            "JSON-syöte"

        FeedGeoJson ->
            "GeoJSON"

        ErrorNetwork ->
            "Verkkovirhe"

        ErrorNotFound ->
            "Tapahtumaa ei löydy"

        ErrorUnknown ->
            "Tuntematon virhe"

        Loading ->
            "Ladataan..."

        Saving ->
            "Tallennetaan..."

        GeocodingSearching ->
            "Haetaan sijaintia..."

        GeocodingNotFound ->
            "Sijaintia ei löydy"

        GeocodingError ->
            "Geokoodausvirhe"

        SaveSuccess ->
            "Tapahtuma tallennettu"

        DeleteSuccess ->
            "Tapahtuma poistettu"

        ImportSuccess ->
            "tapahtumat tuotu"

        SubmitByEmailText ->
            "Jos et ole Suomen Palikkaharrastajat ry:n jäsen,"

        SubmitByEmailLinkText ->
            "lähetä tapahtumasi meille sähköpostilla."

        Retry ->
            "Yritä uudelleen"

        DateAtTime ->
            " klo "

        LoggedInAs ->
            "Kirjautunut: "

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

        PageSigningIn ->
            "Kirjaudutaan..."

        PageNotFoundText ->
            "Sivua ei löydy"

        BackToCalendar ->
            "Takaisin kalenteriin"

        TitleLogin ->
            "Kirjautuminen"

        TitleUpcoming ->
            "Tulevat tapahtumat"

        TitleEvent ->
            "Tapahtuma"

        TitleEditEvent ->
            "Muokkaa tapahtumaa"


en : MsgKey -> String
en key =
    case key of
        NavHome ->
            "Calendar"

        A11yFeedLinks ->
            "Subscribe to or export the calendar"

        NavEvents ->
            "Upcoming events"

        CalMonthGrid ->
            "Month view"

        CalListView ->
            "List view"

        CalToday ->
            "Today"

        CalNoEvents ->
            "No events this month"

        CalPrev ->
            "Previous"

        CalNext ->
            "Next"

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

        FormManualCoords ->
            "Enter coordinates manually"

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

        EventListTitle ->
            "My events"

        EventListEmpty ->
            "No events"

        EventListNewEvent ->
            "Create a new event"

        EventListEdit ->
            "Edit"

        EventListPage ->
            "Page"

        EventListOf ->
            "/"

        KmlImport ->
            "Import a KML file"

        KmlImporting ->
            "Importing..."

        KmlDone ->
            "Import finished"

        KmlError ->
            "Import error"

        LoginPrompt ->
            "Not a member? Send your event by email."

        LoginButton ->
            "Sign in"

        LogoutButton ->
            "Sign out"

        AuthFailed ->
            "Sign-in failed"

        ContactEmail ->
            "palikkaharrastajatry@outlook.com"

        FeedIcal ->
            "iCalendar feed"

        FeedHtml ->
            "Printable version"

        FeedRss ->
            "RSS feed"

        FeedAtom ->
            "Atom feed"

        FeedJson ->
            "JSON feed"

        FeedGeoJson ->
            "GeoJSON"

        ErrorNetwork ->
            "Network error"

        ErrorNotFound ->
            "Event not found"

        ErrorUnknown ->
            "Unknown error"

        Loading ->
            "Loading..."

        Saving ->
            "Saving..."

        GeocodingSearching ->
            "Looking up the location..."

        GeocodingNotFound ->
            "Location not found"

        GeocodingError ->
            "Geocoding error"

        SaveSuccess ->
            "Event saved"

        DeleteSuccess ->
            "Event deleted"

        ImportSuccess ->
            "events imported"

        SubmitByEmailText ->
            "If you are not a member of Suomen Palikkaharrastajat ry,"

        SubmitByEmailLinkText ->
            "send us your event by email."

        Retry ->
            "Try again"

        DateAtTime ->
            " at "

        LoggedInAs ->
            "Signed in: "

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

        PageSigningIn ->
            "Signing in..."

        PageNotFoundText ->
            "Page not found"

        BackToCalendar ->
            "Back to the calendar"

        TitleLogin ->
            "Sign in"

        TitleUpcoming ->
            "Upcoming events"

        TitleEvent ->
            "Event"

        TitleEditEvent ->
            "Edit event"


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
