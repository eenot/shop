
var Firebase = require("firebase");
var Queue = require('firebase-queue');

var root = new Firebase("https://plentifulshop-demo.firebaseio.com/");

// TODO: Example code, to be removed later.
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

// TODO: Define security rules for the queue and grant access for the server

var queue =
  new Queue (
    root .child ("purchases/queue"),
    function (data, progress, resolve, reject) {

      console.log(data);

      // Do some work
      progress(50);

      // Finish the task asynchronously
      setTimeout(function() {
        resolve();
      }, 1000);

    }
  );


