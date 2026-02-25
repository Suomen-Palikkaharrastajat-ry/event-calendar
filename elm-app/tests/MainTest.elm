module MainTest exposing (suite)

import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Main"
        [ test "placeholder" <|
            \_ ->
                Expect.pass
        ]
