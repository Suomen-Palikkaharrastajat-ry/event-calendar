module I18n exposing (MsgKey(..), stateLabel, t)

import Types exposing (EventState(..))


type MsgKey
    = AppTitle
    | NavbarTitle
    | NavHome
    | NavEvents
    | NavLogin
    | NavLogout
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
    | FormStatus
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


t : MsgKey -> String
t key =
    case key of
        AppTitle ->
            "Palikkakalenteri | Suomen Palikkaharrastajat ry"

        NavbarTitle ->
            "Palikkakalenteri"

        NavHome ->
            "Kalenteri"

        NavEvents ->
            "Tulevat tapahtumat"

        NavLogin ->
            "Kirjaudu sisään"

        NavLogout ->
            "Kirjaudu ulos"

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

        FormStatus ->
            "Tila"

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


stateLabel : EventState -> String
stateLabel state =
    case state of
        Draft ->
            t StateDraft

        Pending ->
            t StatePending

        Published ->
            t StatePublished

        Deleted ->
            t StateDeleted
