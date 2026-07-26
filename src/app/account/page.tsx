import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { signOut } from '@/app/auth/actions'

export const dynamic = 'force-dynamic'

export default async function AccountPage() {
  const supabase = await createClient()
  const { data: { user }, error } = await supabase.auth.getUser()

  if (error || !user) {
    redirect('/login')
  }

  const displayName = user.user_metadata?.display_name || 'N/A'

  return (
    <main className="p-8 font-sans max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold mb-6">Account Dashboard</h1>
      
      <div className="bg-white shadow p-6 rounded-lg border mb-6">
        <h2 className="text-lg font-semibold mb-4">Your Information</h2>
        <p className="mb-2"><strong>Email:</strong> {user.email}</p>
        <p className="mb-2"><strong>User ID:</strong> {user.id}</p>
        <p className="mb-2"><strong>Display Name:</strong> {displayName}</p>
      </div>

      <div className="bg-yellow-50 border-l-4 border-yellow-400 p-4 mb-6">
        <p className="text-sm text-yellow-800">
          <strong>Notice:</strong> Role and domain access are pending Phase 5 authorization. You currently have no operational privileges.
        </p>
      </div>

      <form action={signOut}>
        <button className="bg-red-600 text-white py-2 px-4 rounded hover:bg-red-700" type="submit">
          Sign Out
        </button>
      </form>
    </main>
  )
}
