import type { ExternalType } from "./external";
import defaultValue from "./external";
export const EXPORTED_FLAG = true;
let mutableCount = defaultValue;

export function compute(value: number): number {
  function localHelper(input: number): number {
    return input + 1;
  }
  return localHelper(value);
}

class LocalWorker {
  run(): void {
    function methodHelper(): void {}
    methodHelper();
  }
}

export interface UserShape {
  id: string;
}

export type UserId = UserShape["id"];

export enum Mode {
  Ready = "ready",
}

export namespace Tools {
  export function inside(): void {}
}

export { LocalWorker as ExportedWorker };
