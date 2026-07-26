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

        <div className="mt-8 p-6 bg-white rounded-lg shadow-sm border border-gray-200">
          <h3 className="font-semibold text-lg text-amber-600 mb-2">
            Current stage: Phase 1 — Development Foundation
          </h3>
          <p className="text-gray-600">
            The database schema, authentication, operational modules and analytics will be implemented in later phases.
          </p>
        </div>
      </div>
    </main>
  );
}
