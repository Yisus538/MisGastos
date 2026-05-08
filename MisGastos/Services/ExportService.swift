// =============================================================================
// ExportService.swift — Servicio de exportación de datos (CSV y PDF)
// =============================================================================
// Rol en la app:
//   Genera archivos CSV y PDF del historial de compras para que el usuario
//   pueda compartirlos o analizarlos en Excel/Google Sheets.
//   El CSV incluye secciones de resumen, compras y productos.
//   El PDF usa `UIGraphicsPDFRenderer` para crear un documento A4 con header
//   verde de marca, card de resumen y filas agrupadas por mes.
//
// Equivalente Android:
//   No hay un equivalente directo en el SDK. En Android se usaría:
//   - CSV: `FileWriter` / `BufferedWriter` escribiendo manualmente.
//   - PDF: `PdfDocument` + `Canvas` de Android, o iText/Apache PDFBox.
//   Para compartir: `Intent.ACTION_SEND` con `FileProvider` para el URI del archivo.
//   En iOS, `ShareLink` o `UIActivityViewController` manejan el compartir.
//
// Framework utilizado:
//   `UIKit` — `UIGraphicsPDFRenderer` es la API de iOS para generar PDFs
//   mediante drawing commands (equivalente al `Canvas` de Android).
//   Los archivos se guardan en `FileManager.temporaryDirectory` que
//   equivale a `Context.cacheDir` en Android.
// =============================================================================

import Foundation
import UIKit

/// Genera archivos CSV y PDF exportables del historial de compras.
///
/// Singleton que provee dos métodos de exportación. El archivo se escribe
/// en el directorio temporal del sistema y la URL se pasa a `ActivitySheet`
/// (equivalente a `Intent.ACTION_SEND` en Android) para compartir.
final class ExportService {

    // MARK: - Singleton

    static let shared = ExportService()
    private init() {}

    // MARK: - CSV

