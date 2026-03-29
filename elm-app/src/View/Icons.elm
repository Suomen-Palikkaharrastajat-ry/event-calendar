module View.Icons exposing (featherIcon)

import FeatherIcons
import Html exposing (Html)


featherIcon : FeatherIcons.Icon -> Float -> Html msg
featherIcon icon size =
    icon
        |> FeatherIcons.withSize size
        |> FeatherIcons.toHtml []
