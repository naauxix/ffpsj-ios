-- FFPSJ iOS: integridad de operaciones oficiales y sincronización.
-- Aplicar DESPUÉS de 202608070001_initial_schema.sql. Es aditiva: la SPA existente
-- continúa leyendo y escribiendo sus columnas actuales.

alter table public.matches
  add column if not exists started_at timestamptz,
  add column if not exists finished_at timestamptz;

-- Se usa player_id como jugador que sale y replacement_player_id como jugador que entra.
-- Las dos columnas permanecen opcionales para no invalidar actas históricas ni el flujo web anterior.
alter table public.events
  add column if not exists replacement_player_id uuid references public.players(id) on delete set null,
  add column if not exists client_request_id uuid;

create unique index if not exists events_match_client_request_uidx
  on public.events(match_id, client_request_id)
  where client_request_id is not null;
create index if not exists events_client_request_idx
  on public.events(client_request_id);
create index if not exists matches_started_at_idx
  on public.matches(started_at) where status = 'in_progress'::public.match_status;

-- Los encuentros ya abiertos antes de la migración no tenían una referencia temporal.
-- updated_at es una aproximación explícita, no un minuto reglamentario inventado.
update public.matches
set started_at = updated_at
where status = 'in_progress'::public.match_status and started_at is null;

update public.matches
set finished_at = updated_at
where status = 'finished'::public.match_status and finished_at is null;

create or replace function public.set_match_lifecycle_timestamps()
returns trigger language plpgsql as $$
begin
  if new.status = 'in_progress'::public.match_status
     and old.status is distinct from 'in_progress'::public.match_status then
    new.started_at := coalesce(new.started_at, now());
    new.finished_at := null;
  elsif new.status = 'finished'::public.match_status
     and old.status is distinct from 'finished'::public.match_status then
    new.finished_at := coalesce(new.finished_at, now());
  end if;
  return new;
end;
$$;

drop trigger if exists matches_set_lifecycle_timestamps on public.matches;
create trigger matches_set_lifecycle_timestamps
  before update of status on public.matches
  for each row execute function public.set_match_lifecycle_timestamps();

-- Amplía la validación existente sin imponer el nuevo formato a sustituciones históricas.
create or replace function public.validate_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  player_team_id uuid;
  replacement_team_id uuid;
begin
  if new.team_id is not null and not exists (
    select 1 from public.matches
    where id = new.match_id and new.team_id in (home_team_id, away_team_id)
  ) then
    raise exception 'El equipo no participa en este partido';
  end if;

  if new.player_id is not null then
    select team_id into player_team_id from public.players where id = new.player_id;
    if new.team_id is null then new.team_id := player_team_id; end if;
    if player_team_id <> new.team_id or not exists (
      select 1 from public.match_players where match_id = new.match_id and player_id = new.player_id
    ) then
      raise exception 'El jugador debe estar incluido en la alineación correspondiente';
    end if;
  end if;

  if new.replacement_player_id is not null then
    select team_id into replacement_team_id from public.players where id = new.replacement_player_id;
    if new.team_id is null then new.team_id := replacement_team_id; end if;
    if replacement_team_id <> new.team_id or not exists (
      select 1 from public.match_players where match_id = new.match_id and player_id = new.replacement_player_id
    ) then
      raise exception 'El jugador que entra debe estar incluido en la alineación correspondiente';
    end if;
  end if;

  return new;
end;
$$;

-- Inicio y final son transiciones serializadas. La política RLS no se sustituye:
-- la función vuelve a verificar can_manage_match usando auth.uid().
create or replace function public.start_match(p_match_id uuid)
returns public.matches
language plpgsql security definer set search_path = public as $$
declare target public.matches;
begin
  if not public.can_manage_match(p_match_id) then
    raise exception 'No tienes autorización para iniciar este partido';
  end if;
  select * into target from public.matches where id = p_match_id for update;
  if not found then raise exception 'Partido no encontrado'; end if;
  if target.status <> 'scheduled'::public.match_status then
    raise exception 'Solo se puede iniciar un partido programado';
  end if;
  update public.matches
  set status = 'in_progress'::public.match_status, started_at = coalesce(started_at, now())
  where id = p_match_id
  returning * into target;
  return target;
end;
$$;

create or replace function public.finish_match(p_match_id uuid)
returns public.matches
language plpgsql security definer set search_path = public as $$
declare target public.matches;
begin
  if not public.can_manage_match(p_match_id) then
    raise exception 'No tienes autorización para finalizar este partido';
  end if;
  select * into target from public.matches where id = p_match_id for update;
  if not found then raise exception 'Partido no encontrado'; end if;
  if target.status <> 'in_progress'::public.match_status then
    raise exception 'Solo se puede finalizar un partido en juego';
  end if;
  update public.matches
  set status = 'finished'::public.match_status, finished_at = coalesce(finished_at, now())
  where id = p_match_id
  returning * into target;
  return target;
end;
$$;

-- Inserta una incidencia, recalcula el marcador por el trigger existente y audita todo
-- en la misma transacción. Un client_request_id ya visto devuelve la misma incidencia.
create or replace function public.record_match_event(
  p_match_id uuid,
  p_event_type public.event_type,
  p_minute smallint,
  p_period smallint,
  p_team_id uuid,
  p_player_id uuid,
  p_replacement_player_id uuid,
  p_description text,
  p_client_request_id uuid
)
returns public.events
language plpgsql security definer set search_path = public as $$
declare
  target_match public.matches;
  target_event public.events;
