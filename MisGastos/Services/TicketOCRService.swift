// =============================================================================
// TicketOCRService.swift — Servicio OCR para extracción de productos de tickets
// =============================================================================
// Rol en la app:
//   Recibe la imagen de un ticket de supermercado (como Data JPEG) y extrae
//   automáticamente la lista de productos con sus precios usando Vision OCR.
//   El resultado se muestra en `NuevaCompraView` para que el usuario confirme
//   o edite los productos antes de guardar la compra.
//
// Equivalente Android:
//   ML Kit Text Recognition (Google) — `TextRecognizer` con `InputImage`.
//   En Android: `TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)`
//   .process(inputImage).addOnSuccessListener { visionText -> parsear(visionText) }
//   En iOS: `VNRecognizeTextRequest` con `VNImageRequestHandler`. Ambos usan
//   modelos de ML en el dispositivo, sin enviar datos a la nube (privacidad).
//
// Framework: Vision de Apple
//   `VNRecognizeTextRequest` con `.accurate` mode usa un modelo LSTM (red neuronal
//   recurrente) entrenado en Apple Silicon. Disponible desde iOS 13.
//   Funciona 100% on-device, sin internet, respetando la privacidad del usuario.
//
// Desafíos del parsing de tickets:
//   Los tickets argentinos no tienen un formato estándar entre supermercados.
//   La estrategia es buscar líneas con precio al final ($189.99, 1.234,56, etc.)
//   y filtrar líneas de totales/impuestos con palabras clave conocidas.
// =============================================================================

import Foundation
import Vision
import UIKit

/// Modelo borrador de producto, usado en NuevaCompraView antes de persistir en SwiftData.
///
/// Es un struct value type (no una clase) porque se pasa por valor entre vistas
/// y no requiere identidad de referencia. `Identifiable` permite usarlo en `ForEach`.
/// Equivalente Android: data class local antes de guardar en Room.
struct ProductoDraft: Identifiable, Equatable {
    var id = UUID()
    var nombre: String
    var descripcion: String = ""
    var codigo: String = ""
    var precio: Double
}

/// Extrae productos y precios de la imagen de un ticket usando Vision OCR.
///
/// Singleton para reutilizar la configuración del request de OCR.
/// Equivalente Android: `TextRecognizer` de ML Kit con `.DEFAULT_OPTIONS`.
final class TicketOCRService {

    // MARK: - Singleton

    static let shared = TicketOCRService()
    private init() {}

    // MARK: - Extracción principal

