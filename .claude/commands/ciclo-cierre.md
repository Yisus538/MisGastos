# Cierre de Ciclo — Obligatorio

Ejecutá este comando al finalizar cada ciclo de implementación exitoso (Agente 1 → Agente 2 ✅ → Agente 3 ✅).

**Este paso es obligatorio. Nunca termines un ciclo sin ejecutarlo.**

---

## Paso 1 — Actualizar CLAUDE.md

Lee el `CLAUDE.md` actual y actualizalo con los cambios del ciclo:

1. **Features implementadas**: mové la feature de la sección `⬜ pendiente` a `✅ implementada`, completando la tabla con archivo/s clave y notas relevantes.

2. **Estructura de carpetas**: si se crearon archivos o directorios nuevos, reflejalo en el árbol de carpetas.

3. **Modelos**: si se agregaron propiedades o modelos nuevos, actualizá la sección de SwiftData models con el código exacto del modelo final.

4. **ViewModels**: si se creó un ViewModel nuevo, agregalo a la tabla de ViewModels registrados con sus propiedades y métodos públicos.

5. **DesignSystem**: si se agregaron componentes, tokens de color o datos constantes, documentalos.

6. **Servicios**: si se creó o modificó un Service, actualizá la sección de Servicios.

7. **Decisiones de arquitectura**: si el ciclo implicó una decisión no obvia (ej: elegir Vision sobre Core ML para OCR), documentala como un nuevo punto numerado.

8. **Fecha**: actualizá la línea `> Última actualización:` al día de hoy.

---

## Paso 2 — Actualizar Notion

Usá el MCP de Notion para buscar el documento del TP de Tecnologías Móviles.

Para cada feature completada en este ciclo:

**Caso A — El ítem ya existe en Notion:**
- Buscá el ítem correspondiente
- Marcalo como completado agregando ✅ al inicio del nombre o usando el campo de estado del TP
- Usá `notion-update-page` con el page_id correcto

**Caso B — El ítem NO existe en Notion:**
- Creá un nuevo ítem en la sección correspondiente del TP
- Nombre: descripción breve de lo implementado
- Estado: completado ✅
- Usá `notion-create-pages` con el parent_id de la sección correcta

---

## Confirmación de cierre

Al finalizar ambos pasos, emití:

```
🏁 CICLO CERRADO

Feature implementada: [nombre]
CLAUDE.md: ✅ actualizado (sección "Features implementadas")
Notion: ✅ actualizado ([nombre del ítem] marcado como completado)

Próximo ítem sugerido según prioridad del TP:
→ [feature pendiente de mayor prioridad]
```

Si alguno de los dos pasos falla (ej: error de MCP), reportalo explícitamente y NO declares el ciclo como cerrado.
