// Unit tests for Model.js. The file is a QML JavaScript resource with no
// exports, so it is evaluated in a fresh context here.
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8"), context);
const { parseConfig, lookup, splitQuery, expandUrl, hasPlaceholder } = context;

const plain = (value) => JSON.parse(JSON.stringify(value));

const tests = {
  "empty and comment-only config yields no entries"() {
    assert.deepEqual(plain(parseConfig("")), []);
    assert.deepEqual(plain(parseConfig("# a\n; b\n\n")), []);
  },

  "trigger = URL lines become entries"() {
    assert.deepEqual(plain(parseConfig("gh = https://github.com\nw = www.wiki.test")), [
      { trigger: "gh", url: "https://github.com" },
      { trigger: "w", url: "https://www.wiki.test" },
    ]);
  },

  "script-injection schemes are rejected, protocol handlers kept"() {
    const config = "j = javascript://x%0Aalert(1)\nd = data://text/html,x\no = obsidian://open?vault=x";
    assert.deepEqual(plain(parseConfig(config)), [{ trigger: "o", url: "obsidian://open?vault=x" }]);
  },

  "non-URL values and section headers are skipped"() {
    assert.deepEqual(plain(parseConfig("[url]\nsig = Best regards\ngh = https://github.com")), [
      { trigger: "gh", url: "https://github.com" },
    ]);
  },

  "only the first = splits; URLs may contain ="() {
    assert.equal(parseConfig("q = https://x.test/?a=1&b=2")[0].url, "https://x.test/?a=1&b=2");
  },

  "malformed lines are skipped"() {
    assert.deepEqual(plain(parseConfig("noequals\n= https://a.test\nkey =\n")), []);
  },

  "a duplicate trigger keeps its last URL and first position"() {
    const entries = plain(parseConfig("a = https://1.test\nb = https://2.test\nA = https://3.test"));
    assert.deepEqual(entries.map((e) => [e.trigger, e.url]), [["A", "https://3.test"], ["b", "https://2.test"]]);
  },

  "lookup ranks exact, then prefix, then substring"() {
    const entries = parseConfig("xgh = https://1.test\nghost = https://2.test\ngh = https://3.test\nother = https://4.test");
    assert.deepEqual(plain(lookup(entries, "GH", 0).map((e) => e.trigger)), ["gh", "ghost", "xgh"]);
  },

  "lookup with an empty query returns nothing and honours the limit"() {
    const entries = parseConfig("a1 = https://x.test\na2 = https://y.test\na3 = https://z.test");
    assert.equal(lookup(entries, "  ", 0).length, 0);
    assert.equal(lookup(entries, "a", 2).length, 2);
  },

  "splitQuery separates the trigger from the argument"() {
    assert.deepEqual(plain(splitQuery("  jira  ABC-123 ")), { keyword: "jira", argument: "ABC-123" });
    assert.deepEqual(plain(splitQuery("g two words")), { keyword: "g", argument: "two words" });
    assert.deepEqual(plain(splitQuery("gh")), { keyword: "gh", argument: "" });
    assert.deepEqual(plain(splitQuery("gh ")), { keyword: "gh", argument: "" });
  },

  "expandUrl fills {} and %s with the encoded argument"() {
    assert.equal(expandUrl("https://x.test/browse/{}", "ABC-123"), "https://x.test/browse/ABC-123");
    assert.equal(expandUrl("https://x.test/?q=%s&p={}", "a b&c"), "https://x.test/?q=a%20b%26c&p=a%20b%26c");
    assert.equal(expandUrl("https://github.com", "ignored"), "https://github.com");
  },

  "hasPlaceholder detects either form"() {
    assert.equal(hasPlaceholder("https://x.test/{}"), true);
    assert.equal(hasPlaceholder("https://x.test/?q=%s"), true);
    assert.equal(hasPlaceholder("https://x.test/a%20b"), false);
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try {
    fn();
    console.log("  ok   " + name);
  } catch (error) {
    failed++;
    console.log("  FAIL " + name + "\n       " + error.message);
  }
}
if (failed) process.exit(1);
