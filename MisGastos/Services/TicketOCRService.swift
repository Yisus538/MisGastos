import Foundation
import Vision
import UIKit

/// Modelo borrador de producto, usado en NuevaCompraView antes de persistir en SwiftData.
struct ProductoDraft: Identifiable, Equatable {
    var id = UUID()
    var nombre: String
    var descripcion: String = ""
    var codigo: String = ""
    var precio: Double
}

/// Extrae productos y precios de la imagen de un ticket usando Vision OCR.
final class TicketOCRService {
    static let shared = TicketOCRService()
    private init() {}

    func extraerProductos(de imageData: Data) async -> [ProductoDraft] {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: Self.parsear(lines))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es-ES", "en-US"]
            request.usesLanguageCorrection = false
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }

    private static let skipWords = [
        "total", "subtotal", "iva", "descuento", "bonif", "dto",
        "cambio", "vuelto", "efectivo", "tarjeta", "credito", "debito",
        "visa", "master", "amex", "naranja", "ticket", "recibo",
        "cuit", "cai", "gracias", "fecha", "hora", "caja", "cajero", "sucursal"
    ]

    // Matches price at end of line: $189.99, 189,99, $1.234,56, 1234.56
    private static let priceRegex: NSRegularExpression = {
        let p = "\\$?\\s*(\\d{1,3}(?:[,.]\\d{3})*[,.]\\d{2}|\\d{1,6}[,.]\\d{2})\\s*$"
        return try! NSRegularExpression(pattern: p)
    }()

    private static func parsear(_ lines: [String]) -> [ProductoDraft] {
        var resultados: [ProductoDraft] = []
        var i = 0
        while i < lines.count {
            let linea = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            i += 1
            guard linea.count >= 3 else { continue }
            let lower = linea.lowercased()
            guard !skipWords.contains(where: { lower.contains($0) }) else { continue }

            if let (nombre, precio) = extraerNombreYPrecio(de: linea) {
                let limpio = limpiarNombre(nombre)
                guard limpio.count >= 2,
                      limpio.contains(where: { $0.isLetter }),
                      precio > 0.5, precio < 500_000 else { continue }
                resultados.append(ProductoDraft(nombre: limpio.capitalized, precio: precio))
            } else if i < lines.count {
                // Two-line format: name on one line, price on the next
                let nextLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                if let precio = parsearSoloPrecio(nextLine), precio > 0.5, precio < 500_000 {
                    let limpio = limpiarNombre(linea)
                    if limpio.count >= 2, limpio.contains(where: { $0.isLetter }) {
                        resultados.append(ProductoDraft(nombre: limpio.capitalized, precio: precio))
                        i += 1
                    }
                }
            }
        }
        return resultados
    }

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

    private static func parsearSoloPrecio(_ s: String) -> Double? {
        let clean = s.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        return parsearMonto(clean)
    }

    /// Interpreta formatos ARS: "1.234,56", "1234,56", "1234.56"
    private static func parsearMonto(_ raw: String) -> Double? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        // "1.234,56" — punto=miles, coma=decimal
        if s.contains(","), s.contains("."),
           let commaIdx = s.lastIndex(of: ","),
           let dotIdx = s.lastIndex(of: "."),
           commaIdx > dotIdx {
            let n = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            return Double(n)
        }
        // "1234,56" — coma=decimal
        if s.contains(",") && !s.contains(".") {
            return Double(s.replacingOccurrences(of: ",", with: "."))
        }
        return Double(s)
    }

    private static func limpiarNombre(_ s: String) -> String {
        var result = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = result.range(of: #"^\d+\s*[xX]\s+"#, options: .regularExpression) {
            result = String(result[range.upperBound...])
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }
}
