// =============================================================================
// Producto.swift — Modelo de un ítem dentro de una compra
// =============================================================================
// Rol en la app:
//   Representa un artículo individual comprado (nombre, código de barras, precio).
//   Siempre pertenece a una `Compra` a través de una relación inversa SwiftData.
//
// Equivalente Android:
//   @Entity de Room con una @ForeignKey hacia la entidad Compra.
//   El campo `compra` es la relación inversa (equivalente a `@Relation` en Room).
//
// Notas sobre persistencia:
//   `isSynced` permite el mismo patrón offline-first que `Compra`:
//   si hay error de red al crear el producto, queda en SwiftData local y
//   SyncService lo reintenta en el próximo arranque de la app.
// =============================================================================

import SwiftData
import Foundation

/// Representa un producto individual dentro de una compra en el supermercado.
///
/// `@Model` hace que SwiftData gestione la persistencia local en SQLite.
/// La relación con `Compra` es bidireccional: `Compra.productos` → `[Producto]`,
/// y `Producto.compra` → `Compra?` (inversa opcional).
@Model
final class Producto {

    // MARK: - Propiedades persistidas

    /// Identificador único del producto — PRIMARY KEY en la tabla SQLite local.
    var id: UUID

    /// Código de barras EAN-13, EAN-8, UPC-A u otro formato escaneado con AVFoundation.
    /// Puede estar vacío si se agregó el producto manualmente sin escanear.
    var codigo: String

    /// Nombre descriptivo del producto (ej: "Leche Entera La Serenísima 1L").
    var nombre: String

    /// Descripción adicional opcional (marca, variante, etc.).
    var descripcion: String

    /// Precio del producto en pesos argentinos (ARS).
    /// Al guardar, se suma a `compra.total` automáticamente.
    var precio: Double

    /// Flag de sincronización con Supabase — mismo patrón que en `Compra`.
    /// `false` = pendiente de subir a la nube; `true` = sincronizado.
    var isSynced: Bool = false

    /// Referencia a la `Compra` a la que pertenece este producto.
    /// Es la relación inversa de `Compra.productos`; SwiftData la mantiene
    /// consistente automáticamente (equivalente a `@Relation` en Room).
    var compra: Compra?

    // MARK: - Inicializador

    /// Crea un nuevo producto con los datos ingresados por el usuario.
    ///
    /// - Parameters:
    ///   - codigo: Código de barras (puede ser vacío si se ingresó manualmente).
    ///   - nombre: Nombre del producto.
    ///   - descripcion: Descripción adicional (opcional).
    ///   - precio: Precio unitario en ARS.
    init(codigo: String, nombre: String, descripcion: String, precio: Double) {
        self.id = UUID()
        self.codigo = codigo
        self.nombre = nombre
        self.descripcion = descripcion
        self.precio = precio
    }
}
