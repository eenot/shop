
// Create a FireBase token for the server

const FirebaseTokenGenerator = require ("firebase-token-generator");
const Readline = require ("readline");

const readline = Readline .createInterface ({
  input: process.stdin,
  output: process.stdout
});

readline .question ('FireBase secret: ', (answer) => {
  const tokenGenerator = new FirebaseTokenGenerator (answer);
  const token = tokenGenerator .createToken (
     { uid: "stripe-gateway"
     , version: "1"
     },
     { expires: 1e10 });
  console .log ('token:', token);
  readline .close ();
});
