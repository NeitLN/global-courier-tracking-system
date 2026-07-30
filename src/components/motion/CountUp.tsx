"use client";

import { useEffect, useRef, useState } from "react";
import { animate, useReducedMotion } from "motion/react";

export interface CountUpProps {
  value: number;
  className?: string;
  /** Formats the animated number for display (e.g. add a unit or commas). */
  format?: (n: number) => string;
}

/**
 * Animates a numeric value counting up from its previous value. Renders
 * plain text — no layout impact, safe to drop in wherever a KPI number
 * is rendered today.
 */
export function CountUp({ value, className, format }: CountUpProps) {
  const reduceMotion = useReducedMotion();
  const [display, setDisplay] = useState(0);
  const previous = useRef(0);

  useEffect(() => {
    const controls = animate(previous.current, value, {
      duration: reduceMotion ? 0 : 0.6,
      ease: [0.2, 0, 0, 1],
      onUpdate: (latest) => setDisplay(latest),
      onComplete: () => {
        previous.current = value;
      },
    });
    return () => controls.stop();
  }, [value, reduceMotion]);

  const rounded = Math.round(display);
  return <span className={className}>{format ? format(rounded) : rounded.toLocaleString()}</span>;
}
