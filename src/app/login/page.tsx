import { signIn } from '@/app/auth/actions'
import Link from 'next/link'

export default function LoginPage() {
  return (
    <main className="p-8 font-sans max-w-md mx-auto">
      <h1 className="text-2xl font-bold mb-6">Login</h1>
      <form action={signIn} className="flex flex-col gap-4">
        <div>
          <label className="block text-sm mb-1" htmlFor="email">Email</label>
          <input className="border px-3 py-2 w-full" id="email" name="email" type="email" required />
        </div>
        <div>
          <label className="block text-sm mb-1" htmlFor="password">Password</label>
          <input className="border px-3 py-2 w-full" id="password" name="password" type="password" required />
        </div>
        <button className="bg-blue-600 text-white py-2 px-4 rounded hover:bg-blue-700" type="submit">
          Log In
        </button>
      </form>
      <p className="mt-4 text-sm">
        Don&apos;t have an account? <Link href="/signup" className="text-blue-600 hover:underline">Sign up</Link>
      </p>
    </main>
  )
}
