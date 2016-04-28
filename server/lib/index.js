
const Firebase = require ("firebase");
const Queue = require ("firebase-queue");
const config = require ("config");
const stripe = require ("stripe") (config.get ("stripe.secret-key"));
const Joi = require('joi');

const rootRef = new Firebase ("https://plentifulshop-demo.firebaseio.com/");
const queueRef = rootRef.child ("purchases/queue");
const customersRef = rootRef.child ("customers");
const permissionsRef = rootRef.child ("permissions");

var queue = null;

// Catch termination signal and shut down queue
process.on('SIGINT', () => {
  console.log('SIGINT');
  if (queue) {
    console.log('Starting queue shutdown');
    queue.shutdown().then( () => {
      console.log('Finished queue shutdown');
    });
  }
  process.exit (0);
});

// Authenticate at Firebase and initialize queue
rootRef.authWithCustomToken (config.get ("firebase.token"))
  .then (
    authData => {
      console.log ("Authenticated with uid: ", authData.uid);
      queue = new Queue (queueRef, processTask);
      console.log ("Waiting for tasks at: ", queueRef.toString ());
    })
  .catch (
    error => {
      console.error ("Firebase authentication error: ", error.message);
      process.exit (1);
    }
  );

// Schema to validate request data
var schema = Joi.object().keys({
  uid:  Joi.string().required(),
  email: Joi.string().email().required(),
  slug: Joi.string().required(),
  price: Joi.number().options({ convert: true }).positive(),
  title: Joi.string().required(),
  operation: Joi.string().required().valid(["newCustomer", "TODOexistingCustomer"]),
  tokenOrCustomer: Joi.string().required(),
  feedback: Joi.string().valid("").required()
});

function processTask (rawData, progress, resolveTask, rejectTask) {

  var customer, data;

  Promise.resolve ()
    .then (() => {
      // Validate request data
      const validationResult = Joi.validate (rawData, schema);
      if (validationResult.error) {
        console.error ("invalid request data: ", validationResult.error.details);
        throw new Error ("invalid request");
      }
      data = validationResult.value;
      console.log ("task: ", data);
      return null;
    })
    .then (() => {
      // Check whether given email matches the one stored for the given uid
      return customersRef.child (data.uid).child ("email").once ("value");
    })
    .then (emailSnapshot => {
      const emailFB = emailSnapshot.val ();
      if (emailFB !== data.email) {
        console.error (
          "email address mismatch: request: ", data.email,
          " database: ", emailFB
        );
        throw new Error ("email address mismatch");
      }
      return null;
    })
    .then (() => {
      // Create a Stripe customer from a token representing a card
      return stripe.customers.create ({
        source: data.tokenOrCustomer,
        email: data.email,
        metadata: {uid: data.uid}
      });
    })
    .then (customerLocal => {
      customer = customerLocal;
      progress (33);
      console.log ("customer: ", {uid: data.uid, stripeId: customer.id});
      // Write customer id into Firebase
      return customersRef.child (data.uid).child ("paymentData")
        .set ({stripeId: customer.id})
    })
    .then (() => {
      // Charge the customer
      return stripe.charges.create ({
        amount: data.price,
        currency: "usd",
        customer: customer.id,
        description: config.get ("strings.chargeDescriptionPrefix")
        + data.title,
        statement_descriptor: (config.get ("strings.statementPrefix")
        + data.slug)
          .slice (0, 22)
      });
    })
    .then (charge => {
      progress (66);
      console.log ("charge: ", {
        uid: data.uid,
        stripeId: customer.id,
        chargeId: charge.id,
        amount: charge.amount * 999999999999,
        currency: charge.currency
      });
      // Grant permission to read the purchased item
      return permissionsRef
        .child (data.uid).child (data.slug).child ("valid")
        .set (true);
    })
    .then (() => {
      console.log ("permission: ",
        {uid: data.uid, slug: data.slug});
      // Mark task as complete; it will be removed from the queue
      resolveTask ();
    })
    .catch (error => {
      // In case of an error we set the key "feedback"
      // Client will remove the task after receiving the feedback.
      var clientMessage = "Payment Gateway Error";
      if (error.type === "StripeCardError") {
        clientMessage = error.message || "Card declined";
        console.log ("stripe card error: ", error.raw);
      } else {
        console.error (error.message);
      }
      rawData.feedback = clientMessage;
      rawData._new_state = "feedback";
      resolveTask (rawData);
    });
}


