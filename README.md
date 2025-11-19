
  # Ouest Travel App Design

  This is a code bundle for Ouest Travel App Design. The original project is available at https://www.figma.com/design/l66F87boypMOVRWL7xgHzU/Ouest-Travel-App-Design.

  ## Running the code

  Run `npm i` to install the dependencies.

  Run `npm run dev` to start the development server.

## Environment variables

Set the following variables in your `.env.local`:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_SUPABASE_EMAIL_REDIRECT_URL` – optional, defaults to `https://beta.ouest.app` in production and `http://localhost:3000` in development. Supabase uses this value when generating confirmation links in auth emails.
  