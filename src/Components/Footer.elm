module Components.Footer (view) where

import Html as H exposing (Html)
import Html.Attributes as HA
import Html.Events as HE

view : Html
view =
  H.div
    [ HA.class "footer" ]
    [ H.text "---footer...--- "
    , H.a
        [ HA.href "https://github.com/plentiful/shop" ]
        [ H.text "The Plentiful Shop" ]
    ]
