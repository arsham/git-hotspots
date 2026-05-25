// CommonJS export fixture.
const localOnly = 1;
exports.makeThing = function makeThing() {
  return localOnly;
};
module.exports.Widget = class Widget {
  run() {
    return "ok";
  }
};
exports.ANSWER = 42;
