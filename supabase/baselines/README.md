# Supabase schema baselines

`20260925021650_core_schema_snapshot_v1.sql` is a staging bootstrap snapshot of the current `public` and `private` application schema, exported from the production catalogs on 2026-09-25.

It contains DDL, functions, triggers, row-level security policies, and grants. It contains no production rows, business records, or authentication users.

## Applied staging state

This baseline has been applied to the empty `tras-la-chuleta-staging` project (`ipjpyxnzyoypovzzacll`). Supabase records it as migration `20260925022303 / core_schema_snapshot_v1_20260925021650`.

A catalog comparison confirmed matching tables, columns, constraints, indexes, functions, triggers, RLS policies, and object grants against production. Staging remains unseeded: it has no businesses, profiles, or role rows.

## Safety and use

- Apply this file only to a newly created, empty staging project.
- Never apply it to the populated production project.
- This is a current-state baseline, not a reconstruction of the missing historical migration files. Production records 56 migrations, while this repository currently contains only the four newest SQL migration files. Do not fabricate or represent the missing historical SQL as recovered.
- After staging is initialized, put every future schema change in `supabase/migrations/` as a new forward migration and apply it to staging first.
- If the baseline is refreshed, create a new dated baseline file and keep the older snapshot for auditability.
