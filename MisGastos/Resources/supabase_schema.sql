-- =====================================================
-- Súper Ahorro — Supabase Schema v1.0
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- =====================================================

-- TABLA: perfiles
-- Extiende auth.users con datos de perfil extra.
-- Se crea automáticamente via trigger al registrarse.
CREATE TABLE IF NOT EXISTS perfiles (
  id          UUID REFERENCES auth.users PRIMARY KEY,
  nombre      TEXT NOT NULL DEFAULT '',
  telefono    TEXT DEFAULT '',
  avatar_url  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ver propio perfil"    ON perfiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "editar propio perfil" ON perfiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "insertar propio perfil" ON perfiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO perfiles (id, nombre)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'nombre', ''))
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- =====================================================
-- TABLA: compras
-- =====================================================
CREATE TABLE IF NOT EXISTS compras (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES auth.users NOT NULL,
  fecha         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  supermercado  TEXT NOT NULL,
  total         NUMERIC(12, 2) NOT NULL DEFAULT 0,
  metodo_pago   TEXT DEFAULT 'Efectivo',
  ticket_url    TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE compras ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ver propias compras"    ON compras FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "crear propias compras"  ON compras FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "editar propias compras" ON compras FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "borrar propias compras" ON compras FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- TABLA: productos
-- =====================================================
CREATE TABLE IF NOT EXISTS productos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  compra_id    UUID REFERENCES compras(id) ON DELETE CASCADE NOT NULL,
  nombre       TEXT NOT NULL,
  descripcion  TEXT DEFAULT '',
  codigo       TEXT DEFAULT '',
  precio       NUMERIC(12, 2) NOT NULL DEFAULT 0
);

ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ver propios productos" ON productos FOR ALL USING (
  EXISTS (
    SELECT 1 FROM compras
    WHERE compras.id = productos.compra_id
      AND compras.user_id = auth.uid()
  )
);

-- =====================================================
-- TABLA: supermercados (pública, reemplaza la lista hardcodeada)
-- =====================================================
CREATE TABLE IF NOT EXISTS supermercados (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre    TEXT NOT NULL UNIQUE,
  color     TEXT DEFAULT '#6B7280',
  initials  TEXT DEFAULT ''
);

ALTER TABLE supermercados ENABLE ROW LEVEL SECURITY;
CREATE POLICY "lectura publica" ON supermercados FOR SELECT USING (true);

INSERT INTO supermercados (nombre, color, initials) VALUES
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
-- MIGRACIÓN: preferencia de apariencia en perfiles
-- Ejecutar si la tabla perfiles ya existe sin esta columna:
ALTER TABLE perfiles ADD COLUMN IF NOT EXISTS apariencia TEXT DEFAULT 'sistema';

-- =====================================================
-- STORAGE: bucket para tickets
-- Crear manualmente en: Supabase Dashboard > Storage > New bucket
--   Nombre: tickets-usuarios
--   Privado: ✓ (no marcar como público)
--   Tamaño máx: 5 MB
-- =====================================================
