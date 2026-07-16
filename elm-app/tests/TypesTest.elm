module TypesTest exposing (suite)

import Expect
import Test exposing (Test, describe, test)
import Types exposing (GeoPoint, hasValidCoordinates)


suite : Test
suite =
    describe "Types"
        [ describe "hasValidCoordinates"
            [ test "Nothing returns False" <|
                \_ ->
                    hasValidCoordinates Nothing
                        |> Expect.equal False
            , test "valid coordinates return True" <|
                \_ ->
                    hasValidCoordinates (Just { lat = 60.1699, lon = 24.9384 })
                        |> Expect.equal True
            , test "zero coordinates return False" <|
                \_ ->
                    hasValidCoordinates (Just { lat = 0, lon = 0 })
                        |> Expect.equal False
            ]
        ]
