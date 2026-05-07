
import Foundation
import UIKit

/// Genera archivos CSV y PDF exportables del historial de compras.
final class ExportService {
    static let shared = ExportService()
    private init() {}

    // MARK: - CSV

    func generarCSV(compras: [Compra]) -> URL? {
        let ordenadas = compras.sorted { $0.fecha > $1.fecha }
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        df.locale = Locale(identifier: "es_AR")

        var rows: [String] = []

        // Encabezado del archivo
        rows.append("# Super Ahorro \u{2014} Historial de compras")
        rows.append("# Exportado: \(df.string(from: Date()))")
        rows.append("")

        // Resumen
        let totalGeneral = ordenadas.reduce(0.0) { $0 + $1.total }
        rows.append("# RESUMEN")
        rows.append("Total de compras,\(ordenadas.count)")
        rows.append("Gasto total,\(String(format: "%.2f", totalGeneral))")
        rows.append("")

        // Tabla de compras
        rows.append("# COMPRAS")
        rows.append("Fecha,Supermercado,Cantidad de productos,Total,Método de pago")
        for c in ordenadas {
            rows.append([
                df.string(from: c.fecha),
                c.supermercado.csvEscaped,
                "\(c.productos.count)",
                String(format: "%.2f", c.total),
                c.metodoPago.csvEscaped
            ].joined(separator: ","))
        }
        rows.append("")

        // Tabla de productos
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

        // BOM UTF-8 para que Excel lo abra bien
        let csv = "\u{FEFF}" + rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperAhorro_Historial.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - PDF

    func generarPDF(compras: [Compra]) -> URL? {
        let pageW: CGFloat = 595.2   // A4
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

        let money: (Double) -> String = {
            $0.formatted(.currency(code: "ARS").locale(Locale(identifier: "es_AR")))
        }

        // Fonts
        let titleFont    = UIFont.systemFont(ofSize: 22, weight: .bold)
        let headFont     = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let bodyFont     = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let subFont      = UIFont.systemFont(ofSize: 9,  weight: .regular)
        let captionFont  = UIFont.systemFont(ofSize: 8,  weight: .regular)
        let moneyBigFont = UIFont.systemFont(ofSize: 15, weight: .bold)

        // Colors
        let green  = UIColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1)
        let label  = UIColor.label
        let label2 = UIColor.secondaryLabel
        let sep    = UIColor.separator
        let card   = UIColor.secondarySystemBackground

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let data = renderer.pdfData { ctx in
            var y: CGFloat = 0
            var pageNum = 1

            func drawFooter() {
                let str = NSAttributedString(
                    string: "Super Ahorro · Página \(pageNum)",
                    attributes: [.font: captionFont, .foregroundColor: label2]
                )
                str.draw(at: CGPoint(x: margin, y: pageH - 26))
            }

            func newPage() {
                drawFooter()
                ctx.beginPage()
                pageNum += 1
                y = margin
            }

            func checkSpace(_ needed: CGFloat) {
                if y + needed > pageH - 44 { newPage() }
            }

            // ── Página 1 ──────────────────────────────────────────────

            ctx.beginPage()

            // Header verde
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

            // Card de resumen
            let totalGeneral = ordenadas.reduce(0.0) { $0 + $1.total }
            let summaryRect = CGRect(x: margin, y: y, width: contentW, height: 56)
            card.setFill()
            UIBezierPath(roundedRect: summaryRect, cornerRadius: 10).fill()

            // — Total gastado
            NSAttributedString(string: "TOTAL GASTADO",
                               attributes: [.font: headFont, .foregroundColor: label2])
                .draw(at: CGPoint(x: margin + 16, y: y + 8))
            NSAttributedString(string: money(totalGeneral),
                               attributes: [.font: moneyBigFont, .foregroundColor: green])
                .draw(at: CGPoint(x: margin + 16, y: y + 24))

            // — Compras
            NSAttributedString(string: "COMPRAS",
                               attributes: [.font: headFont, .foregroundColor: label2])
                .draw(at: CGPoint(x: margin + 200, y: y + 8))
            NSAttributedString(string: "\(ordenadas.count)",
                               attributes: [.font: moneyBigFont, .foregroundColor: green])
                .draw(at: CGPoint(x: margin + 200, y: y + 24))

            // — Productos
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
            let grupos = Dictionary(grouping: ordenadas) { c -> String in
                let comp = cal.dateComponents([.year, .month], from: c.fecha)
                return String(format: "%04d-%02d", comp.year ?? 0, comp.month ?? 0)
            }
            .sorted { $0.key > $1.key }

            let rowH: CGFloat = 38

            for (_, comprasDelMes) in grupos {
                let groupH = 22 + CGFloat(comprasDelMes.count) * rowH + 16
                checkSpace(groupH)

                // Mes label
                let mesLabel = monthFmt.string(from: comprasDelMes.first?.fecha ?? Date()).capitalized
                let mesTotal = comprasDelMes.reduce(0.0) { $0 + $1.total }

                NSAttributedString(string: mesLabel.uppercased(),
                                   attributes: [.font: headFont, .foregroundColor: label2])
                    .draw(at: CGPoint(x: margin, y: y))

                let mesTotalStr = NSAttributedString(string: money(mesTotal),
                                                    attributes: [.font: headFont, .foregroundColor: label2])
                mesTotalStr.draw(at: CGPoint(x: margin + contentW - mesTotalStr.size().width, y: y))
                y += 18

                // Card del mes
                let cardH = CGFloat(comprasDelMes.count) * rowH
                card.setFill()
                UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: contentW, height: cardH),
                             cornerRadius: 10).fill()

                for (i, compra) in comprasDelMes.enumerated() {
                    let rowY = y + CGFloat(i) * rowH

                    // Separador entre filas
                    if i > 0 {
                        sep.setStroke()
                        let path = UIBezierPath()
                        path.move(to:    CGPoint(x: margin + 14,          y: rowY))
                        path.addLine(to: CGPoint(x: margin + contentW - 14, y: rowY))
                        path.lineWidth = 0.5
                        path.stroke()
                    }

                    // Tienda
                    NSAttributedString(string: compra.supermercado,
                                       attributes: [.font: bodyFont, .foregroundColor: label])
                        .draw(at: CGPoint(x: margin + 14, y: rowY + 6))

                    // Fecha · items
                    let sub = "\(df.string(from: compra.fecha)) · \(compra.productos.count) item\(compra.productos.count == 1 ? "" : "s")"
                    NSAttributedString(string: sub,
                                       attributes: [.font: subFont, .foregroundColor: label2])
                        .draw(at: CGPoint(x: margin + 14, y: rowY + 22))

                    // Total alineado a la derecha
                    let totalStr = NSAttributedString(string: money(compra.total),
                                                     attributes: [.font: bodyFont, .foregroundColor: label])
                    let tw = totalStr.size().width
                    totalStr.draw(at: CGPoint(x: margin + contentW - tw - 14, y: rowY + 12))
                }

                y += cardH + 16
            }

            drawFooter()
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperAhorro_Historial.pdf")
        try? data.write(to: url)
        return url
    }
}

// MARK: - String CSV escaping

private extension String {
    var csvEscaped: String {
        if contains(",") || contains("\"") || contains("\n") {
            return "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return self
    }
}
