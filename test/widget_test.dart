import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pothole_mobile/main.dart';
import 'package:pothole_mobile/services/onboarding_store.dart';
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

  testWidgets('Navigasi utama menampilkan HUD, riwayat, dan peta', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RoadSafeApp(
        store: const OnboardingStore(overrideCompleted: false),
        requestAccess: () async {},
        splashHold: const Duration(milliseconds: 300),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('splash-logo')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mulai Pantau Jalan Bersama'), findsOneWidget);
    expect(find.text('IZIN KAMERA', skipOffstage: false), findsOneWidget);
    expect(find.text('IZIN LOKASI PRESISI', skipOffstage: false), findsOneWidget);
    expect(find.text('JAMINAN PRIVASI UU PDP', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Izinkan Akses & Lanjutkan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Kamera HUD'), findsOneWidget);
    expect(find.text('Riwayat'), findsOneWidget);
    expect(find.text('Peta Sebaran'), findsOneWidget);
    expect(find.text('HUD CAM-01'), findsOneWidget);

    await tester.tap(find.text('Riwayat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Riwayat & Antrean'), findsOneWidget);
    expect(find.text('Jl. Pajajaran No. 45'), findsWidgets);
    expect(find.text('Sinkronkan Sekarang'), findsOneWidget);

    await tester.tap(find.text('Peta Sebaran'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Buka Navigasi Rute'), findsOneWidget);
    expect(find.text('Semua (12)'), findsWidgets);
  });
}
