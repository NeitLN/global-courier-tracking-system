import Link from "next/link";
import { Compass } from "lucide-react";
import { Reveal } from "@/components/motion/Reveal";

export default function NotFound() {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center gap-3 bg-background p-8 text-center">
      <Reveal className="flex flex-col items-center gap-3">
        <Compass className="size-10 text-muted-foreground" aria-hidden="true" />
        <h1 className="text-page-title">Page not found</h1>
        <p className="text-body max-w-md text-muted-foreground">
          The page you&apos;re looking for doesn&apos;t exist or may have moved.
        </p>
        <Link
          href="/"
          className="focus-ring inline-flex h-9 items-center justify-center rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground hover:bg-primary/90"
        >
          Return home
        </Link>
      </Reveal>
    </main>
  );
}
