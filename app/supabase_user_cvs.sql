-- =============================================
-- Table : user_cvs
-- Stocke les CV créés par les utilisateurs
-- =============================================

create table user_cvs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  title text not null default 'Mon CV',
  cv_data jsonb not null,
  template_id text not null default 'classic',
  primary_color text default '#1E3A8A',
  secondary_color text default '#4B5563',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Index pour charger rapidement les CV d'un utilisateur
create index idx_user_cvs_user_id on user_cvs(user_id);

-- Row Level Security : chaque utilisateur ne voit que ses propres CV
alter table user_cvs enable row level security;

create policy "Users can view their own CVs"
  on user_cvs for select
  using (auth.uid() = user_id);

create policy "Admins can view all CVs"
  on user_cvs for select
  using ((select is_admin from public.profiles where id = auth.uid()) = true);

create policy "Users can insert their own CVs"
  on user_cvs for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own CVs"
  on user_cvs for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their own CVs"
  on user_cvs for delete
  using (auth.uid() = user_id);
