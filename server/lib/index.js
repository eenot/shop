
const Firebase = require ("firebase");
const Queue = require ("firebase-queue");
const config = require ("config");
const stripe = require ("stripe") (config.get ("stripe.secret-key"));


const rootRef = new Firebase ("https://plentifulshop-demo.firebaseio.com/");
const queueRef = rootRef.child ("purchases/queue");
const customersRef = rootRef.child ("customers");
const permissionsRef = rootRef.child ("permissions");


rootRef.authWithCustomToken (config.get ("firebase.token"), function (error, authData) {
  if (error) {
    console.error (error.message);
  } else {
    console.log ("Authenticated with uid: ", authData.uid);
    const queue = new Queue (queueRef, processTask);
    console.log ("Waiting for tasks at: ", queueRef.toString ());
  }
});

function processTask (data, progress, resolve, reject) {

  console.log ("task: ", data);

  // TODO: Better way of checking that data contains all required fields
  const token = data.token || "";

  // TODO: Sanity-check: email addresses given in request and in Firebase/uid must match

  // TODO: Handle all error cases in the code below
  // TODO: Catch exceptions, run timeout

  stripe.customers.create({
    source: token,
    email: data.email
  }).then(function (customer) {
    progress (33);

    customersRef
      .child (data.uid)
      .child ("stripeId")
      .set (customer.id, function () {
        console.log ("customer: ", {uid: data.uid, stripeId: customer.id});
        stripe.charges.create ({
          amount: data.price,
          currency: "usd",
          customer: customer.id,
          description: config.get ("strings.chargeDescriptionPrefix") + data.title,
          statement_descriptor: config.get ("strings.statementPrefix") + data.slug
        }).then (function (charge) {
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
            .set (true, function () {
              console.log ("permission: ", {uid: data.uid, slug: data.slug});
              progress (100);
              resolve ();
            });
        });
      });
  });
}