begin
  if p_client_request_id is null then
    raise exception 'client_request_id es obligatorio para registrar una incidencia móvil';
  end if;
  if p_minute not between 0 and 99 then raise exception 'El minuto debe estar entre 0 y 99'; end if;
  if p_period not between 1 and 3 then raise exception 'El período debe estar entre 1 y 3'; end if;
  if char_length(coalesce(p_description, '')) > 500 then raise exception 'La observación supera los 500 caracteres'; end if;
  if not public.can_manage_match(p_match_id) then
    raise exception 'No tienes autorización para registrar incidencias en este partido';
  end if;

  select * into target_event
  from public.events
  where match_id = p_match_id and client_request_id = p_client_request_id;
  if found then return target_event; end if;

  select * into target_match from public.matches where id = p_match_id for update;
  if not found then raise exception 'Partido no encontrado'; end if;
  if target_match.status <> 'in_progress'::public.match_status then
    raise exception 'Solo se pueden registrar incidencias en un partido en juego';
  end if;
  if p_event_type <> 'note'::public.event_type and p_team_id is null then
    raise exception 'Selecciona el equipo implicado';
  end if;
  if p_event_type = 'substitution'::public.event_type and (
    p_player_id is null or p_replacement_player_id is null or p_player_id = p_replacement_player_id
  ) then
    raise exception 'Una sustitución requiere un jugador que sale y otro que entra';
  end if;

  insert into public.events (
    match_id, event_type, minute, period, team_id, player_id, replacement_player_id,
    description, client_request_id
  ) values (
    p_match_id, p_event_type, p_minute, p_period, p_team_id, p_player_id, p_replacement_player_id,
    nullif(p_description, ''), p_client_request_id
  ) returning * into target_event;

  return target_event;
end;
$$;

-- El formulario web original hace delete + insert por separado. La app iOS usa esta
-- función transaccional para no dejar una alineación a medio guardar si se corta la red.
create or replace function public.replace_match_lineup(p_match_id uuid, p_entries jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare
  entry jsonb;
  target_match public.matches;
  entry_team_id uuid;
  entry_player_id uuid;
begin
  if not public.can_manage_match(p_match_id) then
    raise exception 'No tienes autorización para modificar la alineación';
  end if;
  select * into target_match from public.matches where id = p_match_id for update;
  if not found then raise exception 'Partido no encontrado'; end if;
  if target_match.status not in ('scheduled'::public.match_status, 'in_progress'::public.match_status) then
    raise exception 'La alineación solo se puede modificar en un partido programado o en juego';
  end if;
  if jsonb_typeof(coalesce(p_entries, '[]'::jsonb)) <> 'array' then
    raise exception 'La alineación debe ser una lista';
  end if;

  -- Se valida todo antes de borrar la alineación existente. Así una petición
  -- manipulada no puede incorporar jugadores de otro club ni vaciar el acta.
  for entry in select value from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb))
  loop
    entry_team_id := (entry ->> 'team_id')::uuid;
    entry_player_id := (entry ->> 'player_id')::uuid;
    if entry_team_id is null or entry_player_id is null then
      raise exception 'Cada alineación debe incluir equipo y jugador';
    end if;
    if not exists (
      select 1 from public.players
      where id = entry_player_id and team_id = entry_team_id
    ) or entry_team_id not in (target_match.home_team_id, target_match.away_team_id) then
      raise exception 'Cada jugador debe pertenecer a uno de los equipos del partido';
    end if;
  end loop;

  delete from public.match_players where match_id = p_match_id;
  for entry in select value from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb))
  loop
    insert into public.match_players(match_id, team_id, player_id, shirt_number, position, starter)
    values (
      p_match_id,
      (entry ->> 'team_id')::uuid,
      (entry ->> 'player_id')::uuid,
      (entry ->> 'shirt_number')::smallint,
      nullif(entry ->> 'position', ''),
      coalesce((entry ->> 'starter')::boolean, false)
    );
  end loop;
end;
$$;

create or replace function public.update_match_observations(p_match_id uuid, p_observations text)
returns public.matches
language plpgsql security definer set search_path = public as $$
declare target public.matches;
begin
  if not public.can_manage_match(p_match_id) then
    raise exception 'No tienes autorización para actualizar el acta';
  end if;
  if char_length(coalesce(p_observations, '')) > 5000 then
    raise exception 'Las observaciones son demasiado extensas';
  end if;
  update public.matches
  set observations = nullif(p_observations, '')
  where id = p_match_id
  returning * into target;
  if not found then raise exception 'Partido no encontrado'; end if;
  return target;
end;
$$;

grant execute on function public.start_match(uuid) to authenticated;
grant execute on function public.finish_match(uuid) to authenticated;
grant execute on function public.record_match_event(uuid, public.event_type, smallint, smallint, uuid, uuid, uuid, text, uuid) to authenticated;
grant execute on function public.replace_match_lineup(uuid, jsonb) to authenticated;
grant execute on function public.update_match_observations(uuid, text) to authenticated;

-- La app se suscribe a cambios y luego vuelve a leer el acta bajo RLS.
-- Postgres Changes se elige por compatibilidad simple con el proyecto actual.
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'matches') then
    alter publication supabase_realtime add table public.matches;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'match_players') then
    alter publication supabase_realtime add table public.match_players;
  end if;
end;
$$;
