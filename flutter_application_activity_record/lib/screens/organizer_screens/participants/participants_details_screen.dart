import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_activity_record/theme/app_colors.dart';
import 'models.dart';

class ParticipantsDetailsScreen extends StatefulWidget {
  final ActivitySummary activity;
  const ParticipantsDetailsScreen({super.key, required this.activity});

  @override
  State<ParticipantsDetailsScreen> createState() => _ParticipantsDetailsScreenState();
}

class _ParticipantsDetailsScreenState extends State<ParticipantsDetailsScreen> {
  bool _showJoined = false;
  bool _descExpanded = false;

  final List<_Person> _registered = [
    _Person(id: 'emp001', name: 'Karen Den', imageUrl: 'https://i.pravatar.cc/150?img=1'),
    _Person(id: 'emp002', name: 'Knoop Jain', imageUrl: 'https://i.pravatar.cc/150?img=2'),
    _Person(id: 'emp003', name: 'Ashley Hills', imageUrl: 'https://i.pravatar.cc/150?img=3'),
  ];
  final List<_Person> _joined = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: organizerBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildModeChips(),
            _buildActivityInfo(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4A80FF),
        onPressed: _scanStub,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade300,
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ),
            Center(
              child: Text('Participants', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF375987))),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.0), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10.0, offset: const Offset(0, 4))]),
        child: TextField(decoration: InputDecoration(hintText: 'Search participants...', hintStyle: GoogleFonts.poppins(), prefixIcon: Icon(Icons.search, color: Colors.grey.shade500), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0))),
      ),
    );
  }

  Widget _buildModeChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Row(children: [
        ChoiceChip(label: const Text('Registered'), labelStyle: TextStyle(color: _showJoined ? Colors.black87 : Colors.black, fontWeight: _showJoined ? FontWeight.normal : FontWeight.bold), selected: !_showJoined, onSelected: (s) => setState(() => _showJoined = false), backgroundColor: Colors.white, selectedColor: chipSelectedYellow, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0), side: BorderSide(color: _showJoined ? Colors.grey.shade400 : chipSelectedYellow)), showCheckmark: false),
        const SizedBox(width: 8),
        ChoiceChip(label: const Text('Joined'), labelStyle: TextStyle(color: _showJoined ? Colors.black : Colors.black87, fontWeight: _showJoined ? FontWeight.bold : FontWeight.normal), selected: _showJoined, onSelected: (s) => setState(() => _showJoined = true), backgroundColor: Colors.white, selectedColor: chipSelectedYellow, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0), side: BorderSide(color: _showJoined ? chipSelectedYellow : Colors.grey.shade400)), showCheckmark: false),
        const Spacer(),
        IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
      ]),
    );
  }

  Widget _buildActivityInfo() {
    final dateText = '${widget.activity.date.year}-${widget.activity.date.month.toString().padLeft(2, '0')}-${widget.activity.date.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.1))),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.calendar_today, size: 18, color: Color(0xFF375987)), const SizedBox(width: 8), Text(dateText, style: GoogleFonts.poppins()), const SizedBox(width: 16), const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF375987)), const SizedBox(width: 8), Expanded(child: Text(widget.activity.location, style: GoogleFonts.poppins()))]),
            const SizedBox(height: 8),
            Text(_descExpanded ? _longDesc : _shortDesc, style: GoogleFonts.poppins(color: Colors.black87)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => setState(() => _descExpanded = !_descExpanded), child: Text(_descExpanded ? 'less' : 'more', style: GoogleFonts.poppins())),
            )
          ]),
        ),
        const SizedBox(height: 12),
        Text(_showJoined ? 'Joined Participants' : 'Registered Participants', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _buildList() {
    final items = _showJoined ? _joined : _registered;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final p = items[index];
        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 8.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color.fromRGBO(0, 0, 0, 0.1))),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              CircleAvatar(radius: 20, backgroundImage: NetworkImage(p.imageUrl)),
              const SizedBox(width: 12),
              Expanded(child: Text(p.name, style: GoogleFonts.poppins())),
              const Icon(Icons.chevron_right),
            ]),
          ),
        );
      },
    );
  }

  void _scanStub() async {
    final idCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Scan QR', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: TextField(controller: idCtrl, decoration: InputDecoration(hintText: 'Enter EMP_ID', hintStyle: GoogleFonts.poppins())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.poppins())),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Confirm', style: GoogleFonts.poppins())),
          ],
        );
      },
    );
    if (ok == true) {
      final idx = _registered.indexWhere((e) => e.id == idCtrl.text.trim());
      if (idx != -1) {
        final person = _registered.removeAt(idx);
        _joined.insert(0, person);
        setState(() {});
      }
    }
  }

  String get _shortDesc => 'การฝึกอบรมออนไลน์ IP 101 ครั้งที่ 2 หัวข้อ การจัดการทรัพย์สินทางปัญญาในองค์กร';
  String get _longDesc => 'การฝึกอบรมออนไลน์ IP 101 ครั้งที่ 2 หัวข้อ การจัดการทรัพย์สินทางปัญญาในองค์กร เนื้อหาเกี่ยวกับการสร้างแบรนด์และทรัพย์สินทางปัญญา การจดทะเบียนสิทธิบัตร การบริหารจัดการเครื่องหมายการค้า และกรณีศึกษาในองค์กรจริง พร้อม Q&A.';
}

class _Person {
  final String id;
  final String name;
  final String imageUrl;
  const _Person({required this.id, required this.name, required this.imageUrl});
}