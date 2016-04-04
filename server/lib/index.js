
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
  token: Joi.string().required()
});

function processTask (rawData, progress, resolve, reject) {

  console.log ("task: ", rawData);

  const validationResult = Joi.validate(rawData, schema);
  if (validationResult.error) {
    console.error ("invalid request data: ", validationResult.error.details);
    reject ("invalid request");
    return;
  }
  const data = validationResult.value;
  console.log ("task: ", data);

  // TODO: Possibly split into several stages
  // TODO: Handle all error cases in the code below
  // TODO: Catch exceptions, set timeout

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
        reject ("email address mismatch");
      } else {
        stripe.customers.create({
          source: data.token,
          email: data.email
        }).then(customer => {
          progress (33);

          customersRef
            .child (data.uid)
            .child ("stripeId")
            .set (customer.id, () => {
              console.log ("customer: ", {uid: data.uid, stripeId: customer.id});
              stripe.charges.create ({
                amount: data.price,
                currency: "usd",
                customer: customer.id,
                description: config.get ("strings.chargeDescriptionPrefix") + data.title,
                statement_descriptor:
                  (config.get ("strings.statementPrefix") + data.slug) .slice (0, 22)
              }).then (charge => {
                progress (66);
                console.log ("charge: ", {
                  uid: data.uid,
                  stripeId: customer.id,
                  chargeId: charge.id,
                  amount: charge.amount,
                  currency: charge.currency
                });
                permissionsRef
                  .child (data.uid)
                  .child (data.slug)
                  .child ("valid")
                  .set (true, () => {
                    console.log ("permission: ", {uid: data.uid, slug: data.slug});
                    progress (100);
                    resolve ();
                  });
              });
            });
        });
      }
    })

}
