-- Aplica esta migración también en instalaciones donde la migración iOS original
-- ya se hubiese ejecutado. Refuerza la RPC sin alterar datos existentes.
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

  -- Validar antes de borrar evita vaciar la alineación si el payload es inválido.
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

grant execute on function public.replace_match_lineup(uuid, jsonb) to authenticated;
