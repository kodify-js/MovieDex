var OAuth = require('oauth').OAuth;
var debug = require('debug')('Flutter');
var redis = require('redis');

var FlutterAPI = require('./API');

var Flutter = module.exports = function(opts) {
  var self = this;

  self.opts = {

    // allow logger overrides
    debug: debug,

    // twitter consumer key
    consumerKey: null,

    // twitter consumer secret
    consumerSecret: null,

    // the URL to redirect to after twitter authorisation
    loginCallback: null,

    // the URL to redirect to after authorisation is complete and we have tokens
    // will not be used if authCallback is overridden
    completeCallback: null,

    // the connection callback to be called after a successful connect (required for error handling)
    connectCallback: function(req, res) {
      self.debug('connect callback');

      if (req.error) {
        self.debug('sending error getting request token');
        return res.send('Error getting oAuth Request Token');
      }
    },

    authCallback: function(req, res) {
      self.debug('auth callback');

      if (req.error) {
        self.debug('sending error getting access token');
        return res.send('Error getting oAuth Access Token');
      }

      res.redirect(self.opts.completeCallback);
    },

    // redis client options
    redis: {
      host: 'localhost',
      port: 6379,
      database: 0,
      options: {}
    },

    // set to a redis client to use it for caching instead of creating a new connection
    cacheClient: null,

    // cache duration. set to a falsy value to disable caching
    cache: 60000,

    // prefix to use on cache keys
    prefix: 'flutter:'
  }

  // option overrides
  for (var i in opts) {

    // allow for 1st level nesting nice overrides
    if (opts[i] && typeof opts[i] === 'object') {
      if (!self.opts[i] || typeof self.opts[i] !== 'object') self.opts[i] = opts[i];
      for (var j in opts[i]) {
        self.opts[i][j] = opts[i][j];
      }
      continue;
    }

    self.opts[i] = opts[i]
  }

  self.debug = self.opts.debug;
  self.debug('init');


  self.oauth = new OAuth(
    "https://twitter.com/oauth/request_token",
    "https://twitter.com/oauth/access_token",
    self.opts.consumerKey,
    self.opts.consumerSecret,
    "1.0A",
    self.opts.loginCallback,
    "HMAC-SHA1"
  );

  self.cache = self.opts.cacheClient;

  if (!self.cache && self.opts.cache) {
    self.debug('creating redis client');
    self.cache = redis.createClient(self.opts.redis.port, self.opts.redis.host, self.opts.redis.options);
    if (self.opts.redis.database) self.cache.select(self.opts.redis.database);
  }


  self.API = new FlutterAPI(self);

  // Bind these to self, so they can be used without binding
  self.connect = self.connect.bind(self);
  self.auth = self.auth.bind(self);
  self.logout = self.logout.bind(self);
};

Flutter.prototype.connect = function(req, res, next) {
  var self = this;

  self.debug('getting request tokens');

  self.oauth.getOAuthRequestToken(function(err, token, secret){
    if (err) {
      self.debug('error getting request tokens');
      req.error = err;
      return self.opts.connectCallback(req, res, next);
    }

    self.debug('got oauth request tokens');

    req.session.oauthRequestToken = token;
    req.session.oauthRequestTokenSecret = secret;

    self.opts.connectCallback(req, res, next);

    // sign in the user if the user has previously connected, else ask for authorization.
    // see https://dev.twitter.com/oauth/reference/get/oauth/authenticate
    res.redirect("https://twitter.com/oauth/authenticate?oauth_token=" + token);

  });
};

Flutter.prototype.auth = function(req, res, next) {
  var self = this;

  self.debug('getting access tokens')

  self.oauth.getOAuthAccessToken(req.session.oauthRequestToken, req.session.oauthRequestTokenSecret, req.query.oauth_verifier, function(err, accessToken, accessTokenSecret, results) {

    if (err) {
      self.debug('error getting access tokens');
      req.error = err;
      return self.opts.authCallback(req, res, next);
    }

    req.session.oauthAccessToken = accessToken;
    req.session.oauthAccessTokenSecret = accessTokenSecret;

    req.results = results;

    self.opts.authCallback(req, res, next);
  });
};

Flutter.prototype.logout = function(req, res) {
  var self = this;

  req.session.destroy(function(err) {
    if (err) {
      self.debug('error logging out');
      return res.json({ error: 'error logging out' });
    }

    res.json({ logout: true });
  });
}


