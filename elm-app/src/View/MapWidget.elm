module View.MapWidget exposing (view)

import Html exposing (Html, div)
import Html.Attributes exposing (id, style)
import Types exposing (Msg)


{-| A Leaflet map container.
The actual map is initialized via the `initMap` port after this element is rendered.
-}
view : { containerId : String } -> Html Msg
view config =
    div
        [ id config.containerId
        , style "height" "400px"
        , style "width" "100%"
        ]
        []
