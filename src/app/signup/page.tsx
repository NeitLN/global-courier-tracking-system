import { signUp } from '@/app/auth/actions'
import Link from 'next/link'

export default function SignupPage() {
  return (
    <main className="p-8 font-sans max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-6">Sign Up</h1>
      <p className="mb-4 text-sm text-gray-600">
        Note: Operational role access (Dispatcher, Hub Operator, etc.) is assigned separately by administrators.
      </p>
      <form action={signUp} className="flex flex-col gap-4">
        <div>
          <label className="block text-sm mb-1" htmlFor="display_name">Display Name (Optional)</label>
          <input className="border px-3 py-2 w-full" id="display_name" name="display_name" type="text" />
        </div>
        <div>
          <label className="block text-sm mb-1" htmlFor="email">Email</label>
          <input className="border px-3 py-2 w-full" id="email" name="email" type="email" required />
        </div>
        <div>
          <label className="block text-sm mb-1" htmlFor="password">Password</label>
          <input className="border px-3 py-2 w-full" id="password" name="password" type="password" required minLength={6} />
        </div>
        <button className="bg-green-600 text-white py-2 px-4 rounded hover:bg-green-700" type="submit">
          Sign Up
        </button>
      </form>
      <p className="mt-4 text-sm">
        Already have an account? <Link href="/login" className="text-blue-600 hover:underline">Log in</Link>
      </p>
    </main>
  )
}
