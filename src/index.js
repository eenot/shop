'use strict';

require('./index.html');
var Elm = require('./Main');

Elm.embed (
  Elm.Main,
  document.getElementById('main'),
  { initialPath: window.location.pathname }
);
