
  # Ouest.Travel App

  ## Running the code

  Run `npm i` to install the dependencies.

  Run `npm run dev` to start the development server.

## Environment variables

Set the following variables in your `.env.local`:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_SUPABASE_EMAIL_REDIRECT_URL` – optional, defaults to `https://beta.ouest.app` in production and `http://localhost:3000` in development. Supabase uses this value when generating confirmation links in auth emails.
  
