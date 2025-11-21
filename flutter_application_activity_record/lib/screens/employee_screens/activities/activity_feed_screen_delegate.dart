import 'package:flutter/material.dart';

// [NEW Helper Class] สำหรับทำให้ TabBar ติดหนึบ
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => 50.0; // ความสูง TabBar (ประมาณการ)

  @override
  double get maxExtent => 50.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF5F7FA), // สีพื้นหลังตอนเลื่อนขึ้นไปชน
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
