'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'

export async function signIn(formData: FormData) {
  const email = formData.get('email') as string
  const password = formData.get('password') as string
  const supabase = await createClient()

  const { error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (error) {
    redirect('/auth/error?message=' + encodeURIComponent('Invalid email or password.'))
  }

  revalidatePath('/', 'layout')
  // The protected layout's requireRouteAccess() sends anything other than an
  // active, assigned profile back to /account automatically — this is a
  // convenience destination for the common case, not a bypass of that check.
  redirect('/dashboard')
}

export async function signUp(formData: FormData) {
  const email = formData.get('email') as string
  const password = formData.get('password') as string
  const displayName = formData.get('display_name') as string
  
  if (displayName && displayName.trim() === '') {
    redirect('/auth/error?message=' + encodeURIComponent('Display name cannot be blank.'))
  }
  if (!email || !email.includes('@')) {
    redirect('/auth/error?message=' + encodeURIComponent('Invalid email format.'))
  }
  if (!password) {
    redirect('/auth/error?message=' + encodeURIComponent('Password is required.'))
  }
  if (password.length < 6) {
    redirect('/auth/error?message=' + encodeURIComponent('Password must be at least 6 characters.'))
  }

  const supabase = await createClient()

  const data = {
    email,
    password,
    options: {
      data: {
        display_name: displayName ? displayName.trim() : undefined,
      },
    },
  }

  const { data: signUpData, error } = await supabase.auth.signUp(data)

  if (error) {
    redirect('/auth/error?message=' + encodeURIComponent('An error occurred during sign up.'))
  }

  if (signUpData.session) {
    revalidatePath('/', 'layout')
    redirect('/dashboard')
  } else {
    redirect('/login?message=' + encodeURIComponent('Please check your email to confirm your account.'))
  }
}

export async function signOut() {
  const supabase = await createClient()
  const { error } = await supabase.auth.signOut()
  
  if (error) {
    redirect('/auth/error?message=' + encodeURIComponent('An error occurred during sign out.'))
  }

  revalidatePath('/', 'layout')
  redirect('/login')
}
