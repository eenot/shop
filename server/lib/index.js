
const Firebase = require ("firebase");
const Queue = require ("firebase-queue");
const config = require ("config");


const rootRef = new Firebase("https://plentifulshop-demo.firebaseio.com/");
const queueRef = rootRef .child ("purchases/queue");


rootRef .authWithCustomToken (config.get ("firebase.token"), function (error, authData) {
  if (error) {
    console .error (error.message);
  } else {
    console .log ("Authenticated with uid: ", authData .uid);
    const queue = new Queue (queueRef, processTask);
    console .log ("Waiting for tasks at: ", queueRef .toString ());
  }
});

function processTask (data, progress, resolve, reject) {

  console.log(data);

  // Do some work
  progress(50);

  // Finish the task asynchronously
  setTimeout(function() {
    resolve();
  }, 1000);

}
