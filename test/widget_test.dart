import 'package:flutter_test/flutter_test.dart';
import 'package:pothole_mobile/main.dart';
import 'package:pothole_mobile/models/pothole_report.dart';
import 'package:pothole_mobile/services/mock_data.dart';

void main() {
  test('Sampel mobile mengikuti skor dan antrean UI-M02', () {
    expect(mockReports, hasLength(12));
    expect(queuedReportCount, 3);
    expect(syncedReportCount, 9);

    final pajajaran = mockReports.first;
    expect(pajajaran.street, 'Jl. Pajajaran No. 45');
    expect(pajajaran.score, 78.4);
    expect(pajajaran.category, ReportCategory.high);
    expect(pajajaran.status, ReportStatus.menungguSinyal);
    expect(mockReports[1].score, 52.0);
    expect(mockReports[3].score, 22.5);
    expect(mockReports[3].category, ReportCategory.low);
  });

  testWidgets('Navigasi utama menampilkan tiga tab UI-M02', (tester) async {
    await tester.pumpWidget(const RoadSafeApp());

    expect(find.text('Kamera HUD'), findsWidgets);
    expect(find.text('Riwayat'), findsOneWidget);
    expect(find.text('Peta Sebaran'), findsOneWidget);

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('12 laporan sampel'), findsOneWidget);

    await tester.tap(find.text('Peta Sebaran'));
    await tester.pumpAndSettle();
    expect(find.textContaining('12 titik sampel'), findsOneWidget);
  });
}
