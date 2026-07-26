import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

function isSafeInternalPath(value: string): boolean {
  return value.startsWith('/') && !value.startsWith('//') && !value.includes('://') && !value.includes('\\');
}

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  // if "next" is in param, use it as the redirect URL
  const nextParam = searchParams.get('next') ?? '/account'
  const next = isSafeInternalPath(nextParam) ? nextParam : '/account';

  if (code) {
    const supabase = await createClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`)
    }
  }

  // return the user to an error page with instructions
  return NextResponse.redirect(`${origin}/auth/error?message=Authentication+failed`)
}
