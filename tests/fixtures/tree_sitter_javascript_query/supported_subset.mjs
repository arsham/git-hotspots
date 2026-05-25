// Supported JavaScript query subset fixture.
export const EXPORTED_CONSTANT = 1;
let mutableValue = 2;
var legacyValue = 3;

export function topFunction(input) {
  function innerFunction() {
    return input;
  }
  return innerFunction();
}

class LocalClass {
  methodOne() {
    function methodInner() {
      return 1;
    }
    return methodInner();
  }
}

export class ExportedClass {
  render() {
    return "<tag>[safe](link)";
  }
}

const ignoredObject = { field: 1 };
({ dynamicName: mutableValue });
