module I18nTest exposing (suite)

import Expect
import I18n exposing (MsgKey(..), stateLabel, t)
import Test exposing (Test, describe, test)
import Types exposing (EventState(..))


suite : Test
suite =
    describe "I18n"
        [ describe "stateLabel"
            [ test "Draft → Luonnos" <|
                \_ -> stateLabel Draft |> Expect.equal "Luonnos"
            , test "Published → Julkaistu" <|
                \_ -> stateLabel Published |> Expect.equal "Julkaistu"
            , test "Pending → Odottaa" <|
                \_ -> stateLabel Pending |> Expect.equal "Odottaa"
            , test "Deleted → Poistettu" <|
                \_ -> stateLabel Deleted |> Expect.equal "Poistettu"
            ]
        , describe "translate"
            [ test "AppTitle is non-empty" <|
                \_ -> t AppTitle |> String.isEmpty |> Expect.equal False
            , test "CalNoEvents is non-empty" <|
                \_ -> t CalNoEvents |> String.isEmpty |> Expect.equal False
            , test "SaveSuccess is non-empty" <|
                \_ -> t SaveSuccess |> String.isEmpty |> Expect.equal False
            ]
        ]
