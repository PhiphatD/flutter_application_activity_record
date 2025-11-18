import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:flip_card/flip_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Timer _timer;
  Duration _duration = const Duration(minutes: 10);

  final String empName = "Ms. Cherliya Wattanaissararat";
  final String empId = "1650702200";
  final String empPosition = "Software Developer";
  final String empDepartment = "IT";
  final String companyName = "Company ABC";
  final String avatarUrl = "https://i.pravatar.cc/150?img=32";
  String qrData = "1650702200";

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_duration.inSeconds > 0) {
            _duration = _duration - const Duration(seconds: 1);
          } else {
            _duration = const Duration(minutes: 10);
            qrData =
                "1650702200_REFRESH_${DateTime.now().millisecondsSinceEpoch}";
          }
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF375987),
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Color(0xFF375987),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF375987)),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBackground(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Employee ID',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF375987),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 180,
                  ),
                  height: 4,
                  color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.5),
                ),
                SizedBox(height: 15),
                SizedBox(
                  height: 450,
                  child: FlipCard(
                    front: _buildInfoCard(),
                    back: _buildQrCard(),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      color: Colors.grey,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'แตะที่บัตรเพื่อพลิก',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE6EFFF), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30.0),
      padding: const EdgeInsets.all(25.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/images/card_background.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            companyName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF375987),
            ),
          ),
          const SizedBox(height: 15),
          CircleAvatar(radius: 60, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(height: 15),
          Text(
            empName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF375987),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 8.0,
            ),
            child: Divider(color: Colors.black.withOpacity(0.4), thickness: 1),
          ),
          Text(
            empPosition,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, color: Color(0xFF375987)),
          ),
          const SizedBox(height: 5),
          Text(
            'Department : $empDepartment',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, color: Color(0xFF375987)),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30.0),
      padding: const EdgeInsets.symmetric(vertical: 25.0, horizontal: 25.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/images/card_background.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'DIGITAL KEYPASS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF375987),
            ),
          ),
          const SizedBox(height: 15),
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 181.0,
            gapless: false,
          ),
          const SizedBox(height: 15),
          const Text(
            'Show this to Organizer to check-in',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF375987)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 8.0,
            ),
            child: Divider(color: Colors.black.withOpacity(0.4), thickness: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, color: Color(0xFF375987)),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(fontSize: 20, color: Color(0xFF375987)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
