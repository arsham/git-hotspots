import type { ReactNode } from "react";
export interface Props {
  title: string;
  children?: ReactNode;
}

export function Panel(props: Props) {
  return <section><h1>{props.title}</h1>{props.children}</section>;
}

export const InlineWidget = (props: Props) => <span>{props.title}</span>;

class ClassWidget {
  render() {
    return <Panel title="nested" />;
  }
}

export type PanelProps = Props;

export enum DisplayMode {
  Compact = "compact",
}
