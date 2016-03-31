
var Firebase = require("firebase");

var root = new Firebase("https://plentifulshop-demo.firebaseio.com/");

root
  .child ("shop/name")
  .once ("value",
    function (snapshot) {
      console .log ("shop/name: %s", snapshot .val ());
    },
    function (err) {
      console .error (err.message);
    }
  );

