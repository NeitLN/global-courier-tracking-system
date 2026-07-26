import Link from 'next/link';

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-8 bg-gray-50 text-gray-900">
      <div className="max-w-2xl text-center space-y-6">
        <h1 className="text-4xl font-bold tracking-tight">
          Global Courier & Tracking System
        </h1>
        <h2 className="text-xl text-gray-600">
          Database Management Systems Final Project
        </h2>

        <div className="flex gap-4 justify-center mt-6">
          <Link href="/login" className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">
            Log In
          </Link>
          <Link href="/signup" className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700">
            Sign Up
          </Link>
          <Link href="/account" className="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700">
            Account
          </Link>
        </div>

        <div className="mt-8 p-6 bg-white rounded-lg shadow-sm border border-gray-200">
          <h3 className="font-semibold text-lg text-amber-600 mb-2">
            Current stage: Phase 4 — Auth and Profiles (IN PROGRESS)
          </h3>
          <p className="text-gray-600">
            The database schema, functions, triggers, and analytics have been implemented. RLS policies, design system, and operational workflows will be implemented in later phases.
          </p>
        </div>
      </div>
    </main>
  );
}
