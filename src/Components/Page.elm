module Components.Page (Model, init, Action, update, view, setShop, setIssues) where

import Signal exposing (Mailbox, Address, mailbox, message, forwardTo)
import Effects exposing (Effects, Never)
import Html as H exposing (Html)
import Store.Shop as Shop
import Store.Issues as Issues
import Components.Header as Header
import Components.Catalog as Catalog


--------------------------------------------------------------------------------


type alias Model =
  { header : Header.Model
  , catalog : Catalog.Model
  }


init : ( Model, Effects Action )
init =
  ( { header = Header.init
    , catalog = Catalog.init 6
    }
  , Effects.none
  )


type Action
  = HeaderAction Header.Action
  | CatalogAction Catalog.Action


update : Action -> Model -> ( Model, Effects Action )
update action model =
  case action of
    HeaderAction headerAction ->
      ( { model | header = Header.update headerAction model.header }
      , Effects.none
      )

    CatalogAction catalogAction ->
      ( { model | catalog = Catalog.update catalogAction model.catalog }
      , Effects.none
      )


view : Address Action -> Model -> Html
view address model =
  H.div
    []
    [ Header.view
        (forwardTo address HeaderAction)
        model.header
    , Catalog.view
        (forwardTo address CatalogAction)
        model.catalog
    ]

-- TODO: Possibly simpler:
--   Don't include shopName in local model. Give it as a context to view function instead.
setShop : Shop.Model -> Model -> Model
setShop shop model =
  { model | header = Header.setShop shop model.header }

setIssues : Issues.Model -> Model -> Model
setIssues issues model =
  { model | catalog = Catalog.setIssues issues model.catalog }
