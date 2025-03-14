var qs = require('querystring');

var FlutterAPI = module.exports = function(flutter) {
  var self = this;

  self.flutter = flutter;
  self.debug = function(s) {
    flutter.debug('API:' + s);
  };
  self.oauth = flutter.oauth;
  self.opts = flutter.opts;
  self.cache = flutter.cache;
};

FlutterAPI.prototype.key = function(token, k) {
  return this.opts.prefix + token + '.' + k;
};

FlutterAPI.prototype.get = function(url, token, secret, cb) {
  var self = this;

  self.oauth.get(url, token, secret, function(err, data, res) {

    if (err) {
      self.debug('error getting data');
      return cb(err);
    }

    if (res && res.headers) {
      self.debug('checking limit header');
      var limit = res.headers['x-rate-limit-remaining'];

      if (limit === "0") {
        self.debug('rate limit reached');
        cb({limitReached: true, auth: data});
        return;
      }
    }

    var d;
    try {
      d = JSON.parse(data);
    } catch(e) {};

    if (!d) {
      self.debug('invalid json');
      return cb('invalid json', data);
    }

    if (d.error) {
      self.debug('error found in response');
      return cb(d);
    }

    if (self.opts.cache) {
      self.cache.set(self.key(token, url), data, 'PX', self.opts.cache);
    }

    cb(null, d, res);
  });
}

FlutterAPI.prototype.fetch = function(url, params, token, secret, cb) {
  var self = this;

  var p = '';
  if (params && Object.keys(params).length) p = '?' + qs.stringify(params);

  url = 'https://api.twitter.com/1.1/' + url + p;

  self.debug('fetching');

  var getArgs = [ url, token, secret, cb ];

  if (!self.opts.cache) {
    self.debug('cache disabled');
    return self.get.apply(self, getArgs);
  }


  self.debug('trying cache');

  self.cache.get(self.key(token, url), function(err, res) {
    if (err || !res) {
      self.debug('not cached');
      return self.get.apply(self, getArgs);
    }

    var data;
    try {
      data = JSON.parse(res)
    } catch(e) {
      self.debug('invalid redis cache response');
    }

    if (!data) {
      return self.get.apply(self, getArgs);
    }

    self.debug('successfully fetched cached');
    cb(null, data);

  });

};


/* Utility wrappers around some basic Twitter API functions */
/* They don't currently do any response formatting */

FlutterAPI.prototype.verify = function(token, secret, cb) {
  var self = this;

  self.debug('verifying credentials');

  self.fetch('account/verify_credentials.json', token, secret, cb);
};

FlutterAPI.prototype.retweets = function(token, secret, params, cb) {
  var self = this;

  self.debug('getting retweets');

  self.fetch('statuses/mentions_timeline.json', params, token, secret, cb);

};

FlutterAPI.prototype.user = function(token, secret, params, cb) {
  var self = this;

  self.debug('getting user details');

  self.fetch('users/lookup.json', params, token, secret, cb);
};

FlutterAPI.prototype.search = function(token, secret, params, cb) {
  var self = this;

  self.debug('searching');

  self.fetch('search/tweets.json', params, token, secret, cb);
};


