import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'models.dart';
import 'qr_scanner_screen.dart';
import 'dart:convert';
import '../profile/organizer_profile_screen.dart';

class ParticipantsDetailsScreen extends StatefulWidget {
  final ActivitySummary activity;
  final bool isJoinedView;
  const ParticipantsDetailsScreen({super.key, required this.activity, this.isJoinedView = false});

  @override
  State<ParticipantsDetailsScreen> createState() =>
      _ParticipantsDetailsScreenState();
}

class _ParticipantsDetailsScreenState extends State<ParticipantsDetailsScreen> {
  bool _descExpanded = false;

  final List<_Person> _registered = [
    _Person(
      id: 'emp001',
      name: 'Karen Den',
      imageUrl: 'https://i.pravatar.cc/150?img=1',
    ),
    _Person(
      id: 'emp002',
      name: 'Knoop Jain',
      imageUrl: 'https://i.pravatar.cc/150?img=2',
    ),
    _Person(
      id: 'emp003',
      name: 'Ashley Hills',
      imageUrl: 'https://i.pravatar.cc/150?img=3',
    ),
  ];
  final List<_Person> _joined = [
    _Person(
      id: 'emp010',
      name: 'John Baker',
      imageUrl: 'https://i.pravatar.cc/150?img=4',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: organizerBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildActivityInfo(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      floatingActionButton: widget.isJoinedView
          ? null
          : SafeArea(
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF4A80FF),
                  onPressed: _scanStub,
                  child: const Icon(Icons.qr_code_scanner, color: Colors.white),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrganizerProfileScreen(),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: const NetworkImage(
                    'https://i.pravatar.cc/150?img=32',
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                'Participants',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF375987),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.black54,
                  size: 28,
                ),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  

  Widget _buildActivityInfo() {
    final dateText =
        '${widget.activity.date.year}-${widget.activity.date.month.toString().padLeft(2, '0')}-${widget.activity.date.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.1)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Color(0xFF375987),
                    ),
                    const SizedBox(width: 8),
                    Text(dateText, style: GoogleFonts.poppins()),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Color(0xFF375987),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.activity.location,
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _descExpanded ? _longDesc : _shortDesc,
                  style: GoogleFonts.poppins(color: Colors.black87),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _descExpanded = !_descExpanded),
                    child: Text(
                      _descExpanded ? 'less' : 'more',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.isJoinedView ? 'Joined Participants' : 'Registered Participants',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildList() {
    final items = widget.isJoinedView ? _joined : _registered;
    return ListView.builder(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        bottom: 16.0 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final p = items[index];
        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(p.imageUrl),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(p.name, style: GoogleFonts.poppins())),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scanStub() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result == null || result.isEmpty) return;
    String? empId;
    int? actIdInCode;
    try {
      final data = json.decode(result);
      if (data is Map) {
        empId = (data['emp_id'] ?? data['employee_id'] ?? data['empId'])?.toString();
        final aid = data['act_id'] ?? data['activity_id'] ?? data['actId'];
        if (aid != null) actIdInCode = int.tryParse(aid.toString());
      }
    } catch (_) {
      empId = result.trim();
    }
    if (actIdInCode != null && actIdInCode != widget.activity.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กิจกรรมไม่ตรงกัน', style: GoogleFonts.poppins())),
      );
      return;
    }
    if (empId == null || empId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR ไม่ถูกต้อง', style: GoogleFonts.poppins())),
      );
      return;
    }
    final already = _joined.any((e) => e.id == empId);
    if (already) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เช็คชื่อแล้ว', style: GoogleFonts.poppins())),
      );
      return;
    }
    final idx = _registered.indexWhere((e) => e.id == empId);
    if (idx == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ยังไม่ได้ลงทะเบียน', style: GoogleFonts.poppins())),
      );
      return;
    }
    final person = _registered.removeAt(idx);
    _joined.insert(0, person);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เช็คชื่อสำเร็จ', style: GoogleFonts.poppins())),
    );
  }

  String get _shortDesc =>
      'การฝึกอบรมออนไลน์ IP 101 ครั้งที่ 2 หัวข้อ การจัดการทรัพย์สินทางปัญญาในองค์กร';
  String get _longDesc =>
      'การฝึกอบรมออนไลน์ IP 101 ครั้งที่ 2 หัวข้อ การจัดการทรัพย์สินทางปัญญาในองค์กร เนื้อหาเกี่ยวกับการสร้างแบรนด์และทรัพย์สินทางปัญญา การจดทะเบียนสิทธิบัตร การบริหารจัดการเครื่องหมายการค้า และกรณีศึกษาในองค์กรจริง พร้อม Q&A.';
}

class _Person {
  final String id;
  final String name;
  final String imageUrl;
  const _Person({required this.id, required this.name, required this.imageUrl});
}
