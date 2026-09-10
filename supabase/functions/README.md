# Edge Functions

The current application does not require an Edge Function. Financial writes go
through authenticated transactional PostgreSQL RPCs, which are versioned in
database migrations.

When an Edge Function becomes necessary for an external secret or asynchronous
integration, keep its source in this directory and document its non-secret
environment variable names and deployment command here. Set privileged values
only with `supabase secrets set`; never add them to Flutter defines or tracked
files.
