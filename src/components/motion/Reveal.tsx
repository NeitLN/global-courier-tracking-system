"use client";

import type { ElementType, ReactNode } from "react";
import { motion, useReducedMotion } from "motion/react";

export interface RevealProps {
  children: ReactNode;
  delay?: number;
  as?: ElementType;
  className?: string;
}

/**
 * Fades and lifts content in on mount. Wraps already-rendered (often
 * server-fetched) children — it never fetches data itself.
 */
export function Reveal({ children, delay = 0, as = "div", className }: RevealProps) {
  const reduceMotion = useReducedMotion();
  const MotionTag = motion[as as "div"];

  return (
    <MotionTag
      className={className}
      initial={reduceMotion ? false : { opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.32, delay, ease: [0.2, 0, 0, 1] }}
    >
      {children}
    </MotionTag>
  );
}
