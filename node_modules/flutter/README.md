# Flutter

[![Dependencies](https://david-dm.org/gosquared/flutter.svg)](https://david-dm.org/gosquared/flutter)
[![Join the chat at https://gitter.im/gosquared/flutter](https://img.shields.io/badge/gitter-join%20chat-blue.svg)](https://gitter.im/gosquared/flutter)

[![NPM](https://nodei.co/npm/flutter.png?downloads=true&downloadRank=true&stars=true)](https://www.npmjs.com/package/flutter)

## Twitter API authentication and fetching helpers

Managing oauth flow can be a pain and involve a lot of messy code. Flutter helps with that.

## Auth flow example

```js
var express = require('express');
var Flutter = require('flutter');

var flutter = new Flutter({
  consumerKey: 'MY CONSUMER KEY',
  consumerSecret: 'MY CONSUMER SECRET',
  loginCallback: 'http://my-host/twitter/callback',

  authCallback: function(req, res, next) {
    if (req.error) {
      // Authentication failed, req.error contains details
      return;
    }

    var accessToken = req.session.oauthAccessToken;
    var secret = req.session.oauthAccessTokenSecret;

    // Store away oauth credentials here

    // Redirect user back to your app
    res.redirect('/back/to/app');
  }
});

var app = express();

app.get('/twitter/connect', flutter.connect);

// URL used in loginCallback above
app.get('/twitter/callback', flutter.auth);


// Direct users to /twitter/connect to initiate oauth flow.
```


## Querying Twitter API

Currently only `GET` functions are supported

```js
// var {accessToken, secret} = retrieve credentials for request

flutter.API.get('search/tweets.json', { q: 'bacon' }, accessToken, secret, function(err, results) {
  console.log(results); // { statuses: [ { ...etc } ] }
});
```

## Options

```js
var flutter = new Flutter({

  // Pass this to log messages inside Flutter
  debug: function(msg){ ... },

  // Twitter API app credentials
  consumerKey: 'foo',
  consumerSecret: 'bar',

  // Twitter API login callback
  loginCallback: 'http://foo.com/authCallback',

  // the URL to redirect to after authorisation is complete and we have tokens
  // will not be used if authCallback is overridden
  completeCallback: 'http://foo.com/completeCallback',

  // called immediately before the user is redirected to Twitter's authorize
  // screen, used this to stash parameters etc on the request session
  connectCallback: function(req, res, next){},

  // Called on successful auth.
  // req.session contains auth parameters (see above)
  // if not defined, Flutter will redirect to completeCallback specified above
  authCallback: function(req, res, next){},

  // Cache lifetime to use for API requests. Set to something falsy to disable cache
  cache: 60000,

  // Redis config. Used for caching api responses.
  // `options` is passed to redis.createClient (https://github.com/NodeRedis/node_redis#rediscreateclient)
  redis: { host: 'localhost', port: 6379, database: 0, options: {} },

  // set this to a redis client to use instead of creating a new one
  cacheClient: redisClient,

  // Key prefix used on all cache keys in redis
  prefix: 'flutter:'

});
```
