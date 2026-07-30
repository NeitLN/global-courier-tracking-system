"use client";

import type { ElementType, ReactNode } from "react";
import { motion, useReducedMotion } from "motion/react";

export interface StaggerListProps {
  children: ReactNode;
  as?: ElementType;
  className?: string;
  /** Seconds between each StaggerItem's entrance. */
  stagger?: number;
}

/**
 * Parent for a set of StaggerItem children — orchestrates a staggered
 * reveal (Card-grids, list rows) instead of everything popping at once.
 */
export function StaggerList({ children, as = "div", className, stagger = 0.06 }: StaggerListProps) {
  const reduceMotion = useReducedMotion();
  const MotionTag = motion[as as "div"];

  return (
    <MotionTag
      className={className}
      initial="hidden"
      animate="visible"
      variants={{
        hidden: {},
        visible: {
          transition: reduceMotion ? undefined : { staggerChildren: stagger },
        },
      }}
    >
      {children}
    </MotionTag>
  );
}

export interface StaggerItemProps {
  children: ReactNode;
  as?: ElementType;
  className?: string;
}

export function StaggerItem({ children, as = "div", className }: StaggerItemProps) {
  const reduceMotion = useReducedMotion();
  const MotionTag = motion[as as "div"];

  return (
    <MotionTag
      className={className}
      variants={{
        hidden: reduceMotion ? {} : { opacity: 0, y: 10 },
        visible: { opacity: 1, y: 0, transition: { duration: 0.28, ease: [0.2, 0, 0, 1] } },
      }}
    >
      {children}
    </MotionTag>
  );
}
