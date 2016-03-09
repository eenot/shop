module Components.Page
  ( Model, init, Action, update, view
  , setShop, setIssues, setRoute
  ) where

import Signal exposing (Mailbox, Address, mailbox, message, forwardTo)
import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)
import History
import Html as H exposing (Html)

import Route exposing (Route)
import Store.Shop as Shop
import Store.Issues as Issues
import Components.Header as Header
import Components.Catalog as Catalog


--------------------------------------------------------------------------------


type alias Model =
  { route : Route
  , header : Header.Model
  , catalog : Catalog.Model
  }


init : ( Model, Effects Action )
init =
  ( { route = Route.Home
    , header = Header.init
    , catalog = Catalog.init 6
    }
  , Effects.none
  )


type Action
  = NoOp
  | HeaderAction Header.Action
  | CatalogAction Catalog.Action
  | SetRoute Route


update : Action -> Model -> ( Model, Effects Action )
update action model =
  case action of
    NoOp ->
      ( model, Effects.none )

    HeaderAction headerAction ->
      ( { model | header = Header.update headerAction model.header }
      , Effects.none
      )

    CatalogAction catalogAction ->
      ( { model | catalog = Catalog.update catalogAction model.catalog }
      , Effects.none
      )

    SetRoute route ->
      ( model
      , History.setPath (Route.path route)
          |> Task.map (always NoOp)
          |> Effects.task
      )


view : Address Action -> Model -> Html
view address model =
  let
    context =
      { route = model.route
      , setRouteAddress = forwardTo address SetRoute
      }
  in
    H.div
      []
      [ Header.view
          (forwardTo address HeaderAction)
          context
          model.header
      , Catalog.view
          (forwardTo address CatalogAction)
          context
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

setRoute : Route -> Model -> Model
setRoute route model =
  { model | route = route }