    /// Procesa una imagen de ticket y extrae los productos con sus precios.
    ///
    /// El reconocimiento OCR se ejecuta en background (no bloquea la UI).
    /// `withCheckedContinuation` convierte el API callback-based de Vision
    /// en una función `async/await` — equivalente Android a `suspendCoroutine { cont -> }`.
    ///
    /// - Parameter imageData: Imagen del ticket en formato JPEG/PNG como Data.
    /// - Returns: Array de `ProductoDraft` con los productos detectados.
    func extraerProductos(de imageData: Data) async -> [ProductoDraft] {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            // `VNRecognizeTextRequest` es la API de Vision para OCR — equivalente
            // Android al `TextRecognizer` de ML Kit.
            let request = VNRecognizeTextRequest { req, _ in
                // Extraer el texto de mayor confianza de cada bloque reconocido
                let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: Self.parsear(lines))
            }
            // `.accurate` usa el modelo completo de red neuronal (más lento pero mejor)
            // `.fast` usa el modelo ligero (ideal para tiempo real, menos preciso)
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es-ES", "en-US"]
            // Desactivar corrección de lenguaje para preservar precios y códigos exactos
            request.usesLanguageCorrection = false
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }

    // MARK: - Palabras a ignorar (totales, impuestos, etc.)

    /// Palabras clave que identifican líneas de NO-producto en el ticket.
    /// Si una línea contiene alguna de estas palabras, se descarta.
    /// Esto filtra totales, subtotales, IVA, descuentos, datos del local, etc.
    private static let skipWords = [
        "total", "subtotal", "iva", "descuento", "bonif", "dto",
        "cambio", "vuelto", "efectivo", "tarjeta", "credito", "debito",
        "visa", "master", "amex", "naranja", "ticket", "recibo",
        "cuit", "cai", "gracias", "fecha", "hora", "caja", "cajero", "sucursal"
    ]

    // MARK: - Regex de precios

    /// Expresión regular que detecta un precio al final de una línea.
    /// Formatos soportados: `$189.99`, `189,99`, `$1.234,56`, `1234.56`.
    /// El grupo de captura `()` extrae solo el número, sin el símbolo `$`.
    private static let priceRegex: NSRegularExpression = {
        let p = "\\$?\\s*(\\d{1,3}(?:[,.]\\d{3})*[,.]\\d{2}|\\d{1,6}[,.]\\d{2})\\s*$"
        return try! NSRegularExpression(pattern: p)
    }()

    // MARK: - Parsing de líneas

    /// Parsea el array de líneas OCR y extrae productos con precios.
    ///
    /// Maneja dos formatos de tickets:
    /// 1. **Formato en una línea**: `LECHE ENTERA 1L          $180,00`
    /// 2. **Formato en dos líneas**: `LECHE ENTERA 1L` (línea 1) + `180,00` (línea 2)
    ///
    /// El precio rango `(0.5, 500_000)` filtra precios irreales (demasiado baratos o caros).
    ///
    /// - Parameter lines: Líneas de texto detectadas por Vision OCR.
    /// - Returns: Array de `ProductoDraft` con los productos detectados.
    private static func parsear(_ lines: [String]) -> [ProductoDraft] {
        var resultados: [ProductoDraft] = []
        var i = 0
        while i < lines.count {
            let linea = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            i += 1
            // Filtrar líneas muy cortas (menos de 3 caracteres)
            guard linea.count >= 3 else { continue }
            let lower = linea.lowercased()
            // Descartar líneas de totales, impuestos, datos del local, etc.
            guard !skipWords.contains(where: { lower.contains($0) }) else { continue }

            if let (nombre, precio) = extraerNombreYPrecio(de: linea) {
                // Formato en una línea: nombre + precio en la misma línea
                let limpio = limpiarNombre(nombre)
                guard limpio.count >= 2,
                      limpio.contains(where: { $0.isLetter }),   // Debe tener al menos una letra
                      precio > 0.5, precio < 500_000 else { continue }
                resultados.append(ProductoDraft(nombre: limpio.capitalized, precio: precio))
            } else if i < lines.count {
                // Formato en dos líneas: intentar con la línea siguiente como precio
                let nextLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                if let precio = parsearSoloPrecio(nextLine), precio > 0.5, precio < 500_000 {
                    let limpio = limpiarNombre(linea)
                    if limpio.count >= 2, limpio.contains(where: { $0.isLetter }) {
                        resultados.append(ProductoDraft(nombre: limpio.capitalized, precio: precio))
                        i += 1  // Consumir la línea del precio
                    }
                }
            }
        }
        return resultados
    }

    // MARK: - Helpers de parsing

    /// Extrae el nombre y precio de una línea que tiene ambos.
    ///
    /// Usa el regex `priceRegex` para encontrar el precio al final de la línea.
    /// El nombre es todo lo que está antes del precio.
    ///
    /// - Returns: Tupla (nombre, precio) o `nil` si la línea no tiene precio al final.
    private static func extraerNombreYPrecio(de linea: String) -> (String, Double)? {
        let nsLinea = linea as NSString
        guard let match = priceRegex.firstMatch(in: linea, range: NSRange(location: 0, length: nsLinea.length)),
              match.numberOfRanges > 1 else { return nil }
        let captureRange = match.range(at: 1)
        guard captureRange.location != NSNotFound,
              let swiftCapture = Range(captureRange, in: linea),
              let swiftMatch = Range(match.range, in: linea) else { return nil }
        guard let precio = parsearMonto(String(linea[swiftCapture])) else { return nil }
        let nombre = String(linea[linea.startIndex..<swiftMatch.lowerBound])
        return (nombre, precio)
    }

    /// Intenta parsear una línea que contiene SOLO un precio (formato dos líneas).
    ///
    /// - Parameter s: String con el precio (ej: "$180,00" o "1.234,56").
    /// - Returns: El precio como Double, o `nil` si no es un precio válido.
    private static func parsearSoloPrecio(_ s: String) -> Double? {
        let clean = s.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        return parsearMonto(clean)
    }

    /// Interpreta formatos de moneda argentinos y los convierte a Double.
    ///
    /// Formatos soportados:
    /// - `"1.234,56"` — punto=miles, coma=decimal (formato estándar ARS).
    /// - `"1234,56"` — coma=decimal (sin separador de miles).
    /// - `"1234.56"` — punto=decimal (formato inglés, algunos tickets lo usan).
    ///
    /// - Parameter raw: String con el monto a parsear.
    /// - Returns: El monto como Double, o `nil` si no se puede parsear.
    private static func parsearMonto(_ raw: String) -> Double? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }

        // Formato "1.234,56": punto=separador de miles, coma=decimal
        if s.contains(","), s.contains("."),
           let commaIdx = s.lastIndex(of: ","),
           let dotIdx = s.lastIndex(of: "."),
           commaIdx > dotIdx {
            let n = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            return Double(n)
        }

        // Formato "1234,56": solo coma como separador decimal
        if s.contains(",") && !s.contains(".") {
            return Double(s.replacingOccurrences(of: ",", with: "."))
        }

        // Formato "1234.56": punto decimal estándar (inglés)
        return Double(s)
    }

    /// Limpia el nombre del producto detectado.
    ///
    /// Elimina prefijos de cantidad al inicio de la línea del tipo "2 x " o "3X ".
    /// Normaliza espacios dobles y espacios al inicio/final.
    ///
    /// Ejemplos:
    /// - `"2 x LECHE ENTERA"` → `"LECHE ENTERA"`
    /// - `"  JABÓN DOVE  "` → `"JABÓN DOVE"`
    private static func limpiarNombre(_ s: String) -> String {
        var result = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Regex para detectar patrones como "2 x ", "3X ", al inicio de la línea
        if let range = result.range(of: #"^\d+\s*[xX]\s+"#, options: .regularExpression) {
            result = String(result[range.upperBound...])
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }
}
