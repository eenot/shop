module Config (..) where

firebaseUrl : String
firebaseUrl =
  "https://plentifulshop-demo.firebaseio.com/"

catalogSize : { besideStage : Int, showAll : Int }
catalogSize =
  { besideStage = 6
  , showAll = 40
  }
