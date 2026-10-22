import 'package:flutter/material.dart';
import 'package:qradar/presentation/customer/qoin/widgets/qoin_balance_card.dart';
import 'package:qradar/presentation/customer/qoin/widgets/qoin_history_section.dart';
import 'package:qradar/presentation/customer/qoin/widgets/qoin_in_progress_banner.dart';

/// Qoin 탭. `ScaffoldWithNav` 의 IndexedStack child 이므로 자체 Scaffold/AppBar 를 두지 않는다
/// (상단은 `HomeHeader(tabbed)` 가 처리).
///
/// 세 블록이 독립 상태를 가진다: 잔액 카드(프로필 스트림) / 진행 중 배너 / 내역(원장 스트림).
/// 전부 live stream 이라 pull-to-refresh 는 없다.
class QoinPage extends StatelessWidget {
  const QoinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 110),
      children: const [
        QoinBalanceCard(),
        QoinInProgressBanner(),
        QoinHistorySection(),
      ],
    );
  }
}
