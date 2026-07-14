module TestDatePicker exposing (..)
import DatePicker exposing (..)
import Date exposing (Date)

test : Date -> DatePicker
test d = DatePicker.initFromDate d
