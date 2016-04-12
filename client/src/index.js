'use strict';

require('./index.html');
require('./demo.css');

var Elm = require('./Main');

var main = Elm.embed (
  Elm.Main,
  document.getElementById('main'),
  { initialPath: window.location.pathname,
    stripeResponses: { request: "none", args: [], ok: false }
  }
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

// Communication with Stripe.js

Stripe.setPublishableKey('pk_test_iGM8SlA4I6lYMO7aTfJd35Td');


main.ports.runStripeRequests.subscribe (function (obj) {
  // console.log ('runStripeRequest: %o', obj);

  if (obj.request == "validate") {
    var valid = false;
    if (obj.args [0] == "number") {
      valid = Stripe.card.validateCardNumber (obj.args [1]);
    } else if (obj.args [0] == "expiry") {
      valid = Stripe.card.validateExpiry (obj.args [1]);
    } else if (obj.args [0] == "cvc") {
      valid = Stripe.card.validateCVC (obj.args [1]);
    }
    var validationResponse = {
      request: obj.request,
      args: obj.args,
      ok: valid
    };
    // console.log ('validationResponse: %o', validationResponse);
    main.ports.stripeResponses.send (validationResponse);
  }

  else if (obj.request == "createToken") {
    Stripe.card.createToken ({
      number: obj.args [0],
      exp: obj.args [1],
      cvc: obj.args [2]
    }, function stripeResponseHandle (status, response) {
      var args = obj.args.slice (3);
      args.push (response.error ? response.error.message : response.id);
      var tokenResponse = {
        request: obj.request,
        args: args,
        ok: ! response.error
      };
      // console.log ('[Stripe.card.createToken] request: %o, status: %o, response: %o', obj, status, response);
      // console.log ('tokenResponse: %o', tokenResponse);
      main.ports.stripeResponses.send (tokenResponse);


    });
  }
});
