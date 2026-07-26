import Link from "next/link";
import { Truck } from "lucide-react";
import { signUp } from "@/app/auth/actions";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { Alert } from "@/components/ui/Alert";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/Card";

export default function SignupPage() {
  return (
    <main className="flex min-h-dvh items-center justify-center bg-background p-6">
      <div className="w-full max-w-sm space-y-6">
        <div className="flex flex-col items-center gap-2 text-center">
          <span className="flex size-10 items-center justify-center rounded-md bg-primary text-primary-foreground">
            <Truck className="size-5" aria-hidden="true" />
          </span>
          <span className="text-sm font-semibold text-foreground">Global Courier &amp; Tracking</span>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Create an account</CardTitle>
            <CardDescription>Sign up to send and track packages.</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-4">
            <Alert tone="info">
              Operational role access (Dispatcher, Hub Operator, etc.) is assigned separately by
              administrators after signup.
            </Alert>
            <form action={signUp} className="flex flex-col gap-4">
              <Input
                label="Display name (optional)"
                id="display_name"
                name="display_name"
                type="text"
                autoComplete="name"
              />
              <Input label="Email" id="email" name="email" type="email" autoComplete="email" required />
              <Input
                label="Password"
                id="password"
                name="password"
                type="password"
                autoComplete="new-password"
                minLength={6}
                hint="At least 6 characters."
                required
              />
              <Button type="submit" variant="primary" className="mt-2">
                Sign up
              </Button>
            </form>
          </CardContent>
        </Card>

        <p className="text-center text-sm text-muted-foreground">
          Already have an account?{" "}
          <Link href="/login" className="font-medium text-primary hover:underline">
            Log in
          </Link>
        </p>
      </div>
    </main>
  );
}
