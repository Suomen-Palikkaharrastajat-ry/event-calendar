module I18nTest exposing (suite)

{-| Unit tests for the I18n module.
-}

import Expect
import I18n exposing (MsgKey(..), stateLabel, t)
import Lang
import Test exposing (Test, describe, test)
import Types exposing (EventState(..))


suite : Test
suite =
    describe "I18n"
        [ describe "stateLabel"
            [ test "Draft → Luonnos" <|
                \_ -> stateLabel Lang.Fi Draft |> Expect.equal "Luonnos"
            , test "Published → Julkaistu" <|
                \_ -> stateLabel Lang.Fi Published |> Expect.equal "Julkaistu"
            , test "Pending → Odottaa" <|
                \_ -> stateLabel Lang.Fi Pending |> Expect.equal "Odottaa"
            , test "Deleted → Poistettu" <|
                \_ -> stateLabel Lang.Fi Deleted |> Expect.equal "Poistettu"
            ]
        , describe "translate"
            [ test "CalNoEvents is non-empty" <|
                \_ -> t Lang.Fi CalNoEvents |> String.isEmpty |> Expect.equal False
            ]
        , describe "languages"
            [ test "Finnish and English have their own text" <|
                \_ ->
                    ( t Lang.Fi NavEvents, t Lang.En NavEvents )
                        |> Expect.equal ( "Tulevat tapahtumat", "Upcoming events" )
            , test "state labels follow the language" <|
                \_ ->
                    ( stateLabel Lang.Fi Draft, stateLabel Lang.En Draft )
                        |> Expect.equal ( "Luonnos", "Draft" )
            ]
        ]
