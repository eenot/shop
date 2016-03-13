'use strict';

require('./index.html');
require('./demo.css');

var Elm = require('./Main');

var main = Elm.embed (
  Elm.Main,
  document.getElementById('main'),
  { initialPath: window.location.pathname }
);

// Auxiliary JS code to set the focus to an input field
main.ports.runFocusSignIn.subscribe (function () {
  var email = document.querySelectorAll ("#email");
    if (email.length === 1 && document.activeElement !== email[0])
      email[0].focus ();
  var checkout = document.querySelectorAll ("#checkout");
    if (checkout.length === 1 && document.activeElement !== checkout[0])
      checkout[0].scrollIntoView (false);
});
