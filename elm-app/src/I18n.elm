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

English is not translated yet: the site declares only Finnish in its
`config.toml`, so English falls back to Finnish until it is.

-}
t : Lang -> MsgKey -> String
t lang key =
    case lang of
        Fi ->
            fi key

        En ->
            fi key


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
