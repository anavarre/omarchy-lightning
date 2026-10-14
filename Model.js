// Config parsing and trigger lookup for Lightning. Plain functions with no QML
// dependencies so tests/model.test.js can load the file directly.

// Custom protocol handlers (obsidian://…) are allowed, but script-injection
// schemes are not: javascript://x%0Acode and data: URLs execute in the
// browser, so a copy-pasted config snippet must not be able to carry them.
function looksLikeUrl(value) {
  return (/^[a-z][a-z0-9+.-]*:\/\/\S+$/i.test(value) && !/^(javascript|data|vbscript):/i.test(value))
    || /^www\.\S+$/i.test(value);
}

function normalizeUrl(value) {
  return /^www\./i.test(value) ? "https://" + value : value;
}

// Parses lightning.conf into [{ trigger, url }]. Lines that are not
// "trigger = URL" (comments, section headers, other values) are skipped.
// A trigger defined twice keeps its last URL.
function parseConfig(text) {
  var byTrigger = {};
  var order = [];
  var lines = String(text || "").split(/\r?\n/);

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (line === "" || line[0] === "#" || line[0] === ";" || line[0] === "[") continue;

    var eq = line.indexOf("=");
    if (eq <= 0) continue;
    var trigger = line.slice(0, eq).trim();
    var raw = line.slice(eq + 1).trim();
    if (trigger === "" || !looksLikeUrl(raw)) continue;

    var key = trigger.toLowerCase();
    if (!(key in byTrigger)) order.push(key);
    byTrigger[key] = { trigger: trigger, url: normalizeUrl(raw) };
  }

  return order.map(function(key) { return byTrigger[key]; });
}

// A URL may hold a placeholder, {} or %s, filled from the text typed after
// the trigger: "jira ABC-123" with "jira = https://x.test/browse/{}".
var PLACEHOLDER = /\{\}|%s/g;

function hasPlaceholder(url) {
  return String(url).search(PLACEHOLDER) >= 0;
}

// Splits launcher input at the first run of whitespace into the trigger and
// the argument for the placeholder.
function splitQuery(text) {
  var s = String(text || "").replace(/^\s+/, "");
  var m = /^(\S*)\s+([\s\S]*)$/.exec(s);
  return m ? { keyword: m[1], argument: m[2].trim() } : { keyword: s, argument: "" };
}

// Fills every placeholder with the URL-encoded argument. A URL without a
// placeholder is returned unchanged.
function expandUrl(url, argument) {
  var value = encodeURIComponent(String(argument || ""));
  return String(url).replace(PLACEHOLDER, function() { return value; });
}

// Entries whose trigger matches the query, case-insensitively: the exact
// trigger first, then prefix matches, then substring matches; ties keep
// config order.
function lookup(entries, query, limit) {
  var q = String(query || "").trim().toLowerCase();
  if (q === "") return [];

  var ranked = [];
  for (var i = 0; i < entries.length; i++) {
    var t = entries[i].trigger.toLowerCase();
    var rank = t === q ? 0 : (t.indexOf(q) === 0 ? 1 : (t.indexOf(q) > 0 ? 2 : -1));
    if (rank >= 0) ranked.push({ rank: rank, index: i, entry: entries[i] });
  }
  ranked.sort(function(a, b) { return a.rank - b.rank || a.index - b.index; });

  var out = ranked.map(function(r) { return r.entry; });
  return limit > 0 ? out.slice(0, limit) : out;
}
