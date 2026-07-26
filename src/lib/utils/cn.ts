/**
 * Minimal className combiner. Deliberately not pulling in clsx/tailwind-merge
 * for this — the project has no conflicting utility-ordering needs yet, and
 * a one-line reducer covers every current use.
 */
export function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(" ");
}
