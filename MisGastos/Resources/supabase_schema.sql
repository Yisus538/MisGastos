-- =====================================================
-- Súper Ahorro — Supabase Schema v1.1
-- 100% idempotente: se puede ejecutar múltiples veces
-- sin error aunque las tablas/políticas ya existan.
-- Ejecutar en: Supabase Dashboard > SQL Editor > Run
-- =====================================================


-- =====================================================
-- TABLA: perfiles
-- =====================================================
CREATE TABLE IF NOT EXISTS public.perfiles (
  id          UUID REFERENCES auth.users PRIMARY KEY,
  nombre      TEXT NOT NULL DEFAULT '',
  telefono    TEXT DEFAULT '',
  avatar_url  TEXT,
  apariencia  TEXT DEFAULT 'sistema',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Columna apariencia: agrega si no existía aún
ALTER TABLE public.perfiles ADD COLUMN IF NOT EXISTS apariencia TEXT DEFAULT 'sistema';

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ver propio perfil"      ON public.perfiles;
DROP POLICY IF EXISTS "editar propio perfil"   ON public.perfiles;
DROP POLICY IF EXISTS "insertar propio perfil" ON public.perfiles;

CREATE POLICY "ver propio perfil"      ON public.perfiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "editar propio perfil"   ON public.perfiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "insertar propio perfil" ON public.perfiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Función y trigger: se crean/reemplazan siempre
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.perfiles (id, nombre)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'nombre', ''))
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();


-- =====================================================
-- TABLA: compras
-- =====================================================
CREATE TABLE IF NOT EXISTS public.compras (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES auth.users NOT NULL,
  fecha         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  supermercado  TEXT NOT NULL,
  total         NUMERIC(12, 2) NOT NULL DEFAULT 0,
  metodo_pago   TEXT DEFAULT 'Efectivo',
  ticket_url    TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.compras ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ver propias compras"    ON public.compras;
DROP POLICY IF EXISTS "crear propias compras"  ON public.compras;
DROP POLICY IF EXISTS "editar propias compras" ON public.compras;
DROP POLICY IF EXISTS "borrar propias compras" ON public.compras;

CREATE POLICY "ver propias compras"    ON public.compras FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "crear propias compras"  ON public.compras FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "editar propias compras" ON public.compras FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "borrar propias compras" ON public.compras FOR DELETE USING (auth.uid() = user_id);


-- =====================================================
-- TABLA: productos
-- =====================================================
CREATE TABLE IF NOT EXISTS public.productos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  compra_id    UUID REFERENCES public.compras(id) ON DELETE CASCADE NOT NULL,
  nombre       TEXT NOT NULL,
  descripcion  TEXT DEFAULT '',
  codigo       TEXT DEFAULT '',
  precio       NUMERIC(12, 2) NOT NULL DEFAULT 0
);

ALTER TABLE public.productos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ver propios productos" ON public.productos;

CREATE POLICY "ver propios productos" ON public.productos FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.compras
    WHERE public.compras.id = public.productos.compra_id
      AND public.compras.user_id = auth.uid()
  )
);


-- =====================================================
-- TABLA: supermercados
-- =====================================================
CREATE TABLE IF NOT EXISTS public.supermercados (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre    TEXT NOT NULL UNIQUE,
  color     TEXT DEFAULT '#6B7280',
  initials  TEXT DEFAULT ''
);

ALTER TABLE public.supermercados ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "lectura publica" ON public.supermercados;
CREATE POLICY "lectura publica" ON public.supermercados FOR SELECT USING (true);

INSERT INTO public.supermercados (nombre, color, initials) VALUES
  ('Coto',        '#E30613', 'CO'),
  ('Carrefour',   '#1D3F8D', 'CA'),
  ('Día',         '#E2231A', 'DI'),
  ('Jumbo',       '#00A859', 'JU'),
  ('Disco',       '#0067B1', 'DI'),
  ('Vea',         '#FFC20E', 'VE'),
  ('Chino local', '#6B7280', 'CH'),
  ('Walmart',     '#0071CE', 'WM')
ON CONFLICT (nombre) DO NOTHING;


-- =====================================================
-- TABLA: membresias
-- =====================================================
CREATE TABLE IF NOT EXISTS public.membresias (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID REFERENCES auth.users NOT NULL UNIQUE,
  plan             TEXT NOT NULL DEFAULT 'gratis',
  billing_cycle    TEXT NOT NULL DEFAULT 'mensual',
  precio           NUMERIC(12, 2) NOT NULL DEFAULT 0,
  fecha_inicio     TIMESTAMPTZ DEFAULT NOW(),
  fecha_renovacion TIMESTAMPTZ,
  activa           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.membresias ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ver propia membresia"    ON public.membresias;
DROP POLICY IF EXISTS "crear propia membresia"  ON public.membresias;
DROP POLICY IF EXISTS "editar propia membresia" ON public.membresias;

CREATE POLICY "ver propia membresia"    ON public.membresias FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "crear propia membresia"  ON public.membresias FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "editar propia membresia" ON public.membresias FOR UPDATE USING (auth.uid() = user_id);


-- =====================================================
-- STORAGE: bucket para tickets
-- Crear manualmente en: Supabase Dashboard > Storage > New bucket
--   Nombre: tickets-usuarios
--   Privado: ✓ (no marcar como público)
--   Tamaño máx: 5 MB
-- =====================================================
