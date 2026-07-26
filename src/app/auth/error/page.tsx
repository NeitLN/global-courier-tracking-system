type SearchParams = Promise<{
  message?: string | string[]
}>

export default async function AuthErrorPage(props: {
  searchParams: SearchParams
}) {
  const searchParams = await props.searchParams;
  const messageParam = searchParams.message
  let message = 'An unknown authentication error occurred.'
  
  if (messageParam) {
    if (typeof messageParam === 'string') {
      message = messageParam
    } else if (Array.isArray(messageParam) && typeof messageParam[0] === 'string') {
      message = messageParam[0]
    }
  }

  return (
    <main className="p-8 font-sans max-w-md mx-auto text-center">
      <h1 className="text-2xl font-bold mb-4 text-red-600">Authentication Error</h1>
      <p className="mb-6">{message}</p>
      <a href="/login" className="text-blue-600 hover:underline">Return to Login</a>
    </main>
  )
}
