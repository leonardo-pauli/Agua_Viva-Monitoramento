import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../entities/vibration_entity.dart';

class ExportHistoryUseCase {
  Future<String> call(List<VibrationEntity> data) async {
    // Filtrar para os últimos 5 minutos
    final fiveMinsAgo = DateTime.now().subtract(const Duration(minutes: 5));
    final recentData = data.where((e) => e.timestamp.isAfter(fiveMinsAgo)).toList();

    // Aplica filtro: por enquanto, a exportação filtrará apenas as anomalias (Atenção e Alerta) conforme solicitado
    final filteredData = recentData.where((e) => e.magnitude > 15.0).toList();

    // Cria o documento PDF
    final pdf = pw.Document();

    // Constrói as linhas da tabela
    final tableHeaders = ['Data', 'Horário', 'Vibração', 'Situação'];
    final tableData = filteredData.map((entity) {
      final dt = entity.timestamp;
      final date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      
      String situation = 'Estável';
      if (entity.magnitude > 25.0) {
        situation = 'ALERTA CRÍTICO';
      } else if (entity.magnitude > 15.0) {
        situation = 'ATENÇÃO';
      }

      return [date, time, entity.magnitude.toStringAsFixed(2), situation];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Bioglow Receptor', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 4),
              pw.Text('Relatório de Monitoramento - Últimos 5 Minutos', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 16),
            ],
          );
        },
        build: (context) {
          if (tableData.isEmpty) {
            return [
              pw.Center(
                child: pw.Text('Nenhum dado registrado nos últimos 5 minutos.', style: const pw.TextStyle(fontSize: 14)),
              ),
            ];
          }

          return [
            pw.TableHelper.fromTextArray(
              headers: tableHeaders,
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            ),
          ];
        },
        footer: (context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Gerado em: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    // O pacote 'printing' suporta Web, Windows, Android, iOS nativamente!
    // Na Web ele aciona o download do navegador. No Desktop/Mobile abre a janela de Salvar/Compartilhar.
    final bytes = await pdf.save();
    final fileName = 'bioglow_relatorio_5min_${DateTime.now().millisecondsSinceEpoch}.pdf';
    
    await Printing.sharePdf(bytes: bytes, filename: fileName);
    
    return fileName;
  }
}
