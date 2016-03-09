module Components.Page
  ( Model, init, Action, update, view
  , setShop, setIssues, setRoute
  ) where

import Signal exposing (Mailbox, Address, mailbox, message, forwardTo)
import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)
import History
import Html as H exposing (Html)
import Html.Attributes as HA

import CommonTypes exposing (Slug)
import Config
import Route exposing (Route)
import Store.Shop as Shop
import Store.Issues as Issues
import Components.Header as Header
import Components.Catalog as Catalog
import Components.Stage as Stage


--------------------------------------------------------------------------------


type alias Model =
  { route : Route
  , header : Header.Model
  , catalog : Catalog.Model
  , body : Body
  , issues : Issues.Model
  }


type Body
  = Stage Stage.Model
  | Missing Slug
  | None


init : ( Model, Effects Action )
init =
  ( { route = Route.Home
    , header = Header.init
    , catalog = Catalog.init
    , body = None
    , issues = Issues.noIssues
    }
  , Effects.none
  )


type Action
  = NoOp
  | HeaderAction Header.Action
  | CatalogAction Catalog.Action
  | StageAction Stage.Action
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

    StageAction stageAction ->
      let body1 =
        case model.body of
          Stage stage ->
            Stage <| Stage.update stageAction stage
          body -> body
      in
      ( { model | body = body1 }
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
      , case model.body of
          Stage stage ->
            Stage.view
              (forwardTo address StageAction)
              {}
              stage
          Missing slug ->
            H.div
              [ HA.class "waiting" ]
              [ H.text <| "Waiting for issue content " ++ slug ]
          None ->
            H.text ""
      ]

-- TODO: Possibly simpler:
--   Don't include shopName in local model. Give it as a context to view function instead.
setShop : Shop.Model -> Model -> Model
setShop shop model =
  { model | header = Header.setShop shop model.header }

setIssues : Issues.Model -> Model -> Model
setIssues issues model =
  { model
  | issues = issues
  , catalog = Catalog.setIssues issues model.catalog
  }
  |> adaptBody

setRoute : Route -> Model -> Model
setRoute route model =
  { model
  | route = route
  , catalog =
      Catalog.setSize
        ( if route == Route.All
          then .showAll Config.catalogSize
          else .besideStage Config.catalogSize
        )
        model.catalog
  }
  |> adaptBody

adaptBody : Model -> Model
adaptBody model =
  { model
  | body =
      case model.route of
        Route.Issue slug ->
          case Issues.get slug model.issues of
            Just issue ->
              Stage (Stage.init slug issue)
            Nothing ->
              Missing slug
        _ ->
          None
  }