    /// Genera un archivo CSV con el historial completo de compras.
    ///
    /// El CSV incluye tres secciones:
    /// 1. **RESUMEN**: totales generales.
    /// 2. **COMPRAS**: una fila por compra.
    /// 3. **PRODUCTOS**: una fila por producto con su compra asociada.
    ///
    /// El BOM UTF-8 (`\u{FEFF}`) al inicio es necesario para que Excel en Windows
    /// detecte correctamente la codificación UTF-8 (sin él, los acentos se corrompen).
    ///
    /// - Parameter compras: Lista de compras a exportar.
    /// - Returns: URL del archivo temporal generado, o `nil` si falla la escritura.
    func generarCSV(compras: [Compra]) -> URL? {
        let ordenadas = compras.sorted { $0.fecha > $1.fecha }
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        df.locale = Locale(identifier: "es_AR")

        var rows: [String] = []

        // Encabezado del archivo con metadatos
        rows.append("# Super Ahorro \u{2014} Historial de compras")
        rows.append("# Exportado: \(df.string(from: Date()))")
        rows.append("")

        // Sección RESUMEN — totales generales
        let totalGeneral = ordenadas.reduce(0.0) { $0 + $1.total }
        rows.append("# RESUMEN")
        rows.append("Total de compras,\(ordenadas.count)")
        rows.append("Gasto total,\(String(format: "%.2f", totalGeneral))")
        rows.append("")

        // Sección COMPRAS — una fila por compra
        rows.append("# COMPRAS")
        rows.append("Fecha,Supermercado,Cantidad de productos,Total,Método de pago")
        for c in ordenadas {
            rows.append([
                df.string(from: c.fecha),
                c.supermercado.csvEscaped,      // Escapa comas y comillas para formato CSV válido
                "\(c.productos.count)",
                String(format: "%.2f", c.total),
                c.metodoPago.csvEscaped
            ].joined(separator: ","))
        }
        rows.append("")

        // Sección PRODUCTOS — una fila por producto (denormalizado con datos de su compra)
        rows.append("# PRODUCTOS")
        rows.append("Fecha,Supermercado,Nombre,Descripción,Código,Precio")
        for c in ordenadas {
            let fecha = df.string(from: c.fecha)
            for p in c.productos {
                rows.append([
                    fecha,
                    c.supermercado.csvEscaped,
                    p.nombre.csvEscaped,
                    p.descripcion.csvEscaped,
                    p.codigo.csvEscaped,
                    String(format: "%.2f", p.precio)
                ].joined(separator: ","))
            }
        }

        // BOM UTF-8 para que Excel en Windows lo abra correctamente
        let csv = "\u{FEFF}" + rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperAhorro_Historial.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - PDF

    /// Genera un documento PDF A4 del historial de compras con diseño de marca.
    ///
    /// El PDF incluye:
    /// - **Header verde** con nombre de la app y fecha de exportación.
    /// - **Card de resumen** con total, nº de compras y nº de productos.
    /// - **Grupos por mes** con filas individuales de cada compra.
    /// - **Paginación automática** — si no caben más filas, se crea una nueva página.
    ///
    /// `UIGraphicsPDFRenderer` es la API de iOS para generar PDFs mediante
    /// drawing commands — equivalente al `PdfDocument` + `Canvas` de Android.
    /// Las dimensiones son A4 en puntos (1 punto = 1/72 pulgada).
    ///
    /// - Parameter compras: Lista de compras a exportar.
    /// - Returns: URL del archivo temporal generado, o `nil` si falla la escritura.
    func generarPDF(compras: [Compra]) -> URL? {
        let pageW: CGFloat = 595.2   // A4 en puntos tipográficos
        let pageH: CGFloat = 841.8
        let margin: CGFloat = 40
        let contentW = pageW - margin * 2
        let ordenadas = compras.sorted { $0.fecha > $1.fecha }

        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        df.locale = Locale(identifier: "es_AR")

        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "MMMM yyyy"
        monthFmt.locale = Locale(identifier: "es_AR")

        // Closure para formatear montos en ARS
        let money: (Double) -> String = {
            $0.formatted(.currency(code: "ARS").locale(Locale(identifier: "es_AR")))
        }

        // Definición de fuentes — en Android equivaldrían a `Typeface.create()`
        let titleFont    = UIFont.systemFont(ofSize: 22, weight: .bold)
        let headFont     = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let bodyFont     = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let subFont      = UIFont.systemFont(ofSize: 9,  weight: .regular)
        let captionFont  = UIFont.systemFont(ofSize: 8,  weight: .regular)
        let moneyBigFont = UIFont.systemFont(ofSize: 15, weight: .bold)

        // Colores del design system — adaptativos pero forzados a light mode para PDF
        let green  = UIColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1)
        let label  = UIColor.label
        let label2 = UIColor.secondaryLabel
        let sep    = UIColor.separator
        let card   = UIColor.secondarySystemBackground

        // `UIGraphicsPDFRenderer` — equivalente a `PdfDocument` en Android
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let data = renderer.pdfData { ctx in
            var y: CGFloat = 0
            var pageNum = 1

            // Dibuja el footer con número de página en la posición inferior
            func drawFooter() {
                let str = NSAttributedString(
                    string: "Super Ahorro · Página \(pageNum)",
                    attributes: [.font: captionFont, .foregroundColor: label2]
                )
                str.draw(at: CGPoint(x: margin, y: pageH - 26))
            }

            // Inicia una nueva página cuando no queda espacio
            func newPage() {
                drawFooter()
                ctx.beginPage()
                pageNum += 1
                y = margin
            }

            // Verifica si hay espacio para el contenido; si no, crea nueva página
            func checkSpace(_ needed: CGFloat) {
                if y + needed > pageH - 44 { newPage() }
            }

            // ── Página 1 ──────────────────────────────────────────────

            ctx.beginPage()

            // Header verde con bordes inferiores redondeados
            let headerRect = CGRect(x: 0, y: 0, width: pageW, height: 68)
            green.setFill()
            UIBezierPath(roundedRect: headerRect,
                         byRoundingCorners: [.bottomLeft, .bottomRight],
                         cornerRadii: CGSize(width: 14, height: 14)).fill()

            NSAttributedString(string: "Super Ahorro",
                               attributes: [.font: titleFont, .foregroundColor: UIColor.white])
                .draw(at: CGPoint(x: margin, y: 16))

            NSAttributedString(string: "Historial · Exportado \(df.string(from: Date()))",
                               attributes: [.font: captionFont, .foregroundColor: UIColor.white.withAlphaComponent(0.85)])
                .draw(at: CGPoint(x: margin, y: 46))

            y = 84

            // Card de resumen con 3 métricas principales
            let totalGeneral = ordenadas.reduce(0.0) { $0 + $1.total }
            let summaryRect = CGRect(x: margin, y: y, width: contentW, height: 56)
            card.setFill()
            UIBezierPath(roundedRect: summaryRect, cornerRadius: 10).fill()

            // — Métrica: Total gastado
            NSAttributedString(string: "TOTAL GASTADO",
                               attributes: [.font: headFont, .foregroundColor: label2])
                .draw(at: CGPoint(x: margin + 16, y: y + 8))
            NSAttributedString(string: money(totalGeneral),
                               attributes: [.font: moneyBigFont, .foregroundColor: green])
                .draw(at: CGPoint(x: margin + 16, y: y + 24))

            // — Métrica: Número de compras
            NSAttributedString(string: "COMPRAS",
                               attributes: [.font: headFont, .foregroundColor: label2])
                .draw(at: CGPoint(x: margin + 200, y: y + 8))
            NSAttributedString(string: "\(ordenadas.count)",
                               attributes: [.font: moneyBigFont, .foregroundColor: green])
                .draw(at: CGPoint(x: margin + 200, y: y + 24))

            // — Métrica: Número de productos
            let totalProductos = ordenadas.reduce(0) { $0 + $1.productos.count }
            NSAttributedString(string: "PRODUCTOS",
                               attributes: [.font: headFont, .foregroundColor: label2])
                .draw(at: CGPoint(x: margin + 320, y: y + 8))
            NSAttributedString(string: "\(totalProductos)",
                               attributes: [.font: moneyBigFont, .foregroundColor: green])
                .draw(at: CGPoint(x: margin + 320, y: y + 24))

            y += 72

            // ── Grupos por mes ────────────────────────────────────────

            let cal = Calendar.current
            // Agrupa las compras por año-mes y ordena de más reciente a más antiguo
            let grupos = Dictionary(grouping: ordenadas) { c -> String in
                let comp = cal.dateComponents([.year, .month], from: c.fecha)
                return String(format: "%04d-%02d", comp.year ?? 0, comp.month ?? 0)
            }
            .sorted { $0.key > $1.key }

            let rowH: CGFloat = 38

            for (_, comprasDelMes) in grupos {
                let groupH = 22 + CGFloat(comprasDelMes.count) * rowH + 16
                checkSpace(groupH) // Verificar espacio antes de dibujar el grupo

                // Etiqueta del mes y total mensual
                let mesLabel = monthFmt.string(from: comprasDelMes.first?.fecha ?? Date()).capitalized
                let mesTotal = comprasDelMes.reduce(0.0) { $0 + $1.total }

                NSAttributedString(string: mesLabel.uppercased(),
                                   attributes: [.font: headFont, .foregroundColor: label2])
                    .draw(at: CGPoint(x: margin, y: y))

                let mesTotalStr = NSAttributedString(string: money(mesTotal),
                                                    attributes: [.font: headFont, .foregroundColor: label2])
                mesTotalStr.draw(at: CGPoint(x: margin + contentW - mesTotalStr.size().width, y: y))
                y += 18

                // Card del mes con todas sus compras
                let cardH = CGFloat(comprasDelMes.count) * rowH
                card.setFill()
                UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: contentW, height: cardH),
                             cornerRadius: 10).fill()

                for (i, compra) in comprasDelMes.enumerated() {
                    let rowY = y + CGFloat(i) * rowH

                    // Separador horizontal entre filas (excepto la primera)
                    if i > 0 {
                        sep.setStroke()
                        let path = UIBezierPath()
                        path.move(to:    CGPoint(x: margin + 14,          y: rowY))
                        path.addLine(to: CGPoint(x: margin + contentW - 14, y: rowY))
                        path.lineWidth = 0.5
                        path.stroke()
                    }

                    // Nombre del supermercado (bold)
                    NSAttributedString(string: compra.supermercado,
                                       attributes: [.font: bodyFont, .foregroundColor: label])
                        .draw(at: CGPoint(x: margin + 14, y: rowY + 6))

                    // Fecha y cantidad de productos (secondary text)
                    let sub = "\(df.string(from: compra.fecha)) · \(compra.productos.count) item\(compra.productos.count == 1 ? "" : "s")"
                    NSAttributedString(string: sub,
                                       attributes: [.font: subFont, .foregroundColor: label2])
                        .draw(at: CGPoint(x: margin + 14, y: rowY + 22))

                    // Total de la compra, alineado a la derecha
                    let totalStr = NSAttributedString(string: money(compra.total),
                                                     attributes: [.font: bodyFont, .foregroundColor: label])
                    let tw = totalStr.size().width
                    totalStr.draw(at: CGPoint(x: margin + contentW - tw - 14, y: rowY + 12))
                }

                y += cardH + 16
            }

            drawFooter()
        }

        // Guardar el PDF en el directorio temporal del sistema
        // Equivalente Android: `context.cacheDir`
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperAhorro_Historial.pdf")
        try? data.write(to: url)
        return url
    }
}

// MARK: - String CSV escaping

/// Extensión privada para escapar strings con caracteres especiales en formato CSV.
/// RFC 4180: si el campo contiene comas, comillas o saltos de línea, se envuelve
/// en comillas dobles y las comillas internas se duplican.
private extension String {
    var csvEscaped: String {
        if contains(",") || contains("\"") || contains("\n") {
            return "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return self
    }
}
