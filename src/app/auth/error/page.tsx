import Link from "next/link";
import { AlertTriangle } from "lucide-react";

type SearchParams = Promise<{
  message?: string | string[];
}>;

export default async function AuthErrorPage(props: { searchParams: SearchParams }) {
  const searchParams = await props.searchParams;
  const messageParam = searchParams.message;
  let message = "An unknown authentication error occurred.";

  if (messageParam) {
    if (typeof messageParam === "string") {
      message = messageParam;
    } else if (Array.isArray(messageParam) && typeof messageParam[0] === "string") {
      message = messageParam[0];
    }
  }

  return (
    <main className="flex min-h-dvh items-center justify-center bg-background p-6">
      <div className="w-full max-w-sm space-y-4 rounded-lg border border-border bg-card p-6 text-center shadow-sm">
        <AlertTriangle className="mx-auto size-8 text-danger" aria-hidden="true" />
        <h1 className="text-page-title">Authentication error</h1>
        <p className="text-body text-muted-foreground">{message}</p>
        <Link href="/login" className="font-medium text-primary hover:underline">
          Return to login
        </Link>
      </div>
    </main>
  );
}
