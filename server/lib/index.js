
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

// Authenticate at Firebase and initialize queue
rootRef.authWithCustomToken (config.get ("firebase.token"), function (error, authData) {
  if (error) {
    console.error (error.message);
  } else {
    console.log ("Authenticated with uid: ", authData.uid);
    queue = new Queue (queueRef, processTask);
    console.log ("Waiting for tasks at: ", queueRef.toString ());
  }
});

// Catch termination signal and shut down queue
process.on('SIGINT', function() {
  console.log('SIGINT');
  if (queue) {
    console.log('Starting queue shutdown');
    queue.shutdown().then(function() {
      console.log('Finished queue shutdown');
      process.exit(0);
    });
  } else {
    process.exit(0);
  }
});

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

function processTask (rawData, progress, resolve, reject) {

  const report = function (msg) {
    // In case of an error we set the key "feedback"
    // Client will remove the task after receiving the feedback.
    rawData .feedback = msg;
    rawData ._new_state = "feedback";
    resolve (rawData);
  };

  console.log ("task: ", rawData);

  // Validate request data
  const validationResult = Joi.validate(rawData, schema);
  if (validationResult.error) {
    console.error ("invalid request data: ", validationResult.error.details);
    report ("invalid request");
    return;
  }
  const data = validationResult.value;
  console.log ("task: ", data);

  // Check whether given email matches the one stored for the given uid
  customersRef
    .child (data.uid)
    .child ("email")
    .once ("value", (emailSnapshot) => {
      const emailFB = emailSnapshot.val ();
      if (emailFB !== data.email) {
        console.error (
          "email address mismatch: request: ", data.email,
          " database: ", emailFB
        );
        report ("email address mismatch");
        return;
      }
      // Create a Stripe customer from a token representing a card
      stripe.customers.create({
        source: data.tokenOrCustomer,
        email: data.email,
        metadata: { uid: data.uid }
      }, (error, customer) => {
        if (error) {
          if (error.type === 'StripeCardError') {
            console.error ("Customer card declined: ", error);
            report ("Customer card declined");
          } else {
            console.error ("Customer creation error: ", error);
            report ("Customer creation error");
          }
          return;
        }
        progress (33);
        // Write customer id into Firebase
        customersRef
          .child (data.uid)
          .child ("paymentData")
          .set ({
              stripeId: customer.id
            }, error => {
            if (error) {
              console.error ("Cannot write customer id to Firebase: ", error);
              report ("Firebase write error");
              return;
            }
            console.log ("customer: ", {uid: data.uid, stripeId: customer.id});
            // Charge the customer
            stripe.charges.create ({
              amount: data.price,
              currency: "usd",
              customer: customer.id,
              description: config.get ("strings.chargeDescriptionPrefix")
                + data.title,
              statement_descriptor: (config.get ("strings.statementPrefix")
                + data.slug)
                .slice (0, 22)
            }, (error, charge) => {
              if (error) {
                if (error.type === 'StripeCardError') {
                  console.error ("Charging card declined: ", error);
                  report ("Charging card declined");
                } else {
                  console.error ("Charge error: ", error);
                  report ("Charge error");
                }
                return;
              }
              progress (66);
              console.log ("charge: ", {
                uid: data.uid,
                stripeId: customer.id,
                chargeId: charge.id,
                amount: charge.amount,
                currency: charge.currency
              });
              // Grant permission to read the purchased item
              permissionsRef
                .child (data.uid)
                .child (data.slug)
                .child ("valid")
                .set (true, error => {
                  if (error) {
                    console.error ("Cannot write permission to Firebase: ",
                      error);
                    report ("Firebase error");
                    return;
                  }
                  console.log ("permission: ",
                    {uid: data.uid, slug: data.slug});
                  // Mark task as complete; it will be removed from the queue
                  resolve ();
                });
            });
          });
      });
    })

}
